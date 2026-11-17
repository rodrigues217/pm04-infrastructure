#!/usr/bin/env bash
# Gera o inventário do Ansible a partir dos outputs do Terraform.
# Uso: scripts/gerar-inventario.sh [arquivo-de-saida]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/ansible/inventory/hosts.yml}"
KEY="${SSH_KEY_FILE:-$HOME/.ssh/kubeshop}"

tf() { terraform -chdir="$ROOT/terraform" output -raw "$1"; }

APP_IP="$(tf app_public_ip)"
DB_IP="$(tf db_private_ip)"
DB_PUBLIC_IP="$(tf db_public_ip)"
VOLUME_ID="$(tf mongo_volume_id)"

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

cat > "$OUT" <<EOF
# Gerado automaticamente por scripts/gerar-inventario.sh - não editar.
all:
  vars:
    ansible_user: ubuntu
    ansible_ssh_private_key_file: ${KEY}
    app_public_ip: ${APP_IP}
    db_private_ip: ${DB_IP}
  children:
    app:
      hosts:
        app-vm:
          ansible_host: ${APP_IP}
    db:
      hosts:
        db-vm:
          ansible_host: ${DB_IP}
          db_public_ip: "${DB_PUBLIC_IP}"
          mongo_volume_id: ${VOLUME_ID}
          # SSH no banco só via VM da aplicação
          ansible_ssh_common_args: "-o ProxyCommand='ssh -i ${KEY} ${SSH_OPTS} -W %h:%p -q ubuntu@${APP_IP}'"
EOF

echo "Inventário gerado em $OUT (app=$APP_IP, db=$DB_IP via bastion)"
