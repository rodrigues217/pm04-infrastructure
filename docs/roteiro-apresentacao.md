# Roteiro da apresentação e das evidências

Antes: configuração inicial do README feita, imagens `1.0.0` e `1.0.1` publicadas.
Salve um print de cada passo marcado com 📸 na pasta `evidencias/`.

## Cenário 1 · Criação inicial

Deploy → `action=apply`, `environment=dev`, `instance_type=t3.micro`, `docker_tag=1.0.0`,
`update_os=false`, `extra_packages=curl, git, unzip`.

- 📸 `01-plan.png`: resumo do plano com `Plan: N to add, 0 to change, 0 to destroy`.
- 📸 `02-ansible.png`: tarefas instalando Docker, montando o volume e subindo os 3 contêineres.
- 📸 `03-recap.png`: `PLAY RECAP` com `failed=0`.
- 📸 `04-isolamento.png`: passo "Evidência - MongoDB inacessível pela internet".
- 📸 `05-loja.png`: loja aberta no navegador pelo Elastic IP; **faça um pedido**.
- 📸 `06-aws.png`: console EC2 com as duas VMs e o security group do banco.

## Cenário 2 · Atualização do ambiente

Deploy → mesmos parâmetros, mas `instance_type=t3.small`, `docker_tag=1.0.1`,
`update_os=true`, `extra_packages=curl, git, unzip, tree`.

- 📸 `07-plan-update.png`: `1 to change` com `instance_type: "t3.micro" -> "t3.small"` (**atualização no lugar, sem recriar**).
- 📸 `08-ansible-update.png`: tarefas `changed` em atualização do SO, pacote `tree` e recriação dos contêineres da aplicação.
- 📸 `09-versao.png`: `/api/info` mostrando `1.0.1`.
- 📸 `10-pedido-preservado.png`: o pedido do cenário 1 continua em **Meus pedidos** (dados preservados após a mudança de infraestrutura).

## Cenário 3 · Reexecução sem alterações

Deploy com **exatamente** os mesmos parâmetros do cenário 2, mas `update_os=false`.

- 📸 `11-no-changes.png`: Terraform "**Sem alterações**" (o apply nem é executado).
- 📸 `12-idempotente.png`: `PLAY RECAP` com **`changed=0`** nas duas VMs.

## Validação da demanda (rotinas extras)

- 📸 `13-backup.png`: Operação → `backup`, com o arquivo no S3.
- 📸 `14-restore-test.png`: Operação → `restore-test` mostrando `orders=N` no backup e no banco principal.
- 📸 `15-health.png`: Operação → `health` com o smoke test `PASS`.
- 📸 `16-destroy.png` (no fim): Deploy → `destroy`, com o resumo do que continua existindo.

## Roteiro do PDF de entrega

1. Capa: integrantes, disciplina, link do repositório.
2. Análise da demanda: seção 1 de `docs/decisoes-e-custos.md`.
3. Arquitetura: diagrama do README + tabela de decisões.
4. Matriz requisito → solução: tabela do README.
5. Pipeline e parâmetros: tabelas do README.
6. Custos: seção 3 de `docs/decisoes-e-custos.md`.
7. Evidências: prints 01–16 com uma linha explicando cada um.
8. Operação e limitações: `docs/operacao.md` (resumo) + limitações conhecidas.
