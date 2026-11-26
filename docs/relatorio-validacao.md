# Relatório de validação

| Item | Valor |
|---|---|
| Ambiente | `dev` |
| Região | us-east-1 |
| Commit validado | `<sha>` |
| Período dos testes | `<data início>` a `<data fim>` |

Evidências em [evidencias/](../evidencias/). Em "Execução", cole o link da execução no
GitHub Actions (`https://github.com/<dono>/<repo>/actions/runs/<id>`).

As evidências vêm de três fontes, que se complementam:

| Fonte | O que prova |
|---|---|
| GitHub Actions | que cada mudança foi feita pela pipeline (registro de execução) |
| Console da AWS | que os recursos existem como a pipeline informa |
| Navegador | que a loja funciona para o usuário |

## Resultado por critério de aceite

| Critério | Evidências | Execução | Resultado |
|---|---|---|---|
| ACE-01 Reprodução | `02`, `03`, `06` | | |
| ACE-02 Duas VMs | `07`, `08`, `10` | | |
| ACE-03 Isolamento | `04`, `05`, `09`, `14` | | |
| ACE-04 Aplicação | `11`, `12`, `13` | | |
| ACE-05 Persistência | `14`, `15`, `16` (reinício); `17`, `18`, `21` (alteração de infraestrutura) | | |
| ACE-06 CI/CD | `01`, `17`, `19`; [integracao-cicd.md](integracao-cicd.md) | | |
| ACE-07 Recuperação | `22`, `23`, `24`, `25`, `26` | | |
| ACE-08 Administração | `27`, `28`, `29`, `30`, `31`; [operacao.md](operacao.md) | | |
| ACE-09 Custos | [arquitetura.md, seção 5](arquitetura.md#5-estimativa-de-custo-mensal) | — | |
| ACE-10 Transferência | [operacao.md](operacao.md), [inventario.md](inventario.md), [acesso-administrativo.md](acesso-administrativo.md) | — | |

Cenários do enunciado PM-04:

| Cenário | Evidências |
|---|---|
| 1 · Criação inicial | `02`, `03` |
| 2 · Atualização (Terraform + manutenção pelo Ansible) | `17`, `18`, `19`, `20` |
| 3 · Reexecução sem alterações | `06` |

## Contagem de pedidos

O deploy termina com o smoke test do KubeShop, que **cria um pedido fictício** e o
consulta: é a prova de que a loja grava no banco. Por isso **cada deploy soma um pedido**.
As demais rotinas (`health`, `restart`, `backup`, `restore-*`) não gravam nada.

Por isso a persistência é conferida pelo **número do pedido** criado no navegador (ex.:
`#1da85a`), e a contagem `orders=N` só é comparada entre etapas sem deploy no meio.

## Procedimento

Pré-requisitos: preparação da seção 1 de [operacao.md](operacao.md) concluída; variáveis
`APP_INSTANCE_TYPE` e `DB_INSTANCE_TYPE` ainda não criadas (ou com `t3.micro`).

As etapas são sequenciais: cada uma depende do estado deixado pela anterior. A etapa 17
(destroy) é sempre a última. Em cada etapa de pipeline, copie o link da execução para a
tabela acima.

Workflows citados, em *Actions*:

- **Imagens**: *App KubeShop - publicar imagens*
- **Deploy**: *Infra KubeShop - deploy (Terraform + Ansible)*
- **Operação**: *Infra KubeShop - operação (...)*

"Resumo" é o topo da página da execução, acima da lista de jobs. "Passo" é uma linha
dentro do job, expandida com um clique. Prints do console AWS: região **us-east-1**.

### 1. Publicar duas versões da aplicação (ACE-06)

Imagens → `image_tag=1.0.0`. Depois, de novo, com `image_tag=1.0.1`.
Em *Packages*, deixe `kubeshop-api` e `kubeshop-frontend` públicos.

| Print | Onde | Deve aparecer |
|---|---|---|
| `01-imagens.png` | página do pacote `kubeshop-api` em *Packages* | as tags `1.0.0` e `1.0.1` |

### 2. Planejar (ACE-01)

Deploy → `action=plan`, `environment=dev`.

| Print | Onde | Deve aparecer |
|---|---|---|
| `02-plan.png` | resumo da execução | lista de recursos e `Plan: 23 to add, 0 to change, 0 to destroy` |

### 3. Provisionar e configurar (ACE-01, ACE-03 · Cenário 1)

Deploy → `action=apply`, `environment=dev`, `instance_type=t3.micro`, `docker_tag=1.0.0`,
`update_os=false`, `extra_packages=curl, git, unzip`. Duração aproximada: 10 minutos.

| Print | Onde | Deve aparecer |
|---|---|---|
| `03-apply-recap.png` | resumo da execução | "Ansible - PLAY RECAP" com `failed=0` em `app-vm` e `db-vm`, e a URL da loja |
| `04-isolamento.png` | job *Ansible*, passo "Evidência - MongoDB inacessível pela internet" | `OK: 27017 não responde pela internet (IP de saída do banco: <ip>)` |
| `05-porta-fechada-pc.png` | PowerShell no seu computador: `Test-NetConnection <ip de saída do banco> -Port 27017` | `TcpTestSucceeded : False` |

### 4. Reexecução sem alterações (ACE-01 · Cenário 3)

Deploy de novo, com **exatamente os mesmos parâmetros** da etapa 3.

| Print | Onde | Deve aparecer |
|---|---|---|
| `06-sem-alteracoes.png` | resumo da execução | "Sem alterações" no Terraform e `PLAY RECAP` com `changed=0` em `app-vm` e `db-vm` |

### 5. Inventário (ACE-02, ACE-03)

Operação → `operation=inventory`, `environment=dev`. Depois, o console AWS.

| Print | Onde | Deve aparecer |
|---|---|---|
| `07-inventario.png` | resumo da execução | tabela com as duas VMs (`Role` app e db) e o volume `kubeshop-dev-mongo-data` |
| `08-aws-instancias.png` | *EC2 → Instâncias*, filtro `Project = kubeshop` | `vm-pm04-app-dev` e `vm-pm04-db-dev` *em execução*, com **ID da instância**, tipo `t3.micro` e IPs. Anote os dois IDs |
| `09-aws-sg-banco.png` | *EC2 → Security Groups* → `kubeshop-dev-db` → *Regras de entrada* | portas 22 e 27017 com origem no security group da aplicação (`sg-...`); nenhuma `0.0.0.0/0` |
| `10-aws-volume.png` | *EC2 → Volumes* → `kubeshop-dev-mongo-data` | *Em uso*, anexado à instância do banco (mesmo ID do print `08`) |

### 6. Aplicação (ACE-04)

No navegador, abra a URL da loja. Mantenha a **barra de endereço visível** nos três prints.

| Print | Onde | Deve aparecer |
|---|---|---|
| `11-loja-catalogo.png` | navegador | catálogo carregado e itens na sacola |
| `12-loja-confirmacao.png` | navegador, após "Confirmar pedido fictício" | confirmação com o **número do pedido**. Anote o número |
| `13-loja-recarregada.png` | navegador, após F5 | o **mesmo número de pedido** em "Meus pedidos" |

### 7. Saúde e rede privada (ACE-03, ACE-05)

Operação → `operation=health`.

| Print | Onde | Deve aparecer |
|---|---|---|
| `14-health.png` | job, passo "Saúde" | `orders=N` (anote N), tarefas "A porta do MongoDB NÃO pode responder pelo IP público" e "responde pela rede privada" com `ok` |

### 8. Persistência após reinício (ACE-05)

Operação → `operation=restart`, `restart_target=all`. Depois, Operação → `health`.

| Print | Onde | Deve aparecer |
|---|---|---|
| `15-restart.png` | execução do `restart`, passo "Reinício controlado" | reinício do `mongodb`, `kubeshop-api` e `kubeshop-frontend` e as esperas por `healthy` concluídas |
| `16-health-apos-restart.png` | execução do `health`, passo "Saúde" | **a mesma contagem** `orders=N` da etapa 7 |

### 9. Alteração de infraestrutura e manutenção (ACE-05, ACE-06 · Cenário 2)

Em *Settings → Environments → dev → Environment variables*, crie `DB_INSTANCE_TYPE` com
`t3.small` (tipo da VM do **banco**, onde ficam os dados).

Deploy → `action=apply`, `instance_type=t3.small`, `docker_tag=1.0.1`, `update_os=true`,
`extra_packages=curl, git, unzip, tree`.

As duas VMs são paradas e religadas com o novo tipo, sem recriação. O MongoDB volta com o
mesmo volume EBS.

| Print | Onde | Deve aparecer |
|---|---|---|
| `17-plan-alteracao.png` | resumo da execução | `aws_instance.app` e `aws_instance.db` *updated in-place* e `Plan: 0 to add, 2 to change, 0 to destroy` |
| `18-aws-mesmo-id.png` | *EC2 → Instâncias* | as duas VMs em `t3.small` com **os mesmos IDs** do print `08` |
| `19-versao.png` | navegador em `http://<ip>/api/info` | `"version":"1.0.1"` |
| `20-ansible-manutencao.png` | job *Ansible*, passo "ansible-playbook", tarefas "Instalar pacotes base e extras" e "Aplicar atualizações do SO" | `tree` instalado e a lista de pacotes atualizados (`changed`) |
| `21-loja-apos-alteracao.png` | navegador na loja | o **pedido da etapa 6** (mesmo número) no histórico |

Ao final, crie também `APP_INSTANCE_TYPE` = `t3.small`, para que deploys sem
`instance_type` (CI/CD da aplicação) não alterem o tamanho da VM.

### 10. Backup automatizado (ACE-07)

O agendamento de produção é diário às 06:00 UTC. Para capturar uma execução agendada
dentro da janela de testes:

1. Em [operations.yml](../.github/workflows/operations.yml), troque `cron: "0 6 * * *"`
   por `cron: "*/15 * * * *"` e faça commit na `main` (o agendamento só roda a partir dela).
2. Aguarde a primeira execução com evento `schedule` (o GitHub pode atrasar de 5 a 30 min).
3. Volte o `cron` para `"0 6 * * *"` e faça commit.

| Print | Onde | Deve aparecer |
|---|---|---|
| `22-backup-agendado.png` | *Actions* → Operação, filtro `event:schedule`, e o resumo da execução | evento `schedule` e `Backup enviado: s3://kubeshop-backups-.../dev/kubeshop-dev-<data>.archive.gz` |
| `23-aws-backups-s3.png` | *S3* → `kubeshop-backups-<conta>-us-east-1` → `dev/`; e aba *Gerenciamento* do bucket | os arquivos `.archive.gz` com data; a regra `retencao-backups` (14 dias) |

### 11. Restauração testada (ACE-07)

Operação → `operation=restore-test` (deixe `backup_file` vazio).

| Print | Onde | Deve aparecer |
|---|---|---|
| `24-restore-test.png` | job, passo "Restauração", tarefa "Resultado do teste de restauração" | `Backup restaurado (isolado): orders=N` e `Banco principal (agora): orders=N` |

### 12. Restauração no banco principal (ACE-07)

1. Operação → `backup`. Anote o nome do arquivo no resumo e a contagem de pedidos (N).
2. Na loja, crie mais um pedido (agora são N+1). Anote o número dele.
3. Operação → `restore-production`, `backup_file=<arquivo do passo 1>`,
   `confirm=RESTAURAR dev`.
4. Operação → `health`.

| Print | Onde | Deve aparecer |
|---|---|---|
| `25-restore-producao.png` | **resumo** da execução do `restore-production` | o backup de segurança e "Backup selecionado: <arquivo do passo 1>" |
| `26-dados-restaurados.png` | execução do `health`, passo "Saúde"; e a loja no navegador | `orders=N`; o pedido do passo 2 não aparece mais no histórico |

### 13. Diagnóstico (ACE-08, ACE-10)

Operação → `operation=logs`.

| Print | Onde | Deve aparecer |
|---|---|---|
| `27-logs.png` | job, passo "Logs e diagnóstico" | linhas de log de um contêiner e a tabela de CPU/memória/disco |

### 14. Credenciais fora dos logs (ACE-08)

Use a execução da etapa 3.

| Print | Onde | Deve aparecer |
|---|---|---|
| `28-credenciais.png` | job *Ansible*, passo "ansible-playbook", tarefa "Gravar senhas do MongoDB" | as tarefas sem nenhum valor de senha (`item=None` / `censored`) |

### 15. State do Terraform (escopo, seção 8)

| Print | Onde | Deve aparecer |
|---|---|---|
| `29-aws-state.png` | *S3* → `kubeshop-tfstate-<conta>-us-east-1` → `kubeshop/dev/`; e aba *Propriedades* | o arquivo `terraform.tfstate` e "Versionamento de bucket: Ativado" |

### 16. Reverter o agendamento

Confirme que o `cron` voltou para `"0 6 * * *"` (etapa 10, passo 3).

### 17. Desativação (ACE-08)

Somente depois de todas as outras etapas (e da apresentação, se houver demonstração ao
vivo). Deploy → `action=destroy`, `environment=dev`, `confirm_destroy=dev`.

| Print | Onde | Deve aparecer |
|---|---|---|
| `30-destroy.png` | resumo da execução | caminho do backup final no S3, `Destroy complete! Resources: 23 destroyed.` e a lista do que continua existindo |
| `31-aws-pos-destroy.png` | *EC2 → Instâncias* e lista de buckets do *S3* | as VMs `encerrada`; restam apenas os buckets `kubeshop-tfstate-*` e `kubeshop-backups-*` |

O que permanece após o destroy e como removê-lo: [operacao.md, seção 6](operacao.md#6-desativação).

## Observações

- O agendamento do backup foi alterado temporariamente para `*/15 * * * *` somente para
  registrar uma execução agendada durante os testes (etapa 10); o valor de operação é
  `0 6 * * *` (03:00 em Brasília).
- Registrar aqui falhas encontradas durante os testes, a causa e a correção aplicada.
