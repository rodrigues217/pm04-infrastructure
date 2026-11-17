# KubeShop · infraestrutura na AWS

Infraestrutura do KubeShop da Zibiska Korp
([escopo](https://github.com/LaercioMLB/kube-shop-v2/blob/main/escopo.pdf)): duas VMs na
AWS, aplicação na VM 1 e MongoDB na VM 2, provisionadas com Terraform, configuradas com
Ansible e operadas por pipelines do GitHub Actions.

```
Internet ──HTTP :80──▶ VM 1 (Nginx + React, API Node)  ──rede privada :27017──▶  VM 2 (MongoDB)
                       Elastic IP, sub-rede pública                              sub-rede de dados
                                                                                 volume EBS dedicado
```

## Documentação

| Documento | Conteúdo |
|---|---|
| [docs/arquitetura.md](docs/arquitetura.md) | diagnóstico, diagrama, decisões, limitações e estimativa de custos |
| [docs/operacao.md](docs/operacao.md) | preparação, parâmetros, rotinas, recuperação, desativação, state e diagnóstico |
| [docs/integracao-cicd.md](docs/integracao-cicd.md) | integração com o CI/CD da aplicação |
| [docs/acesso-administrativo.md](docs/acesso-administrativo.md) | acesso SSH às VMs e ao MongoDB |
| [docs/inventario.md](docs/inventario.md) | recursos criados e o que é removido no destroy |
| [docs/relatorio-validacao.md](docs/relatorio-validacao.md) | critérios de aceite, procedimento de teste e evidências |

## Pipelines

| Workflow | Função |
|---|---|
| `deploy.yml` | `plan`, `apply` e `destroy` (Terraform + Ansible) |
| `operations.yml` | `health`, `logs`, `inventory`, `restart`, `backup` (também diário), `restore-test`, `restore-production` |
| `app-images.yml` | build e publicação das imagens da aplicação no GHCR |
| `validate.yml` | `terraform fmt/validate`, `ansible-playbook --syntax-check` e ShellCheck a cada push |

## Estrutura

```
.github/actions/setup/   credenciais AWS, chave SSH, terraform init, Ansible
.github/workflows/       pipelines
terraform/               VPC, sub-redes, security groups, VMs, Elastic IP, volume EBS
ansible/playbook.yml     configuração das duas VMs
ansible/ops-*.yml        rotinas de operação
ansible/roles/           os_updates, docker, mongodb, containers
scripts/                 buckets de state/backup, inventário do Ansible, SSH temporário
docs/                    documentação
evidencias/              prints das execuções
```
