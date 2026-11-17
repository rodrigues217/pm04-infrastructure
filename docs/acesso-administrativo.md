# Procedimento de acesso administrativo

As rotinas previstas (deploy, saúde, logs, reinício, backup e restauração) rodam pelas
pipelines e não exigem acesso às VMs. Este procedimento é para diagnóstico que as rotinas
não cobrem. Alterações de configuração feitas manualmente são sobrescritas no próximo
deploy; corrija no código e rode a pipeline.

## Regras de acesso

| Origem | Destino | Porta | Quando |
|---|---|---|---|
| Internet | VM 1 | 80 | sempre (loja) |
| IP do runner do GitHub | VM 1 | 22 | durante a execução da pipeline |
| Faixas de `ADMIN_CIDRS` | VM 1 | 22 | enquanto a variável estiver preenchida |
| VM 1 | VM 2 | 22 | sempre (bastion) |
| VM 1 | VM 2 | 27017 | sempre (API) |
| Internet | VM 2 | qualquer | nunca |

## Pré-requisitos

- Cópia da chave privada `kubeshop-deploy` (a mesma do secret `SSH_PRIVATE_KEY`),
  guardada no cofre de senhas da equipe.
- IPs do ambiente: rode Operação → `inventory` (IP público da VM 1 e IP privado da VM 2).

## 1. Liberar o seu IP

1. Descubra o seu IP público: `curl https://checkip.amazonaws.com`.
2. GitHub → *Settings → Environments → <ambiente> → Variables*: crie ou edite
   `ADMIN_CIDRS` com `["<seu-ip>/32"]`. Se o valor for o mesmo para todos os ambientes, use
   a variável de repositório.
3. Rode Deploy → `action=apply` no ambiente, com `docker_tag` vazio (mantém a versão atual).
   O plano deve mostrar apenas a criação de `aws_vpc_security_group_ingress_rule.app_ssh_admin`.

## 2. Conectar

```bash
eval "$(ssh-agent -s)"
ssh-add kubeshop-deploy

# VM 1 (aplicação)
ssh ubuntu@<ip-publico-vm1>

# VM 2 (banco), passando pela VM 1
ssh -J ubuntu@<ip-publico-vm1> ubuntu@<ip-privado-vm2>
```

## 3. Comandos úteis

Na VM 1:

```bash
sudo docker ps
sudo docker logs --tail 100 kubeshop-api
curl -s http://127.0.0.1/api/health/ready
```

Na VM 2:

```bash
sudo docker ps
df -h /srv/mongo
# shell do MongoDB como root, sem digitar a senha
sudo docker exec -it mongodb sh -c \
  'mongosh -u "$MONGO_INITDB_ROOT_USERNAME" -p "$(cat $MONGO_INITDB_ROOT_PASSWORD_FILE)" --authenticationDatabase admin kubeshop'
```

Para usar uma ferramenta gráfica (ex.: MongoDB Compass), abra um túnel pela VM 1 e conecte
em `localhost:27017`:

```bash
ssh -N -L 27017:<ip-privado-vm2>:27017 ubuntu@<ip-publico-vm1>
```

## 4. Encerrar

1. Apague a variável `ADMIN_CIDRS` (ou deixe `[]`).
2. Rode Deploy → `action=apply` com `docker_tag` vazio. O plano deve mostrar a remoção da
   regra SSH.

## Alternativa sem alterar o código

Quem tiver credenciais AWS próprias com permissão em
`ec2:AuthorizeSecurityGroupIngress` e `ec2:RevokeSecurityGroupIngress` pode abrir e fechar
a porta 22 só para o próprio IP:

```bash
scripts/ssh-access.sh open <app_security_group_id>
# ... acesso ...
scripts/ssh-access.sh close <app_security_group_id>
```

O ID do security group aparece na operação `inventory` (`app_security_group_id`) ou no
console EC2.
