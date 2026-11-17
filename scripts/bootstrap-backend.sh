#!/usr/bin/env bash
# Cria, se ainda não existirem, os buckets que ficam fora do Terraform
# (um destroy não pode apagá-los):
#   kubeshop-tfstate-<conta>-<região>  state do Terraform
#   kubeshop-backups-<conta>-<região>  backups do MongoDB (14 dias)
# Exporta TF_STATE_BUCKET e BACKUP_BUCKET para os passos seguintes.
set -euo pipefail

REGION="${AWS_REGION:?defina AWS_REGION}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
STATE_BUCKET="kubeshop-tfstate-${ACCOUNT_ID}-${REGION}"
BACKUP_BUCKET="kubeshop-backups-${ACCOUNT_ID}-${REGION}"

ensure_bucket() {
  local bucket="$1"
  if aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
    echo "Bucket $bucket já existe."
    return
  fi
  echo "Criando bucket $bucket..."
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$bucket" --region "$REGION" >/dev/null
  else
    aws s3api create-bucket --bucket "$bucket" --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION" >/dev/null
  fi
  aws s3api wait bucket-exists --bucket "$bucket"
  aws s3api put-public-access-block --bucket "$bucket" --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  aws s3api put-bucket-versioning --bucket "$bucket" --versioning-configuration Status=Enabled
  aws s3api put-bucket-encryption --bucket "$bucket" --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
  aws s3api put-bucket-tagging --bucket "$bucket" \
    --tagging 'TagSet=[{Key=Project,Value=kubeshop},{Key=ManagedBy,Value=bootstrap-script}]'
}

ensure_bucket "$STATE_BUCKET"
ensure_bucket "$BACKUP_BUCKET"

# 14 dias para a versão atual, 7 para versões antigas.
aws s3api put-bucket-lifecycle-configuration --bucket "$BACKUP_BUCKET" --lifecycle-configuration '{
  "Rules": [{
    "ID": "retencao-backups",
    "Status": "Enabled",
    "Filter": {"Prefix": ""},
    "Expiration": {"Days": 14},
    "NoncurrentVersionExpiration": {"NoncurrentDays": 7}
  }]
}'

if [ -n "${GITHUB_ENV:-}" ]; then
  echo "TF_STATE_BUCKET=$STATE_BUCKET" >> "$GITHUB_ENV"
  echo "BACKUP_BUCKET=$BACKUP_BUCKET" >> "$GITHUB_ENV"
fi
echo "State: s3://$STATE_BUCKET | Backups: s3://$BACKUP_BUCKET"
