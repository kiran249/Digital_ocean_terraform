# DigitalOcean Kubernetes (DOKS) + Bastion Host — Terraform

Provisions:

| Resource | Details |
|---|---|
| VPC | Private network (`10.10.0.0/16` by default) shared by the cluster and bastion |
| DOKS cluster | Managed Kubernetes, latest version (or pinned via `k8s_version_prefix`) |
| Node pool | **2 worker nodes** (`s-2vcpu-4gb` by default) |
| Bastion host | Ubuntu 24.04 droplet in the same VPC, with kubectl, doctl and helm preinstalled |
| Reserved IP | Static public IP for the bastion |
| Firewall | Bastion allows SSH only from `ssh_allowed_cidrs` |
| Control-plane firewall | Kubernetes API reachable **only from the bastion** (plus `api_extra_allowed_cidrs`) |
| Project | Groups everything in the DO console |

```
            Internet
               │  SSH (22) from ssh_allowed_cidrs
               ▼
        ┌─────────────┐   reserved IP
        │   Bastion   │──────────────────┐
        └─────┬───────┘                  │ kubectl (443)
              │ VPC 10.10.0.0/16         ▼
   ┌──────────┴──────────┐      ┌──────────────────┐
   │ worker-1 │ worker-2 │◄────►│ DOKS control plane│ (managed, API firewalled)
   └──────────┴──────────┘      └──────────────────┘
```

## Prerequisites

- Terraform >= 1.6
- A DigitalOcean API token with read/write scope
- A DigitalOcean Spaces bucket + Spaces access key for the Terraform state
- An SSH key pair (default: `~/.ssh/id_rsa.pub`)

See [PREREQUISITES.md](PREREQUISITES.md) for the full checklist.

## Running from Jenkins

The repo includes a `Jenkinsfile` (declarative pipeline).

### 1. One-time DigitalOcean setup
1. **API token:** DO console > API > Generate New Token (read + write).
2. **State bucket:** DO console > Spaces > Create bucket (e.g. `my-terraform-state` in `blr1`). Keep it private.
3. **Spaces keys:** DO console > API > Spaces Keys > Generate New Key.

### 2. Jenkins credentials (Manage Jenkins > Credentials > Global)

| ID | Kind | Value |
|---|---|---|
| `do-api-token` | Secret text | DigitalOcean API token |
| `do-spaces-keys` | Username with password | username = Spaces access key, password = Spaces secret key |
| `do-bastion-ssh-pubkey` | Secret file | Your SSH **public** key (`id_rsa.pub` / `id_ed25519.pub`) |

### 3. Jenkins job
- Required plugins (normally installed by default): Pipeline, Git, Credentials Binding.
- Agent: a Linux agent with `curl` and `unzip`. The pipeline downloads Terraform itself into the workspace.
- New Item > **Pipeline** > *Pipeline script from SCM* > Git > this repo, branch of your choice, script path `Jenkinsfile`.
- The **first** build only registers the parameters (Jenkins doesn't know about them yet). After that, use **Build with Parameters**.

### 4. Build parameters

| Parameter | Default | Notes |
|---|---|---|
| `ACTION` | `plan` | `plan`, `apply` or `destroy` |
| `PROJECT_NAME` | `demo` | Resource prefix; also the state key (`<name>/terraform.tfstate`) |
| `REGION` | `blr1` | Cluster/bastion region |
| `NODE_COUNT` | `2` | Worker nodes |
| `SSH_ALLOWED_CIDRS` | *(empty)* | **Required** for plan/apply, e.g. `203.0.113.5/32` |
| `API_EXTRA_ALLOWED_CIDRS` | *(empty)* | Extra IPs allowed to reach the K8s API |
| `STATE_BUCKET` | `my-terraform-state` | Your Spaces bucket |
| `STATE_REGION` | `blr1` | Region of that bucket |
| `AUTO_APPROVE` | `false` | Skip the manual approval step |

### Pipeline stages
`Check parameters` → `Install Terraform` → `Init` (Spaces backend) → `Validate` → `Plan` (archives `tfplan.txt`) → `Approval` (manual, 30 min) → `Apply` → `Outputs`

Use `apply` to create or update the infrastructure, and `destroy` to tear it down. Both stop at an approval prompt that shows the plan. The kubeconfig is never printed or archived. Get it from the bastion with `doctl`, as described below.

Spaces has no state locking, so the pipeline uses `disableConcurrentBuilds()`. Don't run Terraform locally against the same state while a build is running.

## Local usage

```bash
export DIGITALOCEAN_TOKEN="dop_v1_xxx"
export AWS_ACCESS_KEY_ID="<spaces access key>"
export AWS_SECRET_ACCESS_KEY="<spaces secret key>"

cp backend.hcl.example backend.hcl             # edit bucket/key/endpoint
cp terraform.tfvars.example terraform.tfvars   # edit: set ssh_allowed_cidrs to your IP!
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

Creation takes ~5–10 minutes.

## Accessing the cluster from the bastion

```bash
# 1. Copy the kubeconfig to the bastion
terraform output -raw kubeconfig > kubeconfig.yaml
scp kubeconfig.yaml root@$(terraform output -raw bastion_public_ip):~/.kube/config
# (create ~/.kube first if needed: ssh root@<ip> mkdir -p ~/.kube)

# 2. SSH in and use kubectl
ssh root@$(terraform output -raw bastion_public_ip)
kubectl get nodes
```

Alternatively, on the bastion: `doctl auth init` then `doctl kubernetes cluster kubeconfig save <cluster_name>`.

> Cloud-init installs the tools a minute or two after the droplet boots. Check progress with `cloud-init status --wait`.

To also run `kubectl` from your laptop, add your public IP to `api_extra_allowed_cidrs` (or set `restrict_api_to_bastion = false`).

## Key variables

| Variable | Default | Description |
|---|---|---|
| `project_name` | `demo` | Name prefix for all resources |
| `region` | `blr1` | DO region slug |
| `node_count` | `2` | Number of worker nodes |
| `node_size` | `s-2vcpu-4gb` | Worker droplet size |
| `k8s_version_prefix` | `""` | e.g. `"1.31."`; empty = latest |
| `ha_control_plane` | `false` | HA control plane (paid) |
| `bastion_size` | `s-1vcpu-1gb` | Bastion droplet size |
| `ssh_allowed_cidrs` | `0.0.0.0/0` | **Restrict to your IP** |
| `restrict_api_to_bastion` | `true` | Firewall the K8s API to the bastion |
| `api_extra_allowed_cidrs` | `[]` | Extra IPs allowed to reach the K8s API |

## Outputs

`bastion_public_ip`, `bastion_private_ip`, `ssh_command`, `cluster_id`, `cluster_name`, `cluster_endpoint`, `cluster_version`, `kubeconfig` (sensitive).

## Teardown

```bash
terraform destroy
```

## Notes

- State contains the kubeconfig and is sensitive. Keep the Spaces bucket private and its keys restricted.
- DOKS worker nodes are managed by DigitalOcean and don't accept your SSH key; the bastion is your secure entry point for `kubectl`/`helm` and for reaching private in-VPC services.
