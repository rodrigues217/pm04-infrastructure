#!/usr/bin/env bash
# Abre/fecha a porta 22 da VM da aplicação para o IP público de quem executa.
# Uso: scripts/ssh-access.sh open|close <security-group-id>
set -euo pipefail

ACTION="${1:?open|close}"
SG_ID="${2:?security group id}"
RUNNER_IP="$(curl -fsS --retry 3 https://checkip.amazonaws.com | tr -d '[:space:]')"
CIDR="${RUNNER_IP}/32"

case "$ACTION" in
  open)
    aws ec2 authorize-security-group-ingress --group-id "$SG_ID" \
      --ip-permissions "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=${CIDR},Description=pipeline-temporario}]" \
      >/dev/null 2>&1 || echo "Regra já existia."
    echo "SSH liberado temporariamente para o runner (${CIDR})."
    ;;
  close)
    aws ec2 revoke-security-group-ingress --group-id "$SG_ID" \
      --protocol tcp --port 22 --cidr "$CIDR" >/dev/null 2>&1 || true
    echo "SSH temporário removido (${CIDR})."
    ;;
  *) echo "Ação inválida: $ACTION" >&2; exit 1 ;;
esac
