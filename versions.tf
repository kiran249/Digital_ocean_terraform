terraform {
  required_version = ">= 1.6.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.45"
    }
  }
}

provider "digitalocean" {
  # Reads the API token from the DIGITALOCEAN_TOKEN env var when do_token is null.
  token = var.do_token
}
