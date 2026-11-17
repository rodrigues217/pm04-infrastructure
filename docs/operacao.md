# Manual de operação (equipe da Zibiska Korp)

Todas as rotinas rodam em **Actions** no GitHub. Nenhuma exige acesso manual às VMs.
O resultado de cada execução fica na página da execução (resumo + logs). Senhas nunca aparecem.

## Rotinas do dia a dia (não removem nada)

| Rotina | Workflow → parâmetros | Resultado esperado | Se falhar |
|---|---|---|---|
| Ver o que mudaria | Deploy → `action=plan` | resumo do plano; nada é alterado | ler o erro do `terraform plan` |
| Criar/atualizar | Deploy → `action=apply` + parâmetros | `PLAY RECAP ... failed=0` e URL da loja | rodar de novo (é idempotente); se persistir, ver "Logs" |
| Publicar nova versão | 1) App images `image_tag=X` 2) Deploy `docker_tag=X` | `/api/info` mostra a versão X | voltar: Deploy com a tag anterior |
| Atualizar o SO | Deploy → `update_os=true` | pacotes atualizados; reinício automático se necessário | rodar `health`; ver `logs` |
| Saúde | Operação → `health` | contêineres healthy + smoke test `PASS` | rodar `logs` |
| Logs | Operação → `logs` | 150 linhas por contêiner + CPU/memória/disco | — |
| Reiniciar | Operação → `restart` + `all/app/db` | serviços healthy | ver `logs`; depois Deploy `apply` |
| Backup | Operação → `backup` (também diário às 03:00) | arquivo em `s3://kubeshop-backups-.../<ambiente>/` | ver espaço em disco com `logs` |
| Testar restauração | Operação → `restore-test` | contagens do backup e do banco principal; principal intacto | escolher outro arquivo em `backup_file` |

## Rotinas que alteram ou removem dados (exigem confirmação)

| Rotina | Parâmetros | O que acontece |
|---|---|---|
| Restaurar no banco principal | Operação → `restore-production`, `confirm=RESTAURAR <ambiente>` | faz backup de segurança, substitui os dados pelo backup escolhido (ou o anterior ao de segurança), reinicia a API e roda o teste de saúde |
| Desativar ambiente | Deploy → `action=destroy`, `confirm_destroy=<ambiente>` | faz backup final no S3 e remove VMs, volume, IP, rede e SGs. **Os dados do volume são apagados**; ficam os backups (14 dias) e o state |

## Recuperação em caso de falha

- **Deploy falhou no Terraform:** nada foi aplicado parcialmente fora do state; corrigir e rodar de novo. O state é versionado no S3 (dá para voltar a uma versão anterior pelo console do S3).
- **Deploy falhou no Ansible:** a infraestrutura existe; rodar o deploy de novo. O playbook só muda o que estiver diferente.
- **Versão nova com defeito:** rodar o deploy com o `docker_tag` anterior (rollback em ~1 min).
- **Dados corrompidos:** `restore-test` para conferir um backup e depois `restore-production`.
- **VM do banco perdida:** o volume EBS é independente; um `apply` recria a VM e o Ansible remonta o mesmo volume.

## Integração com o CI/CD da aplicação

O CI/CD da aplicação (representado por `app-images.yml`) entrega imagens com tag em
`ghcr.io/<owner>/kubeshop-api` e `kubeshop-frontend`. A infraestrutura só consome a tag
(`docker_tag`). Para integrar o CI/CD real da Zibiska Korp basta ele publicar nesse registro
(ou informar outro em `docker_image`) e disparar o deploy com:

```bash
gh workflow run deploy.yml -f environment=prod -f docker_tag=1.0.1
```
