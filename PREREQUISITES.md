# Prerequisites

Everything you need before running this Terraform, from Jenkins or from your own machine.

## 1. DigitalOcean account

- [ ] A DigitalOcean account with billing enabled. The cluster, worker nodes, bastion and reserved IP are paid resources.
- [ ] Enough droplet quota for 3 droplets (2 workers + 1 bastion) in your chosen region (default `blr1`).

## 2. DigitalOcean credentials

| What | Where to create it | Used for |
|---|---|---|
| **API token** (read + write) | DO console > API > Tokens > Generate New Token | Creating all resources |
| **Spaces bucket** (private) | DO console > Spaces > Create bucket, e.g. `my-terraform-state` in `blr1` | Storing Terraform state |
| **Spaces access key + secret** | DO console > API > Spaces Keys > Generate New Key | Reading/writing the state bucket |

Copy the token and the Spaces secret when you create them. DigitalOcean shows them only once.

## 3. SSH key pair

- [ ] An SSH key pair on your machine, for example `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub`.
  Create one if needed: `ssh-keygen -t ed25519`
- [ ] The **public** key is installed on the bastion. Keep the private key to yourself.

## 4. Your public IP

- [ ] Your public IP address in CIDR form, for example `203.0.113.5/32` (find it with `curl ifconfig.me`).
  It goes in `ssh_allowed_cidrs` / `SSH_ALLOWED_CIDRS` so only you can SSH into the bastion.

## 5a. For Jenkins runs

- [ ] A Jenkins server with these plugins: **Pipeline**, **Git**, **Credentials Binding**.
- [ ] A Linux agent with `curl` and `unzip`. The pipeline downloads Terraform itself.
- [ ] Jenkins can reach this Git repository.
- [ ] These credentials added under Manage Jenkins > Credentials > Global:

| ID | Kind | Value |
|---|---|---|
| `do-api-token` | Secret text | DigitalOcean API token |
| `do-spaces-keys` | Username with password | Username = Spaces access key, password = Spaces secret |
| `do-bastion-ssh-pubkey` | Secret file | Your SSH public key file |

## 5b. For local runs

- [ ] **Terraform 1.6 or newer** (`terraform version`)
- [ ] **Git**, to clone this repo
- [ ] An **SSH client**, to log in to the bastion
- [ ] Optional: `kubectl` and `doctl`, if you want to manage the cluster from your laptop. The bastion already has both.
- [ ] Environment variables set:

```bash
export DIGITALOCEAN_TOKEN="<api token>"
export AWS_ACCESS_KEY_ID="<spaces access key>"
export AWS_SECRET_ACCESS_KEY="<spaces secret key>"
```

## Quick checklist

- [ ] DigitalOcean account with billing
- [ ] API token
- [ ] Private Spaces bucket + Spaces keys
- [ ] SSH key pair
- [ ] Your public IP
- [ ] Jenkins set up with the 3 credentials **or** Terraform installed locally

When all of these are ready, follow the steps in [README.md](README.md).
