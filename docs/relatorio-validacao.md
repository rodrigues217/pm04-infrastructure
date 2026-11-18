# Relatório de validação

| Item | Valor |
|---|---|
| Ambiente | `dev` |
| Região | us-east-1 |
| Commit validado | `<sha>` |
| Período dos testes | `<data início>` a `<data fim>` |

Evidências em [evidencias/](../evidencias/). Em "Execução", cole o link da execução no
GitHub Actions (`https://github.com/<dono>/<repo>/actions/runs/<id>`).

## Resultado por critério de aceite

| Critério | Evidência | Execução | Resultado |
|---|---|---|---|
| ACE-01 Reprodução | etapas 2, 3 e 9: `02`, `03`, `15` | | |
| ACE-02 Duas VMs | etapa 4: `05`, `06` | | |
| ACE-03 Isolamento | etapas 3 e 6: `04`, `09` | | |
| ACE-04 Aplicação | etapa 5: `07`, `08` | | |
| ACE-05 Persistência | etapas 7 e 8: `10`, `11`, `12`, `14` | | |
| ACE-06 CI/CD | etapas 1 e 9: `01`, `15`; [integracao-cicd.md](integracao-cicd.md) | | |
| ACE-07 Recuperação | etapas 10, 11 e 12: `16`, `17`, `18`, `19` | | |
| ACE-08 Administração | etapas 13, 14 e 15: `20`, `21`, `22`; [operacao.md](operacao.md) | | |
| ACE-09 Custos | [arquitetura.md, seção 5](arquitetura.md#5-estimativa-de-custo-mensal) | — | |
| ACE-10 Transferência | [operacao.md](operacao.md), [inventario.md](inventario.md), [acesso-administrativo.md](acesso-administrativo.md) | — | |

## Procedimento

Pré-requisitos: preparação da seção 1 de [operacao.md](operacao.md) concluída; variável
`APP_INSTANCE_TYPE` ainda não criada.

As etapas são sequenciais: cada uma depende do estado deixado pela anterior. A etapa 10
exige o ambiente ligado durante a madrugada; a etapa 15 é sempre a última.

Workflows citados, em *Actions*:

- **Imagens**: *App KubeShop - publicar imagens*
- **Deploy**: *Infra KubeShop - deploy (Terraform + Ansible)*
- **Operação**: *Infra KubeShop - operação (...)*

"Resumo" é o topo da página da execução, acima da lista de jobs. "Passo" é uma linha
dentro do job, expandida com um clique.

### 1. Publicar duas versões da aplicação (ACE-06)

Imagens → `image_tag=1.0.0`. Depois, de novo, com `image_tag=1.0.1`.
Em seguida, no perfil do dono do repositório → *Packages*, deixe `kubeshop-api` e
`kubeshop-frontend` públicos.

| Print | Onde | Deve aparecer |
|---|---|---|
| `01-imagens.png` | página do pacote `kubeshop-api` em *Packages* | as tags `1.0.0` e `1.0.1` |

### 2. Planejar (ACE-01)

Deploy → `action=plan`, `environment=dev`.

| Print | Onde | Deve aparecer |
|---|---|---|
| `02-plan.png` | resumo da execução | `Plan: N to add, 0 to change, 0 to destroy` |

### 3. Provisionar e configurar (ACE-01, ACE-03)

Deploy → `action=apply`, `environment=dev`, `instance_type=t3.micro`, `docker_tag=1.0.0`,
`update_os=false`, `extra_packages=curl, git, unzip`. Duração aproximada: 10 minutos.

| Print | Onde | Deve aparecer |
|---|---|---|
| `03-apply-recap.png` | resumo da execução | bloco "Ansible - PLAY RECAP" com `failed=0` em `app-vm` e `db-vm`, e a URL da loja |
| `04-isolamento.png` | job *Ansible*, passo "Evidência - MongoDB inacessível pela internet" | `OK: 27017 não responde pela internet` |

### 4. Inventário (ACE-02)

Operação → `operation=inventory`, `environment=dev`.

| Print | Onde | Deve aparecer |
|---|---|---|
| `05-inventario.png` | resumo da execução | tabela com as duas VMs (`Role` app e db) e o volume `kubeshop-dev-mongo-data` |
| `06-console-ec2.png` | console AWS → *EC2 → Security Groups* → `kubeshop-dev-db` → aba *Inbound rules* | portas 22 e 27017 com origem no security group da aplicação (`sg-...`), nenhuma `0.0.0.0/0` |

### 5. Aplicação (ACE-04)

No navegador, abra a URL do resumo da etapa 3. Adicione produtos à sacola e confirme o
pedido. Depois recarregue a página (F5).

| Print | Onde | Deve aparecer |
|---|---|---|
| `07-loja-pedido.png` | navegador, com a barra de endereço visível | catálogo e a confirmação do pedido |
| `08-loja-recarregada.png` | navegador, após F5 | o pedido no histórico |

### 6. Saúde e rede privada (ACE-03)

Operação → `operation=health`.

| Print | Onde | Deve aparecer |
|---|---|---|
| `09-health.png` | job, passo "Saúde" | `orders=1`, `Smoke test: PASS`, tarefas "A porta do MongoDB NÃO pode responder pelo IP público" e "responde pela rede privada" com `ok` |

### 7. Persistência após reinício (ACE-05)

Operação → `operation=restart`, `restart_target=all`. Depois, Operação → `health`.

| Print | Onde | Deve aparecer |
|---|---|---|
| `10-restart.png` | execução do `restart`, passo "Reinício controlado" | reinício do `mongodb`, `kubeshop-api` e `kubeshop-frontend` e as esperas por `healthy` concluídas |
| `11-pedido-apos-reinicio.png` | execução do `health`, passo "Saúde" | a mesma contagem `orders=1` da etapa 6 |

### 8. Alteração de infraestrutura (ACE-05)

Deploy → `action=apply`, `instance_type=t3.small`, `docker_tag=1.0.1`, `update_os=true`,
`extra_packages=curl, git, unzip, tree`.

| Print | Onde | Deve aparecer |
|---|---|---|
| `12-plan-alteracao.png` | resumo da execução | `# aws_instance.app will be updated in-place` e `Plan: 0 to add, 1 to change, 0 to destroy` |
| `13-versao.png` | navegador em `http://<ip>/api/info` | `"version":"1.0.1"` |
| `14-pedido-apos-alteracao.png` | navegador na loja | o pedido da etapa 5 no histórico |

Ao final, em *Settings → Environments → dev → Environment variables*, crie
`APP_INSTANCE_TYPE` com o valor `t3.small`.

### 9. Disparo pelo CI/CD e reexecução sem alterações (ACE-01, ACE-06)

No terminal, na pasta do repositório (simula o CI/CD da aplicação):

```bash
gh workflow run deploy.yml -f action=apply -f environment=dev -f docker_tag=1.0.1
```

| Print | Onde | Deve aparecer |
|---|---|---|
| `15-sem-alteracoes.png` | resumo da execução | "Sem alterações" no Terraform e `PLAY RECAP` com `changed=0` em `app-vm` e `db-vm` |

### 10. Backup automatizado (ACE-07)

Mantenha o ambiente ligado durante a madrugada. O agendamento é às 06:00 UTC e o GitHub
pode atrasar a execução. Pela manhã, em *Actions* → Operação, procure a execução com o
rótulo `schedule`.

| Print | Onde | Deve aparecer |
|---|---|---|
| `16-backup-agendado.png` | lista de execuções de Operação + resumo da execução agendada | evento `schedule` e `Backup enviado: s3://kubeshop-backups-.../dev/kubeshop-dev-<data>.archive.gz` |

### 11. Restauração testada (ACE-07)

Operação → `operation=restore-test` (deixe `backup_file` vazio).

| Print | Onde | Deve aparecer |
|---|---|---|
| `17-restore-test.png` | job, passo "Restauração", tarefa "Resultado do teste de restauração" | `Backup restaurado (isolado): orders=N` e `Banco principal (agora): orders=N` |

### 12. Restauração no banco principal (ACE-07)

1. Operação → `backup`. Anote o nome do arquivo que aparece no resumo e a contagem de
   pedidos (N).
2. Na loja, crie mais um pedido (agora são N+1).
3. Operação → `restore-production`, `backup_file=<arquivo do passo 1>`,
   `confirm=RESTAURAR dev`.
4. Operação → `health`.

| Print | Onde | Deve aparecer |
|---|---|---|
| `18-restore-producao.png` | resumo da execução do `restore-production` | o backup de segurança e "Backup selecionado: <arquivo do passo 1>" |
| `19-dados-restaurados.png` | execução do `health`, passo "Saúde" | `orders=N`; o pedido do passo 2 não existe mais |

### 13. Diagnóstico (ACE-08, ACE-10)

Operação → `operation=logs`.

| Print | Onde | Deve aparecer |
|---|---|---|
| `20-logs.png` | job, passo "Logs e diagnóstico" | linhas de log de um contêiner e a tabela de CPU/memória/disco |

### 14. Credenciais fora dos logs (ACE-08)

Use a execução da etapa 3.

| Print | Onde | Deve aparecer |
|---|---|---|
| `21-credenciais.png` | job *Ansible*, passo "ansible-playbook", tarefa "Gravar senhas do MongoDB" | o conteúdo como `censored`, sem senha |

### 15. Desativação (ACE-08)

Somente depois de todas as outras etapas (e da apresentação, se houver demonstração ao
vivo). Deploy → `action=destroy`, `environment=dev`, `confirm_destroy=dev`.

| Print | Onde | Deve aparecer |
|---|---|---|
| `22-destroy.png` | resumo da execução | caminho do backup final no S3 e a lista do que continua existindo |

O que permanece após o destroy e como removê-lo: [operacao.md, seção 6](operacao.md#6-desativação).

## Observações

Registrar aqui falhas encontradas durante os testes, a causa e a correção aplicada.
