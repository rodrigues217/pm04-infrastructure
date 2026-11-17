# bucket, key e region vêm da pipeline (-backend-config).
# key: kubeshop/<environment>/terraform.tfstate
terraform {
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}
