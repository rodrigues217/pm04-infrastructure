# Arquitetura, decisões e custos

## 1. Diagnóstico da aplicação

A aplicação fornecida (`LaercioMLB/kube-shop-v2`) roda localmente em um único projeto
Docker Compose com três serviços:

| Componente | Origem | Depende de | Onde roda na nuvem |
|---|---|---|---|
| Frontend React + Nginx | `apps/frontend/Dockerfile` | API (proxy de `/api` para `api:3000`) | VM 1 |
| API Node.js/Express | `apps/backend/Dockerfile` | MongoDB (`MONGO_HOST`, usuário `kubeshop`) | VM 1 |
| MongoDB 8.0.17 | imagem oficial `mongo` | disco persistente, senhas root e da aplicação | VM 2 |

O repositório da aplicação não contém pipelines. Os pontos de integração com o CI/CD
estão descritos em [integracao-cicd.md](integracao-cicd.md).

### Adaptações para hosts separados

Nenhuma alteração no código da aplicação foi necessária:

- A API recebe `MONGO_HOST=<IP privado da VM 2>`; o `config.js` já lê essa variável.
- A senha chega à API como arquivo (`MONGO_PASSWORD_FILE`), como no Compose original.
- O contêiner da API recebe o alias de rede `api`, mantendo o `nginx.conf` da imagem.
- Ordem de inicialização: o playbook sobe o MongoDB primeiro e só configura a VM 1 depois
  que o banco está `healthy`. O health check da API (`/api/health/ready`) testa a conexão
  com o banco.
- O MongoDB publica a porta 27017 somente no IP privado da VM 2. No Compose ela ficava em
  uma rede Docker interna.

## 2. Arquitetura

```
                Internet
                    │ HTTP :80
                    ▼
┌──────────────────────── VPC 10.40.0.0/16 (us-east-1) ────────────────────────┐
│                                                                               │
│  Sub-rede pública 10.40.1.0/24            Sub-rede de dados 10.40.2.0/24      │
│  ┌──────────────────────────────┐         ┌───────────────────────────────┐   │
│  │ VM 1 · aplicação (t3.micro)  │ privada │ VM 2 · banco (t3.micro)       │   │
│  │ Elastic IP                   │ :27017  │ sem portas de entrada públicas│   │
│  │ ┌──────────────────────────┐ │────────▶│ ┌───────────────────────────┐ │   │
│  │ │ kubeshop-frontend        │ │         │ │ mongodb 8.0.17 (auth)     │ │   │
│  │ │ Nginx + React  :80→8080  │ │         │ └─────────────┬─────────────┘ │   │
│  │ │        │ /api            │ │  SSH    │               │               │   │
│  │ │ kubeshop-api  Node :3000 │ │(bastion)│   EBS gp3 10 GB (/srv/mongo)  │   │
│  │ └──────────────────────────┘ │────────▶│                               │   │
│  └──────────────────────────────┘         └───────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────────────┘
   S3: state do Terraform (versionado)  ·  S3: backups do MongoDB (14 dias)
```

**Acesso à loja:** `http://<Elastic IP da VM 1>`, porta 80. O endereço é exibido no
resumo de cada execução do deploy e na operação `inventory`. Não há DNS nem TLS nesta
entrega (ver limitações).

**Fluxo:** o navegador acessa o Nginx na VM 1, que entrega o React e encaminha `/api` para
a API no mesmo host. Somente a API acessa o MongoDB, pela rede privada da VPC.

### Atendimento dos requisitos

| Requisito | Implementação |
|---|---|
| REQ-01 Servidores | `aws_instance.app` e `aws_instance.db` em [terraform/main.tf](../terraform/main.tf). Recursos adicionais (Elastic IP, volume EBS, buckets S3) justificados na seção 3 |
| REQ-02 Banco isolado | MongoDB só na VM 2. Porta publicada só no IP privado. O security group do banco não tem regra de entrada para a internet |
| REQ-03 Rede privada | A regra de entrada da 27017 aceita apenas o security group da VM 1. A API usa o IP privado. Procedimento administrativo: [acesso-administrativo.md](acesso-administrativo.md) |
| REQ-04 Acessos | SSH por chave. Banco só via VM 1. A porta 22 da VM 1 é aberta para o IP do runner durante a execução e fechada ao final. Senhas e chaves em GitHub Secrets, gravadas nas VMs com permissão 0400 e `no_log` no Ansible |
| REQ-05 Persistência | Volume EBS dedicado em `/srv/mongo`. Troca de `instance_type` é feita no lugar (stop/start), sem recriar VM nem volume |

## 3. Decisões técnicas

| Decisão | Escolha | Motivo |
|---|---|---|
| Provedor e região | AWS, us-east-1 | Uma das regiões de menor preço para EC2 e EBS; provider Terraform maduro; IAM permite restringir a pipeline a uma região e a buckets com prefixo |
| Infraestrutura como código | Terraform | Plano de execução antes de aplicar (`plan`), detecção de drift, state remoto com lock e um mesmo código para vários ambientes |
| Configuração das VMs | Ansible | Sem agente nas VMs (usa SSH), acessa o banco pela VM 1 como bastion, módulos idempotentes para Docker e pacotes |
| Pipelines | GitHub Actions | Mesmo lugar do código; secrets mascarados nos logs; Environments separam segredos e permitem aprovação por ambiente; agendamento nativo para o backup |
| Execução nas VMs | Docker com as imagens da aplicação | Reaproveita os Dockerfiles já validados pela Zibiska; versão da aplicação controlada pela tag |
| Sistema operacional | Ubuntu 24.04 LTS | Suporte até 2029; pacotes oficiais do Docker |
| VM da aplicação | t3.micro (2 vCPU, 1 GiB) | Nginx com arquivos estáticos e uma API Node com catálogo em memória; o consumo real aparece na operação `logs` (`docker stats`, `free -h`) |
| VM do banco | t3.micro (2 vCPU, 1 GiB) + 1 GB de swap | Base de pedidos pequena; cache do WiredTiger limitado a 0,25 GB. Para tráfego real, `DB_INSTANCE_TYPE=t3.small` |
| Disco do banco | EBS gp3 10 GB separado do disco do sistema | Os dados não dependem do ciclo de vida da VM |
| IP público da loja | Elastic IP | O endereço não muda quando a VM é parada para trocar de tipo |
| Saída do banco para a internet | IP público só de saída (padrão) ou NAT Gateway (`ENABLE_NAT_GATEWAY=true`) | A NAT Gateway mais que dobraria o custo mensal. Sem ela, o security group continua sem regras de entrada públicas e o MongoDB escuta só no IP privado; a pipeline testa a porta 27017 pelo IP público a cada deploy |
| Imagens | GHCR, tags explícitas (`1.0.0`, `1.0.1`) | Implantação reproduzível e rollback trocando a tag |
| Backups | `mongodump` diário para S3, retenção de 14 dias | Cópia fora das VMs, sobrevive a um `destroy`; restauração testada em instância isolada |
| DNS e TLS | Não utilizados | O escopo não exige domínio. Evolução: registro DNS apontando para o Elastic IP e certificado via Caddy ou Certbot na VM 1 |

### State do Terraform

- **Armazenamento:** bucket `kubeshop-tfstate-<conta>-<região>`, chave
  `kubeshop/<ambiente>/terraform.tfstate` (um state por ambiente).
- **Proteção:** versionamento, criptografia SSE-S3, bloqueio de acesso público, lock por
  arquivo `.tflock` (`use_lockfile`) e `concurrency` no GitHub Actions por ambiente. A
  política IAM da pipeline só acessa buckets `kubeshop-*`. O bucket é criado por
  [scripts/bootstrap-backend.sh](../scripts/bootstrap-backend.sh), fora do Terraform, para
  que um `destroy` não o remova. O state não contém senhas: elas vão direto dos secrets
  para o Ansible.
- **Recuperação:** procedimento em [operacao.md](operacao.md#7-state-do-terraform).

## 4. Limitações

- Uma única zona de disponibilidade; sem alta disponibilidade.
- Sem HTTPS e sem domínio.
- MongoDB em instância única, sem replica set. Perda máxima de dados: até o último backup
  (diário), caso o volume EBS seja perdido.
- As imagens precisam ser públicas no registro; as VMs não autenticam no GHCR.
- Trocar as senhas do MongoDB depois da primeira inicialização exige atualizar os usuários
  no banco. O script de criação de usuário só roda com o disco vazio.
- A VM do banco tem IP público de saída quando a NAT Gateway está desligada.

## 5. Estimativa de custo mensal

### Premissas

| Item | Valor |
|---|---|
| Provedor e região | AWS, us-east-1 (N. Virginia) |
| Moeda | USD, preços on-demand, sem impostos |
| Data de referência | novembro de 2026 |
| Período | 1 mês = 730 horas, ambiente ligado 24×7 |
| Ambientes | 1 (`prod`) |
| Tráfego | até 10 GB/mês de saída |

### Composição

| Item | Detalhe | Cálculo | US$/mês |
|---|---|---|---|
| VM 1 aplicação | t3.micro, 2 vCPU, 1 GiB | 730 h × 0,0104 | 7,59 |
| VM 2 banco | t3.micro, 2 vCPU, 1 GiB | 730 h × 0,0104 | 7,59 |
| Discos do sistema | 2 × gp3 10 GB | 20 GB × 0,08 | 1,60 |
| Volume do MongoDB | gp3 10 GB | 10 GB × 0,08 | 0,80 |
| IPv4 públicos | Elastic IP da VM 1 + IP de saída da VM 2 | 2 × 730 h × 0,005 | 7,30 |
| S3 | state + 14 backups diários (< 1 GB, incluindo versões) | | 0,05 |
| Transferência de saída | até 100 GB/mês sem cobrança | | 0,00 |
| Logs | rotação local no Docker + logs do GitHub Actions; sem CloudWatch | | 0,00 |
| GitHub Actions | ~150 min/mês (backup diário + deploys); repositório público | | 0,00 |
| GHCR | pacotes públicos | | 0,00 |
| **Total** | | | **24,93** |

Variações:

- Com NAT Gateway: + 32,85 (730 h × 0,045) + 0,045/GB processado − 3,65 (IP de saída do banco) ≈ **US$ 54/mês**.
- Banco em t3.small: + 7,59 ≈ **US$ 32,50/mês**.
- Repositório privado: o GitHub Free inclui 2.000 min/mês; acima disso, US$ 0,008/min.

### Fontes

- EC2 on-demand: https://aws.amazon.com/ec2/pricing/on-demand/
- EBS: https://aws.amazon.com/ebs/pricing/
- IPv4 público: https://aws.amazon.com/vpc/pricing/
- S3: https://aws.amazon.com/s3/pricing/
- GitHub Actions: https://docs.github.com/billing/managing-billing-for-your-products/managing-billing-for-github-actions/about-billing-for-github-actions

### Créditos e faixas gratuitas (não incluídos no total)

| Benefício | Efeito |
|---|---|
| Créditos do plano gratuito da AWS para contas novas | Abatem o consumo enquanto houver saldo; o total acima volta a valer quando acabam |
| 100 GB/mês de transferência de saída da AWS | Já considerado como custo zero na linha de transferência |
| GitHub Actions e GHCR em repositório público | Sem cobrança |

### O que pode alterar o valor

- Uso contínuo de CPU acima da linha de base das instâncias t3 (modo unlimited cobra créditos de CPU excedentes).
- Crescimento da base e do tamanho dos backups.
- Tráfego acima de 100 GB/mês.
- Ambientes adicionais (`dev`, `homolog`) ligados ao mesmo tempo: cada um soma o valor completo.
- Após um `destroy`, ficam apenas os buckets S3 (centavos por mês).
