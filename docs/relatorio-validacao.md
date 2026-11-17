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

### 1. Publicar duas versões da aplicação (ACE-06)

*App KubeShop - publicar imagens*: `image_tag=1.0.0`; depois `image_tag=1.0.1`.

- `01-imagens.png`: resumo com as duas imagens publicadas.

### 2. Planejar (ACE-01)

Deploy: `action=plan`, `environment=dev`.

- `02-plan.png`: `Plan: N to add, 0 to change, 0 to destroy`.

### 3. Provisionar e configurar (ACE-01, ACE-03)

Deploy: `action=apply`, `environment=dev`, `instance_type=t3.micro`, `docker_tag=1.0.0`,
`update_os=false`, `extra_packages=curl, git, unzip`.

- `03-apply-recap.png`: `PLAY RECAP` com `failed=0` nas duas VMs.
- `04-isolamento.png`: passo "Evidência - MongoDB inacessível pela internet".

### 4. Inventário (ACE-02)

Operação: `inventory`, `environment=dev`.

- `05-inventario.png`: tabela com as duas VMs (`Role` app e db) e o volume do MongoDB.
- `06-console-ec2.png`: console EC2 com as duas VMs e as regras de entrada do security
  group `kubeshop-dev-db-sg` (27017 e 22 apenas do SG da aplicação).

### 5. Aplicação (ACE-04)

Abrir a URL do resumo do deploy. Conferir o catálogo, adicionar itens, confirmar o pedido.
Recarregar a página (F5).

- `07-loja-pedido.png`: confirmação do pedido.
- `08-loja-recarregada.png`: pedido listado no histórico depois de recarregar.

### 6. Saúde e rede privada (ACE-03)

Operação: `health`.

- `09-health.png`: `orders=1`, smoke test `PASS`, tarefa "A porta do MongoDB NÃO pode
  responder pelo IP público" ok e "responde pela rede privada" ok.

### 7. Persistência após reinício (ACE-05)

Operação: `restart`, `restart_target=all`. Em seguida, Operação: `health`.

- `10-restart.png`: os três contêineres `healthy` depois do reinício.
- `11-pedido-apos-reinicio.png`: `health` com a mesma contagem de `orders` e a loja com o
  pedido.

### 8. Alteração de infraestrutura (ACE-05)

Deploy: `action=apply`, `instance_type=t3.small`, `docker_tag=1.0.1`, `update_os=true`,
`extra_packages=curl, git, unzip, tree`.

- `12-plan-alteracao.png`: `instance_type: "t3.micro" -> "t3.small"`, `1 to change`,
  `0 to destroy`.
- `13-versao.png`: `http://<ip>/api/info` com a versão `1.0.1`.
- `14-pedido-apos-alteracao.png`: o pedido da etapa 5 no histórico.

Depois desta etapa, crie a variável de ambiente `APP_INSTANCE_TYPE=t3.small` em
*Settings → Environments → dev*, para que deploys sem `instance_type` mantenham o tamanho.

### 9. Disparo pelo CI/CD e reexecução sem alterações (ACE-01, ACE-06)

No terminal, como o CI/CD da aplicação faria:

```bash
gh workflow run deploy.yml -f action=apply -f environment=dev -f docker_tag=1.0.1
```

- `15-sem-alteracoes.png`: execução disparada por `workflow_dispatch`, Terraform
  "Sem alterações" e `PLAY RECAP` com `changed=0` nas duas VMs.

### 10. Backup automatizado (ACE-07)

Manter o ambiente `dev` ligado até o horário do agendamento (06:00 UTC). Em Actions,
abrir a execução do workflow de operação com evento `schedule`.

- `16-backup-agendado.png`: execução agendada com o arquivo enviado ao S3.

### 11. Restauração testada (ACE-07)

Operação: `restore-test` (sem `backup_file`).

- `17-restore-test.png`: "Backup restaurado (isolado): orders=N" e "Banco principal:
  orders=N".

### 12. Restauração no banco principal (ACE-07)

1. Operação: `backup`. Anote o nome do arquivo e a contagem de pedidos (N).
2. Na loja, crie mais um pedido (N+1).
3. Operação: `restore-production`, `backup_file=<arquivo do passo 1>`,
   `confirm=RESTAURAR dev`.
4. Operação: `health`.

- `18-restore-producao.png`: execução concluída com o backup de segurança e a restauração.
- `19-dados-restaurados.png`: `health` com `orders=N`; o pedido do passo 2 não aparece.

### 13. Diagnóstico (ACE-08, ACE-10)

Operação: `logs`.

- `20-logs.png`: logs dos contêineres e uso de CPU, memória e disco.

### 14. Credenciais fora dos logs (ACE-08)

- `21-credenciais.png`: tarefa "Gravar senhas do MongoDB" com `censored` e um passo com
  secrets exibidos como `***`.

### 15. Desativação (ACE-08)

Deploy: `action=destroy`, `confirm_destroy=dev`.

- `22-destroy.png`: backup final e a lista do que continua existindo.

## Observações

Registrar aqui falhas encontradas durante os testes, a causa e a correção aplicada.
