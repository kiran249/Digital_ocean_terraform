output "vpc_id" {
  value = digitalocean_vpc.this.id
}

output "bastion_public_ip" {
  description = "Reserved public IP of the bastion host."
  value       = digitalocean_reserved_ip.bastion.ip_address
}

output "bastion_private_ip" {
  value = digitalocean_droplet.bastion.ipv4_address_private
}

output "ssh_command" {
  value = "ssh root@${digitalocean_reserved_ip.bastion.ip_address}"
}

output "cluster_id" {
  value = digitalocean_kubernetes_cluster.this.id
}

output "cluster_name" {
  value = digitalocean_kubernetes_cluster.this.name
}

output "cluster_endpoint" {
  value = digitalocean_kubernetes_cluster.this.endpoint
}

output "cluster_version" {
  value = digitalocean_kubernetes_cluster.this.version
}

output "kubeconfig" {
  description = "Raw kubeconfig for the cluster. Retrieve with: terraform output -raw kubeconfig > kubeconfig.yaml"
  value       = digitalocean_kubernetes_cluster.this.kube_config[0].raw_config
  sensitive   = true
}
