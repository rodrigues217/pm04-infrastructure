# Análise da demanda, decisões de arquitetura e custos

## 1. Análise da demanda (KubeShop · Zibiska Korp)

**O que o cliente tem:** frontend React servido por Nginx, API Node.js/Express e MongoDB
autenticado, validados localmente em um único Docker Compose.

**O que o cliente pede:** publicar a loja na nuvem com aplicação e banco em servidores
distintos, comunicação privada com o banco, persistência dos pedidos, segredos fora do
código e dos logs, e pipelines para criar, alterar, operar (reinício, saúde, logs, backup,
restauração) e desativar a infraestrutura, com estimativa de custo mensal justificada.

**Componentes e dependências identificados:**

| Componente | Imagem | Depende de | Onde roda |
|---|---|---|---|
| Frontend (Nginx + React) | `kubeshop-frontend:<tag>` | API (proxy `/api` para o host `api:3000`) | VM 1 |
| API Node.js/Express | `kubeshop-api:<tag>` | MongoDB (`MONGO_HOST`, usuário `kubeshop`) | VM 1 |
| MongoDB 8.0.17 | `mongo:8.0.17` | disco persistente, senhas root e da aplicação | VM 2 |

**Adaptações para hosts separados** (escopo, seção 5), sem alterar o código da aplicação:

- A API passa a usar `MONGO_HOST=<IP privado da VM 2>`; o próprio `config.js` do KubeShop já lê essa variável.
- A senha chega à API como arquivo (`MONGO_PASSWORD_FILE`), igual ao Compose original.
- O alias de rede `api` mantém o `nginx.conf` da imagem funcionando sem mudança.
- Ordem de inicialização: o playbook sobe o banco primeiro e só segue quando ele está `healthy`; a API tem health check que testa a conexão com o banco (`/api/health/ready`).
- O MongoDB publica a 27017 apenas no IP privado (no Compose original ficava numa rede Docker interna).

## 2. Decisões técnicas

| Decisão | Escolha | Justificativa |
|---|---|---|
| Provedor | **AWS, us-east-1** | Região mais barata e com mais serviços; compatível com AWS Academy; documentação ampla para Terraform |
| CI/CD | **GitHub Actions** | Código e pipeline no mesmo lugar; Secrets e Environments nativos; aceito pelo PM-04 |
| IaC | **Terraform** + state no S3 (versionado, criptografado, `use_lockfile`) | Exigido pelo PM-04; state por ambiente; lock impede execuções simultâneas |
| Configuração | **Ansible** com roles | Exigido pelo PM-04; idempotente; acessa o banco via bastion, sem expô-lo |
| Sistema operacional | Ubuntu 24.04 LTS | Suporte até 2029; Docker oficial disponível |
| VM da aplicação | `t3.micro` (2 vCPU, 1 GiB) | Nginx estático + uma API Node leve; burstable atende tráfego de demonstração |
| VM do banco | `t3.micro` (2 vCPU, 1 GiB) + swap de 1 GB | Cabe no Free Tier. O cache do WiredTiger fica limitado a 0,25 GB e o swap dá margem ao SO. Para tráfego real: `DB_INSTANCE_TYPE=t3.small` |
| Disco do banco | EBS gp3 10 GB **separado** do disco do sistema | Os dados sobrevivem a troca de tipo de VM, reinícios e até à recriação da VM |
| IP público | Elastic IP na VM da aplicação | O endereço da loja não muda quando a VM é parada (ex.: troca de `instance_type`) |
| Saída do banco | IP público só de saída, **sem nenhuma porta liberada** (padrão) ou NAT Gateway (`ENABLE_NAT_GATEWAY=true`) | NAT Gateway dobraria o custo mensal (+US$ 33). O SG do banco não tem regra para a internet e o Mongo escuta só no IP privado; a pipeline prova que 27017 não responde de fora |
| Acesso administrativo | SSH com chave; banco só via bastion; SSH da app aberto só para o IP do runner durante a execução | Nenhuma porta 22 aberta permanentemente para a internet |
| Imagens | GHCR com **tags explícitas** (`1.0.0`, `1.0.1`) | Reprodutível; atualização controlada pelo parâmetro `docker_tag`; `pull_images` cobre tags mutáveis |
| Backups | `mongodump` diário → S3 (14 dias de retenção) + restauração testada em MongoDB isolado | Atende "backups automatizados" e "restauração testada" sem sobrescrever o ambiente principal |
| DNS / TLS | **Não utilizados** nesta entrega; acesso por `http://<Elastic IP>` | O escopo do KubeShop deixa DNS/TLS opcionais. Evolução: domínio + Caddy/Certbot ou ALB + ACM |

**Limitações conhecidas:** uma única zona de disponibilidade (sem alta disponibilidade);
sem HTTPS; o MongoDB não é replica set; trocar as senhas depois da primeira inicialização
exige atualizar o usuário no banco (o script de init só roda com o disco vazio).

## 3. Estimativa de custo mensal

**Premissas:** AWS us-east-1, preços on-demand em USD (tabela pública da AWS, referência
nov/2026; confira na [AWS Pricing Calculator](https://calculator.aws/)), 730 h/mês (24×7),
um ambiente (`prod`), tráfego de demonstração (< 10 GB/mês).

| Item | Cálculo | US$/mês |
|---|---|---|
| VM aplicação t3.micro | 730 h × 0,0104 | 7,59 |
| VM banco t3.micro | 730 h × 0,0104 | 7,59 |
| Discos do sistema gp3 | 2 × 10 GB × 0,08 | 1,60 |
| Volume do MongoDB gp3 | 10 GB × 0,08 | 0,80 |
| IPv4 públicos (Elastic IP + saída do banco) | 2 × 730 h × 0,005 | 7,30 |
| S3 (state + backups, < 1 GB) | | 0,05 |
| Transferência de saída | primeiros 100 GB/mês gratuitos | 0,00 |
| GitHub Actions e GHCR | repositório/pacotes públicos | 0,00 |
| **Total (preço cheio, 24×7)** | | **≈ 24,90** |

- **Com NAT Gateway** (banco sem IP público): + 32,85 (gateway) + 0,045/GB processado, − 3,65 (IP do banco) ≈ **US$ 54/mês**.
- **Com banco em t3.small** (tráfego real): + 7,59 ≈ US$ 32,50/mês.

**Custo efetivo deste projeto acadêmico: US$ 0.** O total acima é o valor recorrente de
referência pedido pelo cliente; os créditos aparecem separados, como o escopo exige
("Créditos e faixas gratuitas... separadamente"):

| Faixa gratuita usada | Cobre |
|---|---|
| Créditos do plano gratuito da AWS (contas novas) | todo o consumo de EC2, EBS, IPv4 e S3 enquanto houver saldo |
| Uso só em testes e apresentação (≈ 30 h, `destroy` ao final de cada sessão) | ≈ US$ 1 de consumo, descontado dos créditos |
| GitHub Actions e GHCR em repositório público | sem custo |

Quando os créditos acabarem, o valor recorrente passa a ser o total de referência acima.
- **Após o `destroy`** continuam apenas os buckets S3 (centavos por mês).
- **O que pode alterar o consumo:** créditos de CPU das instâncias t3 (uso contínuo alto gera cobrança extra no modo unlimited), volume de backups e tráfego real.
