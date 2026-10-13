locals {
  name = var.project_name
  tags = concat(var.tags, [var.project_name])
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
resource "digitalocean_vpc" "this" {
  name     = "${local.name}-vpc"
  region   = var.region
  ip_range = var.vpc_cidr
}

# ---------------------------------------------------------------------------
# Bastion host
# ---------------------------------------------------------------------------
resource "digitalocean_ssh_key" "bastion" {
  name       = "${local.name}-bastion-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

resource "digitalocean_droplet" "bastion" {
  name       = "${local.name}-bastion"
  region     = var.region
  size       = var.bastion_size
  image      = var.bastion_image
  vpc_uuid   = digitalocean_vpc.this.id
  ssh_keys   = [digitalocean_ssh_key.bastion.fingerprint]
  monitoring = true
  tags       = concat(local.tags, ["bastion"])

  user_data = templatefile("${path.module}/templates/bastion-cloud-init.yaml.tftpl", {})
}

# Stable public IP for the bastion (survives droplet rebuilds).
resource "digitalocean_reserved_ip" "bastion" {
  region = var.region
}

resource "digitalocean_reserved_ip_assignment" "bastion" {
  ip_address = digitalocean_reserved_ip.bastion.ip_address
  droplet_id = digitalocean_droplet.bastion.id
}

resource "digitalocean_firewall" "bastion" {
  name        = "${local.name}-bastion-fw"
  droplet_ids = [digitalocean_droplet.bastion.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.ssh_allowed_cidrs
  }

  inbound_rule {
    protocol         = "icmp"
    source_addresses = [var.vpc_cidr]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# ---------------------------------------------------------------------------
# Kubernetes (DOKS) cluster with 2 worker nodes
# ---------------------------------------------------------------------------
data "digitalocean_kubernetes_versions" "this" {
  version_prefix = var.k8s_version_prefix
}

resource "digitalocean_kubernetes_cluster" "this" {
  name          = "${local.name}-k8s"
  region        = var.region
  version       = data.digitalocean_kubernetes_versions.this.latest_version
  vpc_uuid      = digitalocean_vpc.this.id
  ha            = var.ha_control_plane
  auto_upgrade  = false
  surge_upgrade = true
  tags          = local.tags

  node_pool {
    name       = "${local.name}-workers"
    size       = var.node_size
    node_count = var.node_count
    tags       = concat(local.tags, ["k8s-worker"])
    labels = {
      role = "worker"
    }
  }

  # Lock the Kubernetes API down to the bastion's public IP (and any extras).
  control_plane_firewall {
    enabled = var.restrict_api_to_bastion
    allowed_addresses = concat(
      ["${digitalocean_reserved_ip.bastion.ip_address}/32"],
      var.api_extra_allowed_cidrs,
    )
  }

  maintenance_policy {
    day        = "sunday"
    start_time = "04:00"
  }
}

# ---------------------------------------------------------------------------
# Project grouping (shows everything together in the DO console)
# ---------------------------------------------------------------------------
resource "digitalocean_project" "this" {
  name        = local.name
  description = "Kubernetes cluster with bastion host, managed by Terraform"
  purpose     = "Web Application"
  environment = "Development"

  resources = [
    digitalocean_kubernetes_cluster.this.urn,
    digitalocean_droplet.bastion.urn,
    digitalocean_reserved_ip.bastion.urn,
  ]
}
