// Jenkins pipeline: DOKS cluster (2 workers) + bastion host on DigitalOcean.
//
// Required Jenkins credentials (Manage Jenkins > Credentials):
//   do-api-token          Secret text        DigitalOcean API token
//   do-spaces-keys        Username/password  Spaces access key (username) / secret key (password)
//   do-bastion-ssh-pubkey Secret file        SSH public key installed on the bastion

def TF_VERSION = '1.9.8'

// "1.2.3.4/32, 5.6.7.8/32" -> ["1.2.3.4/32","5.6.7.8/32"]
def toTfList(String csv) {
  def items = (csv ?: '').tokenize(',').collect { it.trim() }.findAll { it }
  return '[' + items.collect { "\"${it}\"" }.join(',') + ']'
}

// Runs body with terraform on PATH and all DigitalOcean credentials exported.
def withTerraform(Closure body) {
  withEnv(["PATH+TF=${env.WORKSPACE}/.tfbin"]) {
    withCredentials([
      string(credentialsId: 'do-api-token', variable: 'DIGITALOCEAN_TOKEN'),
      usernamePassword(credentialsId: 'do-spaces-keys',
                       usernameVariable: 'AWS_ACCESS_KEY_ID',
                       passwordVariable: 'AWS_SECRET_ACCESS_KEY'),
      file(credentialsId: 'do-bastion-ssh-pubkey', variable: 'TF_VAR_ssh_public_key_path'),
    ]) {
      body()
    }
  }
}

pipeline {
  agent any

  parameters {
    choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'], description: 'Terraform action to run')
    string(name: 'PROJECT_NAME', defaultValue: 'demo', description: 'Name prefix for all resources (also the state key)')
    string(name: 'REGION', defaultValue: 'blr1', description: 'DigitalOcean region for the cluster and bastion')
    string(name: 'NODE_COUNT', defaultValue: '2', description: 'Number of Kubernetes worker nodes')
    string(name: 'SSH_ALLOWED_CIDRS', defaultValue: '', description: 'Comma-separated CIDRs allowed to SSH into the bastion, e.g. 203.0.113.5/32 (required)')
    string(name: 'API_EXTRA_ALLOWED_CIDRS', defaultValue: '', description: 'Comma-separated extra CIDRs allowed to reach the Kubernetes API (bastion is always allowed)')
    string(name: 'STATE_BUCKET', defaultValue: 'my-terraform-state', description: 'Spaces bucket holding the Terraform state')
    string(name: 'STATE_REGION', defaultValue: 'blr1', description: 'Region of the Spaces state bucket')
    booleanParam(name: 'AUTO_APPROVE', defaultValue: false, description: 'Skip the manual approval before apply/destroy')
  }

  options {
    disableConcurrentBuilds() // Spaces has no state locking; never run two builds at once
    buildDiscarder(logRotator(numToKeepStr: '20'))
    timeout(time: 90, unit: 'MINUTES')
  }

  environment {
    TF_IN_AUTOMATION         = 'true'
    TF_INPUT                 = '0'
    TF_VAR_project_name      = "${params.PROJECT_NAME}"
    TF_VAR_region            = "${params.REGION}"
    TF_VAR_node_count        = "${params.NODE_COUNT}"
    TF_VAR_ssh_allowed_cidrs = toTfList(params.SSH_ALLOWED_CIDRS)
    TF_VAR_api_extra_allowed_cidrs = toTfList(params.API_EXTRA_ALLOWED_CIDRS)
  }

  stages {
    stage('Check parameters') {
      steps {
        script {
          if (params.ACTION != 'destroy' && !params.SSH_ALLOWED_CIDRS?.trim()) {
            error('SSH_ALLOWED_CIDRS is required (e.g. 203.0.113.5/32). Refusing to open bastion SSH to the world.')
          }
        }
      }
    }

    stage('Install Terraform') {
      steps {
        sh """
          set -eu
          if [ -x .tfbin/terraform ] && .tfbin/terraform version | head -1 | grep -q 'v${TF_VERSION}\$'; then
            echo "Terraform ${TF_VERSION} already installed"
          else
            mkdir -p .tfbin
            curl -fsSLo .tfbin/terraform.zip https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip
            unzip -o -q .tfbin/terraform.zip -d .tfbin
            rm -f .tfbin/terraform.zip
          fi
          .tfbin/terraform version
        """
      }
    }

    stage('Init') {
      steps {
        writeFile file: 'backend.hcl', text: """\
bucket    = "${params.STATE_BUCKET}"
key       = "${params.PROJECT_NAME}/terraform.tfstate"
endpoints = { s3 = "https://${params.STATE_REGION}.digitaloceanspaces.com" }
"""
        withTerraform {
          sh 'terraform init -reconfigure -backend-config=backend.hcl'
        }
      }
    }

    stage('Validate') {
      steps {
        withTerraform {
          sh '''
            terraform fmt -check -recursive
            terraform validate
          '''
        }
      }
    }

    stage('Plan') {
      steps {
        withTerraform {
          sh '''
            set -eu
            if [ "$ACTION" = "destroy" ]; then
              terraform plan -destroy -out=tfplan
            else
              terraform plan -out=tfplan
            fi
            terraform show -no-color tfplan > tfplan.txt
          '''
        }
        archiveArtifacts artifacts: 'tfplan.txt', fingerprint: true
      }
    }

    stage('Approval') {
      when {
        allOf {
          expression { params.ACTION != 'plan' }
          expression { !params.AUTO_APPROVE }
        }
      }
      steps {
        timeout(time: 30, unit: 'MINUTES') {
          input message: "Run terraform ${params.ACTION} for '${params.PROJECT_NAME}'? Review tfplan.txt in the build artifacts.",
                ok: "Yes, ${params.ACTION}"
        }
      }
    }

    stage('Apply') {
      when { expression { params.ACTION != 'plan' } }
      steps {
        withTerraform {
          sh 'terraform apply tfplan'
        }
      }
    }

    stage('Outputs') {
      when { expression { params.ACTION == 'apply' } }
      steps {
        withTerraform {
          // kubeconfig is sensitive and is not printed or archived.
          sh 'terraform output'
        }
      }
    }
  }

  post {
    always {
      sh 'rm -f tfplan backend.hcl'
    }
  }
}
