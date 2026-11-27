# Relatório de validação

| Item | Valor |
|---|---|
| Ambiente | `dev` |
| Região | us-east-1 |
| Commit validado | `8debdc6` (deploys, operação e restauração); destroy em `cb02a6e`, que só altera o horário do agendamento |
| Período dos testes | 25/11/2026 (backup agendado) e 27/11/2026 (demais testes) |
| Resultado geral | todos os critérios de aceite atendidos |

Evidências em [evidencias/](../evidencias/). Base dos links:
`https://github.com/rodrigues217/pm04-infrastructure/actions/runs/<id>`.

## Resultado por critério de aceite

| Critério | Evidências | Execução | Resultado |
|---|---|---|---|
| ACE-01 Reprodução | `02`, `03` | [45937227306](https://github.com/rodrigues217/pm04-infrastructure/actions/runs/45937227306) | Atendido: ambiente criado do zero pela pipeline, 23 recursos |
| ACE-02 Duas VMs | `02` | [45937227306](https://github.com/rodrigues217/pm04-infrastructure/actions/runs/45937227306) | Atendido: `vm-pm04-app-dev` e `vm-pm04-db-dev`, MongoDB só na VM do banco |
| ACE-03 Isolamento | `04` | [45937227306](https://github.com/rodrigues217/pm04-infrastructure/actions/runs/45937227306) | Atendido: 27017 não responde pela internet; API conectada pelo IP privado |
| ACE-04 Aplicação | `05` | navegador | Atendido: pedido `#bbbaff` criado e consultado após recarregar |
| ACE-05 Persistência | `06`, `07` (reinício); `09`, `11` (alteração) | [45938970357](https://github.com/rodrigues217/pm04-infrastructure/actions/runs/45938970357), [45939581276](https://github.com/rodrigues217/pm04-infrastructure/actions/runs/45939581276) | Atendido: pedido `#bbbaff` preservado após reinício e após troca de tipo das duas VMs |
| ACE-06 CI/CD | `01`, `10`; [integracao-cicd.md](integracao-cicd.md) | [45939581276](https://github.com/rodrigues217/pm04-infrastructure/actions/runs/45939581276) | Atendido: imagens publicadas com tag e implantadas pelo parâmetro `docker_tag` |
| ACE-07 Recuperação | `13`, `14`, `15`, `16` | [45659961552](https://github.com/rodrigues217/pm04-infrastructure/actions/runs/45659961552), [45942551414](https://github.com/rodrigues217/pm04-infrastructure/actions/runs/45942551414) | Atendido: backup agendado no S3; restauração testada com `orders=4` no backup e no banco |
| ACE-08 Administração | `06`, `12`, `17`; [operacao.md](operacao.md) | [45943204935](https://github.com/rodrigues217/pm04-infrastructure/actions/runs/45943204935) | Atendido: rotinas e desativação pela pipeline; senhas fora do código e dos logs |
| ACE-09 Custos | `18`; [arquitetura.md, seção 5](arquitetura.md#5-estimativa-de-custo-mensal) | [calculadora AWS](https://calculator.aws/#/estimate?id=72767dcfd4952808d7be8ab7fe59e32a9caebae1) | Atendido: US$ 24,90/mês, conferido na AWS Pricing Calculator |
| ACE-10 Transferência | [operacao.md](operacao.md), [inventario.md](inventario.md), [acesso-administrativo.md](acesso-administrativo.md) | — | Atendido |

## Cenários do enunciado PM-04

| Cenário | Evidências | Execução | Resultado |
|---|---|---|---|
| 1 · Criação inicial | `02`, `03` | [#11](https://github.com/rodrigues217/pm04-infrastructure/actions/runs/45937227306) | Terraform cria 23 recursos; Ansible instala pacotes, Docker, MongoDB e a loja `1.0.0` nas duas VMs |
| 2 · Atualização | `08`, `09`, `10` | [#12](https://github.com/rodrigues217/pm04-infrastructure/actions/runs/45939581276) | Terraform troca as duas VMs para `t3.small` no lugar (`2 changed`); Ansible atualiza o SO e a imagem para `1.0.1` |
| 3 · Reexecução sem alterações | `12` | [#13](https://github.com/rodrigues217/pm04-infrastructure/actions/runs/45940761270) | Terraform "Sem alterações"; Ansible `changed=0` nas duas VMs |

## Evidências

| # | Arquivo | Origem | O que mostra |
|---|---|---|---|
| 01 | `01-imagens-publicadas.png` | GHCR | `kubeshop-api` público, com as tags `1.0.0` e `1.0.1` |
| 02 | `02-terraform-criacao.png` | deploy #11 | `Apply complete! Resources: 23 added` e os outputs com as duas VMs |
| 03 | `03-ansible-criacao.png` | deploy #11 | PLAY RECAP com `failed=0` em `app-vm` e `db-vm` e as tarefas de pacotes, Docker, MongoDB e contêineres |
| 04 | `04-mongodb-isolado.png` | deploy #11 | `OK: 27017 não responde pela internet` |
| 05 | `05-pedido-criado.png` | navegador | pedido `#bbbaff` confirmado e listado em "Meus pedidos" |
| 06 | `06-restart.png` | operação #26 | reinício do MongoDB, da API e do frontend, todos `healthy` em seguida |
| 07 | `07-pedido-apos-restart.png` | navegador | pedido `#bbbaff` após o reinício |
| 08 | `08-variavel-db-instance-type.png` | GitHub | variável `DB_INSTANCE_TYPE=t3.small`, parâmetro do tipo da VM do banco |
| 09 | `09-terraform-alteracao.png` | deploy #12 | `Modifying...` nas duas VMs, mesmos IDs, `0 added, 2 changed, 0 destroyed` |
| 10 | `10-ansible-atualizacao-imagem.png` | deploy #12 | contêineres recriados de `1.0.0` para `1.0.1`, "Versão 1.0.1" |
| 11 | `11-pedido-apos-alteracao.png` | navegador | pedido `#bbbaff` após a troca das VMs e da versão |
| 12 | `12-sem-alteracoes.png` | deploy #13 | "Sem alterações" e `changed=0` nas duas VMs |
| 13 | `13-backup-agendado.png` | operação #18 | execução com evento **Scheduled** |
| 14 | `14-backup-enviado.png` | operação #18 | `Backup enviado: s3://.../kubeshop-dev-20261125T170247Z.archive.gz` |
| 15 | `15-backups-s3.png` | console AWS | backups diários no bucket `kubeshop-backups`, incluindo o arquivo do print 14 |
| 16 | `16-restore-test.png` | operação #28 | `orders=4` no backup restaurado e no banco principal |
| 17 | `17-destroy.png` | deploy #15 | `Destroy complete! Resources: 23 destroyed` |
| 18 | `18-calculadora-aws.png` | AWS Pricing Calculator | EC2 16,78 + EBS 0,80 + IPv4 7,30 + S3 0,02 = US$ 24,90/mês |

## Procedimento executado

| Etapa | Execução | Parâmetros |
|---|---|---|
| Publicar imagens | imagens [#1](https://github.com/rodrigues217/pm04-infrastructure/actions/runs/43995175173) e [#2](https://github.com/rodrigues217/pm04-infrastructure/actions/runs/43995395836) | `image_tag=1.0.0` e `1.0.1` |
| Criação | deploy [#11](https://github.com/rodrigues217/pm04-infrastructure/actions/runs/45937227306) | `apply`, `t3.micro`, `docker_tag=1.0.0`, `update_os=false`, `curl, git, unzip` |
| Pedido na loja | navegador | `http://98.87.237.80` |
| Reinício | operação [#26](https://github.com/rodrigues217/pm04-infrastructure/actions/runs/45938970357) | `restart`, `all` |
| Atualização | deploy [#12](https://github.com/rodrigues217/pm04-infrastructure/actions/runs/45939581276) | variável `DB_INSTANCE_TYPE=t3.small`; `apply`, `t3.small`, `docker_tag=1.0.1`, `update_os=true`, `curl, git, unzip` |
| Reexecução | deploy [#13](https://github.com/rodrigues217/pm04-infrastructure/actions/runs/45940761270) | mesmos parâmetros do #12, com `APP_INSTANCE_TYPE=t3.small` |
| Backup manual | operação [#27](https://github.com/rodrigues217/pm04-infrastructure/actions/runs/45942259201) | `backup` |
| Restauração testada | operação [#28](https://github.com/rodrigues217/pm04-infrastructure/actions/runs/45942551414) | `restore-test` |
| Desativação | deploy [#15](https://github.com/rodrigues217/pm04-infrastructure/actions/runs/45943204935) | `destroy`, `confirm_destroy=dev` |

## Observações

- **Pedidos automáticos:** cada deploy termina com o smoke test do KubeShop, que cria um
  pedido fictício. Por isso a persistência foi conferida pelo número do pedido feito no
  navegador (`#bbbaff`), e não pela quantidade de pedidos.
- **Backup agendado:** a evidência é a execução de 25/11 (#18), com o ambiente anterior no
  ar. O GitHub executou os agendamentos diários de 22 a 25/11 com 8 a 12 horas de atraso
  em relação ao horário configurado (06:00 UTC). Para a restauração testada (#28) foi feito
  antes um backup manual (#27) do ambiente de 27/11, para comparar o backup com o banco de
  origem.
- **Atualização do cenário 2:** a manutenção pelo Ansible foi a atualização do SO
  (`update_os=true`) e a troca da imagem para `1.0.1`; nenhum pacote novo foi adicionado.

### Falhas encontradas e correções

| Falha | Causa | Correção |
|---|---|---|
| Backup agendado falhou com o ambiente destruído | a checagem "ambiente existe" aceitava o aviso do Terraform "No outputs found" como IP | checagem pelos outputs em JSON (`01f7010`) |
| Contagem de pedidos mudava entre consultas | o `health` rodava o smoke test, que cria um pedido | `health` somente leitura; smoke test só no deploy (`ceb63f7`) |
| Risco de o MongoDB subir sem o volume após reboot | a montagem com `nofail` não era aguardada pelo Docker | `RequiresMountsFor=/srv/mongo` no serviço Docker (`ceb63f7`) |
| `restore-test` falhava ao recriar índices | o MongoDB temporário (512 MB) exige 500 MB livres por padrão | `indexBuildMinAvailableDiskSpaceMB=0` no contêiner temporário (`b206a33`) |
| Destroy recusado (deploy #14) | `confirm_destroy` não preenchido | comportamento esperado da trava; repetido com `confirm_destroy=dev` (#15) |
