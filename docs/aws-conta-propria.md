# Preparar uma conta AWS própria

Faça uma vez, pelo console da AWS, logado como administrador da conta.
**Não** use as chaves do usuário root na pipeline.

## 1. Fazer de graça

1. Ao criar a conta, escolha o **plano gratuito (Free plan)**. Contas novas recebem créditos
   em dólar, e nesse plano a AWS **não cobra o cartão**: quando os créditos ou o prazo
   acabam, os recursos param em vez de gerar fatura. Veja o saldo em *Billing → Credits*.
2. Use os padrões do projeto: as duas VMs em `t3.micro` e a NAT Gateway desligada.
3. **Rode o `destroy` ao final de cada sessão de testes.** Ligado 24×7, o ambiente consumiria
   cerca de US$ 25/mês dos créditos; só nos testes e na apresentação (cerca de 30 h),
   cerca de US$ 1.
4. Deixe o repositório **público**: assim o GitHub Actions e as imagens no GHCR não têm custo.

## 2. Alerta de gastos (proteção extra)

*Billing and Cost Management → Budgets → Create budget → Use a template → Zero spend budget*:
você recebe um e-mail se qualquer valor passar a ser cobrado fora dos créditos.

## 3. Usuário exclusivo da pipeline (permissão mínima)

1. *IAM → Policies → Create policy → JSON*: cole o conteúdo de
   [iam-policy-pipeline.json](iam-policy-pipeline.json) e salve como `pm04-pipeline`.
   - A política permite EC2 **somente em us-east-1**, S3 **somente em buckets `kubeshop-*`**
     e a consulta do número da conta. Ela não dá acesso a IAM, billing nem a outros serviços.
   - Se usar outra região, troque `us-east-1` na política e crie a variável `AWS_REGION` no GitHub.
2. *IAM → Users → Create user*: nome `github-pm04`, **sem** acesso ao console.
   Em permissões, escolha *Attach policies directly* e marque `pm04-pipeline`.
3. Abra o usuário, vá em *Security credentials → Create access key*, escolha
   *Third-party service* e copie as duas chaves (elas só aparecem uma vez).

## 4. Secrets no GitHub

*Settings → Secrets and variables → Actions → New repository secret*:

| Secret | Valor |
|---|---|
| `AWS_ACCESS_KEY_ID` | access key do usuário `github-pm04` |
| `AWS_SECRET_ACCESS_KEY` | secret key do usuário `github-pm04` |
| `SSH_PRIVATE_KEY` | conteúdo do arquivo `kubeshop-deploy` (README, passo 2) |
| `MONGO_ROOT_PASSWORD` | `openssl rand -base64 24` |
| `MONGO_APP_PASSWORD` | `openssl rand -base64 24` (outra senha) |

Com conta própria **não** é preciso criar o `AWS_SESSION_TOKEN`.

## 5. Depois da apresentação

1. Deploy → `action=destroy`, `confirm_destroy=dev` (repita para cada ambiente criado).
2. Opcional: apague os buckets `kubeshop-tfstate-*` e `kubeshop-backups-*` no console do S3.
3. *IAM → Users → github-pm04 → Security credentials*: desative e exclua a access key.
