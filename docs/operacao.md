# Manual de operação

Todas as rotinas são executadas em **Actions** no GitHub, em *Run workflow*. O resultado
fica na página da execução: resumo no topo e log de cada passo. Senhas e chaves não
aparecem nos logs.

- **Deploy**: workflow *Infra KubeShop - deploy* (`deploy.yml`)
- **Operação**: workflow *Infra KubeShop - operação* (`operations.yml`)

## 1. Preparação (uma vez por conta)

### Conta AWS

1. *IAM → Policies → Create policy → JSON*: cole [iam-policy-pipeline.json](iam-policy-pipeline.json)
   e salve como `pm04-pipeline`. A política libera EC2 apenas em us-east-1 e S3 apenas em
   buckets `kubeshop-*`. Para outra região, troque `us-east-1` na política e crie a
   variável `AWS_REGION`.
2. *IAM → Users → Create user*: `github-pm04`, sem acesso ao console, com a política
   `pm04-pipeline`.
3. No usuário, *Security credentials → Create access key → Third-party service*.
4. Recomendado: *Billing → Budgets* com alerta de gasto mensal.

### Chave SSH

```bash
ssh-keygen -t ed25519 -N "" -C kubeshop-deploy -f kubeshop-deploy
```

Guarde `kubeshop-deploy` (privada) no cofre de senhas da equipe. A chave pública é
derivada dela pela pipeline.

### GitHub

*Settings → Secrets and variables → Actions*. Secrets que mudam por ambiente podem ficar em
*Settings → Environments → dev/homolog/prod*.

| Secret | Valor |
|---|---|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | access key do usuário `github-pm04` |
| `AWS_SESSION_TOKEN` | somente para credenciais temporárias (STS) |
| `SSH_PRIVATE_KEY` | conteúdo do arquivo `kubeshop-deploy` |
| `MONGO_ROOT_PASSWORD` | `openssl rand -base64 24` |
| `MONGO_APP_PASSWORD` | outra senha gerada da mesma forma |

| Variável (opcional) | Padrão | Uso |
|---|---|---|
| `AWS_REGION` | `us-east-1` | região |
| `APP_INSTANCE_TYPE` | `t3.micro` | tipo da VM 1 quando `instance_type=ambiente` |
| `DB_INSTANCE_TYPE` | `t3.micro` | tipo da VM 2 |
| `ADMIN_CIDRS` | `[]` | IPs com SSH fixo na VM 1 ([acesso-administrativo.md](acesso-administrativo.md)) |
| `ENABLE_NAT_GATEWAY` | `false` | `true` remove o IP público do banco (+US$ 33/mês) |
| `SCHEDULED_BACKUP_ENV` | `dev` | ambiente do backup diário |

### Imagens

Rode *App KubeShop - publicar imagens* com `image_tag=1.0.0`. Em *Packages*, deixe
`kubeshop-api` e `kubeshop-frontend` públicos. Em produção as imagens vêm do CI/CD da
aplicação ([integracao-cicd.md](integracao-cicd.md)).

## 2. Parâmetros do deploy

| Parâmetro | Valores | Efeito |
|---|---|---|
| `action` | `plan` / `apply` / `destroy` | só mostrar o plano, criar/atualizar ou remover |
| `environment` | `dev` / `homolog` / `prod` | state, nomes e secrets separados |
| `instance_name` | ex.: `vm-pm04` | tag Name das VMs (sem recriar) |
| `instance_type` | `ambiente` / `t3.micro` / `t3.small` / `t3.medium` | tipo da VM 1; muda com stop/start, sem recriar |
| `docker_image` | vazio ou registro | vazio = `ghcr.io/<dono do repositório>` |
| `docker_tag` | ex.: `1.0.1` | versão da aplicação; vazio mantém a atual (obrigatório no primeiro deploy) |
| `pull_images` | `true` / `false` | baixar a tag de novo (tags mutáveis) |
| `update_os` | `true` / `false` | `apt upgrade` e reinício se o SO pedir |
| `extra_packages` | ex.: `curl, git, unzip` | pacotes adicionais |
| `confirm_destroy` | nome do ambiente | obrigatório para `destroy` |

O deploy executa, nesta ordem: buckets de state e backup → `terraform fmt/validate` →
`plan` (resumo na execução) → `apply` só se houver mudança → inventário do Ansible a partir
dos outputs → SSH aberto para o runner → playbook (SO, Docker, MongoDB, aplicação) → teste
de saúde e smoke test → teste da porta 27017 pela internet → SSH fechado (mesmo com erro).

## 3. Rotinas do dia a dia

Não removem dados.

| Rotina | Como executar | Resultado esperado | Se falhar |
|---|---|---|---|
| Ver mudanças | Deploy, `action=plan` | resumo do plano; nada é alterado | ver o erro do `terraform plan` (seção 7) |
| Criar ou atualizar | Deploy, `action=apply` | `PLAY RECAP` com `failed=0` e URL da loja no resumo | rodar de novo; se persistir, Operação `logs` |
| Nova versão | Deploy, `docker_tag=<nova>` | `/api/info` com a nova versão | Deploy com a tag anterior |
| Atualizar o SO | Deploy, `update_os=true` | pacotes atualizados, reinício se necessário | Operação `health` e `logs` |
| Inventário | Operação, `inventory` | outputs, recursos no state, VMs e volumes | conferir se o ambiente existe |
| Saúde | Operação, `health` | contêineres `healthy`, contagem de documentos, smoke test `PASS`, 27017 fechada pela internet e aberta pela rede privada | Operação `logs` |
| Logs | Operação, `logs` | 150 linhas por contêiner, CPU, memória e disco | — |
| Reiniciar | Operação, `restart`, `restart_target=all/app/db` | serviços `healthy`; banco reinicia antes da aplicação | `logs`; depois Deploy `apply` |
| Backup | Operação, `backup` (também diário às 03:00) | arquivo em `s3://kubeshop-backups-<conta>-<região>/<ambiente>/` | `logs` (espaço em disco) |
| Testar restauração | Operação, `restore-test`, `backup_file` opcional | contagens do backup e do banco principal; banco principal intacto | escolher outro arquivo em `backup_file` |

## 4. Rotinas que alteram ou removem dados

Exigem confirmação digitada.

| Rotina | Parâmetros | O que acontece |
|---|---|---|
| Restaurar no banco principal | Operação, `restore-production`, `confirm=RESTAURAR <ambiente>` | backup de segurança; substitui os dados pelo backup escolhido (vazio = o anterior ao de segurança); reinicia a API; teste de saúde |
| Desativar ambiente | Deploy, `action=destroy`, `confirm_destroy=<ambiente>` | backup final no S3 e remoção dos recursos do ambiente (seção 6) |

## 5. Recuperação em caso de falha

| Situação | Ação |
|---|---|
| Deploy falhou no Terraform | O state registra o que foi criado. Corrija a causa e rode de novo |
| Deploy falhou no Ansible | A infraestrutura existe. Rode o deploy de novo; o playbook só altera o que estiver diferente |
| Versão nova com defeito | Deploy com o `docker_tag` anterior |
| Dados corrompidos | `restore-test` para conferir o backup, depois `restore-production` |
| VM do banco perdida | O volume EBS é independente. Um `apply` recria a VM e o Ansible remonta o mesmo volume |
| Volume do banco perdido | `apply` cria um volume vazio; depois `restore-production` com o último backup |

## 6. Desativação

Deploy → `action=destroy`, `confirm_destroy=<ambiente>`.

| Item | Destino |
|---|---|
| VMs, discos do sistema, Elastic IP, VPC, sub-redes, security groups, NAT | removidos |
| Volume do MongoDB | **removido com os dados** |
| Backup final | gravado antes da remoção em `s3://kubeshop-backups-.../<ambiente>/`, expira em 14 dias |
| State do Terraform | permanece no bucket de state (versionado) |
| Imagens no GHCR | permanecem |

Continuam gerando custo após o destroy: apenas os dois buckets S3 (centavos por mês).
Para encerrar tudo, depois do destroy de todos os ambientes:

1. Esvazie e apague os buckets `kubeshop-tfstate-*` e `kubeshop-backups-*` no console do
   S3 (inclua as versões antigas). Os backups serão perdidos.
2. Desative e exclua a access key do usuário `github-pm04`.

## 7. State do Terraform

Local: `s3://kubeshop-tfstate-<conta>-<região>/kubeshop/<ambiente>/terraform.tfstate`.
Os passos abaixo usam credenciais de administrador da conta: a política da pipeline não
lista versões de objetos.

**Lock preso** (`Error acquiring the state lock`, após uma execução cancelada):

1. Confirme em Actions que não há execução em andamento no ambiente.
2. Apague o objeto `kubeshop/<ambiente>/terraform.tfstate.tflock` no bucket.
3. Rode Deploy → `plan`.

**State corrompido ou apagado:**

```bash
B=kubeshop-tfstate-<conta>-<região>
K=kubeshop/<ambiente>/terraform.tfstate
aws s3api list-object-versions --bucket "$B" --prefix "$K" \
  --query 'Versions[].[VersionId,LastModified,Size]' --output table
aws s3api copy-object --bucket "$B" --key "$K" --copy-source "$B/$K?versionId=<versao>"
```

Depois, rode Deploy → `plan`: o plano deve mostrar "Sem alterações" ou apenas a diferença
esperada.

**State perdido sem versões:** os recursos continuam existindo, identificados pelas tags
`Project=kubeshop` e `Environment=<ambiente>`. Apague-os pelo console (as VMs primeiro),
rode Deploy → `apply` para recriar e `restore-production` com o último backup.

## 8. Diagnóstico de falhas comuns

| Sintoma no log | Causa provável | Ação |
|---|---|---|
| `Error acquiring the state lock` | execução anterior cancelada | seção 7 |
| `terraform fmt -check` falhou | código fora do padrão | `terraform fmt -recursive` e novo commit |
| `UnauthorizedOperation` / `AccessDenied` | política IAM ou região diferente de us-east-1 | conferir a política e `AWS_REGION` |
| `Defina os secrets MONGO_ROOT_PASSWORD...` | secret ausente no ambiente | cadastrar o secret com 12+ caracteres |
| `Informe docker_tag` | primeiro deploy sem tag | rodar com `docker_tag` preenchido |
| `UNREACHABLE` no Ansible | SSH bloqueado ou VM reiniciando | rodar de novo; conferir o security group no console |
| `pull access denied` / `manifest unknown` | imagem privada ou tag inexistente | deixar o pacote público; conferir a tag publicada |
| MongoDB não fica `healthy` | secret de senha alterado depois da criação do banco, ou disco cheio | voltar o valor anterior do secret; `logs` para ver o espaço em disco |
| API não fica `healthy` / `/api/health/ready` 503 | API sem acesso ao banco | `health` (teste da 27017 pela rede privada) e `logs` |
| `A porta 27017 respondeu pela internet!` | regra de entrada indevida no SG do banco | remover a regra no console e rodar `apply` |
| `Nenhum backup encontrado` | backup ainda não executado no ambiente | rodar `backup` |

## 9. Credenciais nos registros

- Secrets do GitHub aparecem como `***` nos logs.
- Tarefas do Ansible que manipulam senhas usam `no_log` e aparecem como `censored`.
- Comandos dentro dos contêineres leem as senhas de arquivos (`$(cat ...)`), sem o valor na
  linha de comando registrada.
- Antes de anexar prints de evidência, confira que nenhum mostra valores de secrets.
