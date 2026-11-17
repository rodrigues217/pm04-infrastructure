# PM-04 · KubeShop na AWS com Terraform, Ansible e GitHub Actions

Infraestrutura automatizada para o **KubeShop** da Zibiska Korp (demanda
[kube-shop-v2](https://github.com/LaercioMLB/kube-shop-v2/blob/main/escopo.pdf)).
Toda mudança passa pela pipeline: o Terraform provisiona, o Ansible configura e mantém,
e nenhum ajuste é feito à mão nos servidores.

## Arquitetura

```
                Internet
                    │ HTTP :80
                    ▼
┌──────────────────────── VPC 10.40.0.0/16 (us-east-1) ────────────────────────┐
│                                                                               │
│  Sub-rede pública 10.40.1.0/24            Sub-rede de dados 10.40.2.0/24      │
│  ┌──────────────────────────────┐         ┌───────────────────────────────┐   │
│  │ VM 1 · aplicação (t3.micro)  │ privada │ VM 2 · banco (t3.micro)       │   │
│  │ Elastic IP fixo              │ :27017  │ sem nenhuma porta pública     │   │
│  │ ┌──────────────────────────┐ │────────▶│ ┌───────────────────────────┐ │   │
│  │ │ kubeshop-frontend        │ │         │ │ mongodb 8.0.17 (auth)     │ │   │
│  │ │ Nginx + React  :80→8080  │ │         │ └─────────────┬─────────────┘ │   │
│  │ │        │ /api            │ │  SSH    │               │               │   │
│  │ │ kubeshop-api  Node :3000 │ │ (bastion)│   EBS gp3 10 GB (/srv/mongo) │   │
│  │ └──────────────────────────┘ │────────▶│   dados persistentes          │   │
│  └──────────────────────────────┘         └───────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────────────┘
   S3: Terraform state (versionado)  ·  S3: backups do MongoDB (14 dias)
```

| Requisito da demanda | Como foi atendido |
|---|---|
| REQ-01 Servidores: no mínimo 2 VMs | `aws_instance.app` e `aws_instance.db` ([terraform/main.tf](terraform/main.tf)) |
| REQ-02 Banco isolado, porta não pública | MongoDB só na VM 2; porta publicada só no IP privado; SG sem regra para a internet |
| REQ-03 Rede privada | SG do banco aceita 27017 **apenas** do SG da aplicação; API usa `MONGO_HOST=<IP privado>` |
| REQ-04 Acessos | SSH do banco só via bastion; SSH da app aberto só para o IP do runner durante a execução; segredos em GitHub Secrets |
| REQ-05 Persistência | Volume EBS separado montado em `/srv/mongo`; troca de `instance_type` preserva os pedidos |
| Operações (seção 9) | `deploy.yml` (plan/apply/destroy) e `operations.yml` (saúde, logs, reinício, backup, restauração) |

Detalhes e justificativas: [docs/decisoes-e-custos.md](docs/decisoes-e-custos.md).

## Estrutura

```
.github/
  actions/setup/            ação reutilizável: AWS, SSH, terraform init, Ansible
  workflows/deploy.yml      pipeline principal: Terraform → Ansible (plan/apply/destroy)
  workflows/operations.yml  saúde, logs, reinício, backup (diário), restauração
  workflows/app-images.yml  build e publicação das imagens no GHCR (integração com o CI/CD da app)
  workflows/validate.yml    fmt/validate/syntax-check a cada push
terraform/                  VPC, sub-redes, SGs, 2 VMs, Elastic IP, volume EBS
ansible/
  playbook.yml              configuração completa (idempotente)
  ops-*.yml                 rotinas de operação
  roles/os_updates          pacotes base + extra_packages + atualização do SO (update_os)
  roles/docker              Docker CE do repositório oficial
  roles/mongodb             volume EBS, segredos e contêiner MongoDB
  roles/containers          API e frontend, health checks
scripts/                    bootstrap do backend, inventário dinâmico, SSH temporário
docs/                       decisões, custos, operação e roteiro da apresentação
evidencias/                 prints e logs das execuções
```

## Configuração inicial (uma vez)

0. **Prepare a conta AWS**: alerta de gastos, usuário IAM `github-pm04` com permissão mínima
   e access key. Passo a passo em [docs/aws-conta-propria.md](docs/aws-conta-propria.md).
1. **Crie o repositório no GitHub** e envie este conteúdo.
2. **Gere a chave SSH do deploy** (no seu computador):
   ```bash
   ssh-keygen -t ed25519 -N "" -C kubeshop-deploy -f kubeshop-deploy
   ```
3. **Cadastre os Secrets** em *Settings → Secrets and variables → Actions*:

   | Secret | Valor |
   |---|---|
   | `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | access key do usuário IAM `github-pm04` (nunca a do root) |
   | `AWS_SESSION_TOKEN` | não usar com conta própria (só para credenciais temporárias) |
   | `SSH_PRIVATE_KEY` | conteúdo do arquivo `kubeshop-deploy` (privada) |
   | `MONGO_ROOT_PASSWORD` | senha forte, mín. 12 caracteres |
   | `MONGO_APP_PASSWORD` | outra senha forte, mín. 12 caracteres |

   Para senhas: `openssl rand -base64 24`. Os secrets podem ficar por ambiente
   (*Settings → Environments → dev/homolog/prod*), e o `prod` pode exigir aprovação.

4. **Variáveis opcionais** (aba *Variables*): `AWS_REGION` (padrão `us-east-1`),
   `DB_INSTANCE_TYPE` (padrão `t3.micro`, Free Tier), `ADMIN_CIDRS` (ex.: `["200.1.2.3/32"]`),
   `ENABLE_NAT_GATEWAY` (`true` deixa o banco sem IP público, +US$ 33/mês),
   `SCHEDULED_BACKUP_ENV` (ambiente do backup diário, padrão `dev`).
5. **Publique as imagens**: *Actions → App KubeShop - publicar imagens → Run* com `image_tag=1.0.0`.
   Depois, em *Packages* no seu perfil, torne `kubeshop-api` e `kubeshop-frontend` **públicos**
   (assim as VMs baixam sem credencial). Repita com `image_tag=1.0.1` para ter uma segunda versão.

## Parâmetros do deploy

| Parâmetro | Exemplo | Efeito |
|---|---|---|
| `action` | `plan` / `apply` / `destroy` | só planejar, criar/atualizar ou remover |
| `environment` | `dev` / `homolog` / `prod` | state, nomes e secrets separados por ambiente |
| `instance_name` | `vm-pm04` | tag Name das VMs (atualiza sem recriar) |
| `instance_type` | `t3.micro` → `t3.small` | tipo da VM da aplicação (stop/start, sem recriar) |
| `docker_image` | vazio = `ghcr.io/<owner>` | registro das imagens |
| `docker_tag` | `1.0.0` → `1.0.1` | versão da aplicação (recria só os contêineres) |
| `pull_images` | `false` | força baixar a tag de novo (para `latest`) |
| `update_os` | `true` / `false` | aplica `apt upgrade` e reinicia se o SO pedir |
| `extra_packages` | `curl, git, unzip` | pacotes adicionais via apt |
| `confirm_destroy` | `dev` | trava de segurança do destroy |

## Como a pipeline funciona

1. **Terraform**: garante os buckets de state/backup, `init` com state remoto por ambiente,
   `fmt` + `validate`, `plan -detailed-exitcode` (resumo na página da execução) e `apply`
   somente se houver mudança.
2. **Ansible**: gera o inventário a partir dos outputs do Terraform, abre SSH só para o IP
   do runner, executa `playbook.yml` (SO → Docker → MongoDB → aplicação), roda o teste
   funcional e prova que a porta 27017 não responde pela internet. O SSH é fechado sempre,
   mesmo em caso de erro.
3. Qualquer erro interrompe a execução: os passos shell usam `set -e`/`pipefail`, e o playbook
   usa `any_errors_fatal` (se o banco falhar, a aplicação não é tocada).

Roteiro dos 3 cenários da apresentação: [docs/roteiro-apresentacao.md](docs/roteiro-apresentacao.md).
Procedimentos para a equipe do cliente: [docs/operacao.md](docs/operacao.md).
