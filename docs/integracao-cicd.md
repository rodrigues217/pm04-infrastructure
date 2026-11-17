# Integração com o CI/CD da aplicação

## Responsabilidades

| Fluxo | Responsável | Faz | Não faz |
|---|---|---|---|
| CI/CD da aplicação | Zibiska Korp | testes, build e publicação das imagens com tag; dispara o deploy informando a tag | não acessa a AWS nem as VMs |
| Pipeline de deploy (`deploy.yml`) | infraestrutura | cria/altera a infraestrutura, configura as VMs e troca a versão dos contêineres | não constrói imagens |
| Pipeline de operação (`operations.yml`) | infraestrutura | saúde, logs, inventário, reinício, backup e restauração | não altera a infraestrutura |

O repositório da aplicação entregue não contém workflows. Para os testes desta entrega,
o workflow [app-images.yml](../.github/workflows/app-images.yml) faz o papel do CI/CD:
constrói as duas imagens a partir do repositório da aplicação e publica no GHCR.

## Pontos de integração

### 1. Imagens

| Item | Valor esperado |
|---|---|
| Registro | `ghcr.io/<organização>` (ou outro, informado em `docker_image`) |
| Nomes | `<registro>/kubeshop-api:<tag>` e `<registro>/kubeshop-frontend:<tag>` |
| Build | `apps/backend/Dockerfile` e `apps/frontend/Dockerfile`, contexto na raiz do repositório |
| Tag | imutável (versão ou SHA curto do commit). `latest` funciona só com `pull_images=true` |
| Visibilidade | pública. As VMs não fazem login no registro |

### 2. Contrato das imagens com o ambiente

A infraestrutura assume o comportamento atual das imagens. Mudanças nestes itens precisam
ser combinadas antes:

| Imagem | Contrato |
|---|---|
| API | escuta na porta 3000; lê `MONGO_HOST`, `MONGO_PORT`, `MONGO_DATABASE`, `MONGO_AUTH_SOURCE`, `MONGO_USERNAME`, `MONGO_PASSWORD_FILE`, `APP_VERSION`; responde `/api/health/ready` (inclui o banco) e `/api/info` (versão); contém `/app/scripts/smoke.mjs`; roda como uid 1000 com sistema de arquivos somente leitura |
| Frontend | escuta na porta 8080; responde `/healthz`; encaminha `/api` para o host `api:3000` |

### 3. Disparo do deploy

O CI/CD chama o workflow `deploy.yml` deste repositório pela API do GitHub
(`workflow_dispatch`). Parâmetros:

| Parâmetro | Valor | Observação |
|---|---|---|
| `action` | `apply` | |
| `environment` | `dev`, `homolog` ou `prod` | |
| `docker_tag` | tag publicada no passo anterior | obrigatório |
| `docker_image` | vazio ou o registro usado | vazio = `ghcr.io/<dono deste repositório>` |
| demais | não informar | `instance_type=ambiente` usa a variável `APP_INSTANCE_TYPE`; assim um deploy de aplicação não altera o tamanho da VM |

Exemplo de passo no workflow da aplicação:

```yaml
- name: Implantar em homologação
  env:
    GH_TOKEN: ${{ secrets.INFRA_DEPLOY_TOKEN }}
  run: |
    gh workflow run deploy.yml \
      --repo <organização>/<repositório-de-infraestrutura> \
      -f action=apply -f environment=homolog -f docker_tag=${{ env.IMAGE_TAG }}
```

### 4. Segredos e variáveis

No repositório da aplicação:

| Nome | Tipo | Conteúdo |
|---|---|---|
| `INFRA_DEPLOY_TOKEN` | secret | token fine-grained com permissão **Actions: read and write** apenas no repositório de infraestrutura |
| `GITHUB_TOKEN` | automático | publicação no GHCR (`packages: write`) |

No repositório de infraestrutura (já usados pelo deploy):

| Nome | Tipo | Escopo |
|---|---|---|
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` | secret | repositório ou ambiente |
| `SSH_PRIVATE_KEY` | secret | repositório ou ambiente |
| `MONGO_ROOT_PASSWORD`, `MONGO_APP_PASSWORD` | secret | por ambiente |
| `APP_INSTANCE_TYPE`, `DB_INSTANCE_TYPE` | variável | por ambiente |

Os valores não ficam no código nem aparecem nos logs (o GitHub mascara secrets e o Ansible
usa `no_log` nas tarefas que manipulam senhas).

### 5. Destino e verificação

- Endereço: `http://<Elastic IP>`, mostrado no resumo da execução do deploy.
- O deploy termina com falha se a API não ficar saudável ou se o smoke test falhar.
- Versão em execução: `GET http://<Elastic IP>/api/info`.
- Rollback: novo deploy com a tag anterior.
- Duas execuções no mesmo ambiente não rodam em paralelo; a segunda aguarda a primeira.
- Para exigir aprovação antes de produção: *Settings → Environments → prod → Required reviewers*.
