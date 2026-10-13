# Remote state in a DigitalOcean Spaces bucket (S3-compatible).
# bucket, key and endpoints are supplied at init time:
#   terraform init -backend-config=backend.hcl
# Credentials come from AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY (Spaces access keys).
terraform {
  backend "s3" {
    region                      = "us-east-1" # required by the s3 backend, ignored by Spaces
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_s3_checksum            = true
  }
}
