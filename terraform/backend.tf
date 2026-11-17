# O state fica em um bucket S3 (versionado e criptografado) criado pelo
# script scripts/bootstrap-backend.sh. bucket, key e region são passados pela
# pipeline com -backend-config, com uma key por ambiente:
#   kubeshop/<environment>/terraform.tfstate
terraform {
  backend "s3" {
    encrypt      = true
    use_lockfile = true # lock nativo no S3, impede duas execuções simultâneas
  }
}
