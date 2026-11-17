# Inventário dos recursos

Todos os recursos AWS criados pelo Terraform têm as tags `Project=kubeshop`,
`Client=zibiska-korp`, `Environment=<ambiente>` e `ManagedBy=terraform`. No console,
filtre por essas tags. A lista atual de um ambiente sai em Operação → `inventory`.

`<amb>` = `dev`, `homolog` ou `prod`. `<nome>` = parâmetro `instance_name` (padrão `vm-pm04`).

## Gerenciados pelo Terraform (por ambiente)

| Recurso | Nome (tag Name) | Função | Custo | Removido no destroy |
|---|---|---|---|---|
| `aws_instance.app` | `<nome>-app-<amb>` | VM 1: Nginx + React e API | sim | sim |
| `aws_instance.db` | `<nome>-db-<amb>` | VM 2: MongoDB | sim | sim |
| `aws_ebs_volume.mongo` | `kubeshop-<amb>-mongo-data` | dados do MongoDB (`/srv/mongo`) | sim | **sim, com os dados** |
| `aws_volume_attachment.mongo` | — | anexa o volume à VM 2 | não | sim |
| `aws_eip.app` | `kubeshop-<amb>-app-eip` | endereço público da loja | sim | sim |
| `aws_key_pair.deploy` | `kubeshop-<amb>-deploy` | chave pública de acesso às VMs | não | sim |
| `aws_vpc.main` | `kubeshop-<amb>-vpc` | rede 10.40.0.0/16 | não | sim |
| `aws_internet_gateway.main` | `kubeshop-<amb>-igw` | saída para a internet | não | sim |
| `aws_subnet.public` | `kubeshop-<amb>-public` | 10.40.1.0/24, VM 1 | não | sim |
| `aws_subnet.data` | `kubeshop-<amb>-data` | 10.40.2.0/24, VM 2 | não | sim |
| `aws_route_table.public` / `.data` | `kubeshop-<amb>-rt-*` | rotas das sub-redes | não | sim |
| `aws_security_group.app` | `kubeshop-<amb>-app-sg` | entrada 80 pública; 22 de `ADMIN_CIDRS` e do runner | não | sim |
| `aws_security_group.db` | `kubeshop-<amb>-db-sg` | entrada 27017 e 22 somente do SG da VM 1 | não | sim |
| `aws_nat_gateway.main` + `aws_eip.nat` | `kubeshop-<amb>-nat` | saída do banco sem IP público (só com `ENABLE_NAT_GATEWAY=true`) | sim | sim |

Os discos do sistema das VMs (gp3 10 GB, criptografados) são removidos junto com as VMs.

## Fora do Terraform (compartilhados entre ambientes)

| Recurso | Nome | Função | Criado por | Removido no destroy |
|---|---|---|---|---|
| Bucket S3 | `kubeshop-tfstate-<conta>-<região>` | state do Terraform | `scripts/bootstrap-backend.sh` | não |
| Bucket S3 | `kubeshop-backups-<conta>-<região>` | backups do MongoDB, pasta por ambiente, 14 dias | `scripts/bootstrap-backend.sh` | não |
| Usuário IAM | `github-pm04` + política [iam-policy-pipeline.json](iam-policy-pipeline.json) | credencial da pipeline | manual (uma vez) | não |
| Imagens | `ghcr.io/<dono>/kubeshop-api`, `kubeshop-frontend` | versões da aplicação | `app-images.yml` / CI/CD | não |
| Secrets, variáveis e Environments | GitHub | configuração das pipelines | manual (uma vez) | não |

## Dentro das VMs

| VM | Item | Local |
|---|---|---|
| 1 | contêineres `kubeshop-frontend` (80→8080) e `kubeshop-api` (3000), rede Docker `kubeshop` | — |
| 1 | senha da API | `/opt/kubeshop/app/secrets` (0400) |
| 2 | contêiner `mongodb` 8.0.17, porta 27017 no IP privado | — |
| 2 | dados, config e área temporária de backup | `/srv/mongo/{db,configdb,backup}` |
| 2 | senhas, init e health check do MongoDB | `/opt/kubeshop/mongo` |
| 1 e 2 | swap de 1 GB | `/swapfile` |
