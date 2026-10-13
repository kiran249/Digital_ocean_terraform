variable "do_token" {
  description = "DigitalOcean API token. Leave null to use the DIGITALOCEAN_TOKEN environment variable."
  type        = string
  default     = null
  sensitive   = true
}

variable "project_name" {
  description = "Prefix used for naming all resources."
  type        = string
  default     = "demo"
}

variable "region" {
  description = "DigitalOcean region slug."
  type        = string
  default     = "blr1"
}

variable "vpc_cidr" {
  description = "IP range for the private VPC."
  type        = string
  default     = "10.10.0.0/16"
}

# ---------------- Kubernetes ----------------

variable "k8s_version_prefix" {
  description = "Kubernetes minor version prefix (e.g. \"1.31.\"). Empty string selects the latest available version."
  type        = string
  default     = ""
}

variable "node_size" {
  description = "Droplet size slug for worker nodes."
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "node_count" {
  description = "Number of worker nodes."
  type        = number
  default     = 2
}

variable "ha_control_plane" {
  description = "Enable the highly-available control plane (extra cost)."
  type        = bool
  default     = false
}

variable "restrict_api_to_bastion" {
  description = "If true, the Kubernetes API is reachable only from the bastion (plus api_extra_allowed_cidrs)."
  type        = bool
  default     = true
}

variable "api_extra_allowed_cidrs" {
  description = "Additional CIDRs/IPs allowed to reach the Kubernetes API when restrict_api_to_bastion is true."
  type        = list(string)
  default     = []
}

# ---------------- Bastion ----------------

variable "bastion_size" {
  description = "Droplet size slug for the bastion host."
  type        = string
  default     = "s-1vcpu-1gb"
}

variable "bastion_image" {
  description = "Image slug for the bastion host."
  type        = string
  default     = "ubuntu-24-04-x64"
}

variable "ssh_public_key_path" {
  description = "Path to the SSH public key to install on the bastion."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed to SSH into the bastion. Restrict this to your own IP (e.g. [\"203.0.113.5/32\"])."
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}

variable "tags" {
  description = "Extra tags applied to resources."
  type        = list(string)
  default     = ["terraform"]
}
