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

- Terraform >= 1.5
- A DigitalOcean API token with read/write scope
- An SSH key pair (default: `~/.ssh/id_rsa.pub`)

## Usage

```bash
export DIGITALOCEAN_TOKEN="dop_v1_xxx"

cp terraform.tfvars.example terraform.tfvars   # edit: set ssh_allowed_cidrs to your IP!
terraform init
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

- State contains the kubeconfig and is sensitive — use a remote backend (e.g. DO Spaces / S3) with encryption for team use.
- DOKS worker nodes are managed by DigitalOcean and don't accept your SSH key; the bastion is your secure entry point for `kubectl`/`helm` and for reaching private in-VPC services.
