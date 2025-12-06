# 🔄 Fluxo Completo na Prática

## Cenário: Nova feature indo para produção

```bash
┌─────────────────────────────────────────────────┐
│ 1. DESENVOLVIMENTO                              │
│ → Dev roda: ./scripts/setup-dev.sh              │
│ → Desenvolve feature                            │
│ → Testa localmente                              │
│ → Git commit + push                             │
└──────────────────┬──────────────────────────────┘
                   │
                   ↓ (CI/CD automático)
┌─────────────────────────────────────────────────┐
│ 2. STAGING                                      │
│ → CI roda: ./scripts/deploy-staging.sh          │
│ → Backup automático ✅                          │
│ → Deploy ✅                                     │
│ → Health check ✅                               │
│ → QA testa                                      │
└──────────────────┬──────────────────────────────┘
                   │
                   ↓ (Manual approval)
┌─────────────────────────────────────────────────┐
│ 3. PRODUÇÃO                                     │
│ → DevOps roda: ./scripts/deploy-prod.sh         │
│ → Backup automático ✅                          │
│ → Blue-green deploy ✅                          │
│ → Health check ✅                               │
│ → Se falhar: Rollback automático ✅             │
│ → Slack notifica team ✅                        │
└─────────────────────────────────────────────────┘
                   │
                   ↓ (Cron job diário)
┌─────────────────────────────────────────────────┐
│ 4. BACKUP (todo dia 2h da manhã)               │
│ → Cron: ./scripts/backup.sh production          │
│ → pg_dump ✅                                    │
│ → Validação ✅                                  │
│ → Upload S3 ✅                                  │
│ → Cleanup old backups ✅                        │
└─────────────────────────────────────────────────┘
```

# 📊 Resumo Final - Scripts Helper

## ✅ Scripts Criados:

```bash
| Script              | Função                | Quando Usar              |
| ------------------- | --------------------- | ------------------------ |
| `setup-dev.sh`      | Setup completo de dev | Nova máquina, onboarding |
| `deploy-staging.sh` | Deploy automatizado   | Merge para staging       |
| `backup.sh`         | Backup do banco       | Diário (cron) ou manual  |
| `logs.sh`           | Ver logs facilmente   | Troubleshooting, debug   |
```

# 🎯 Raciocínio Resumido de Cada Script:

## 1. setup-dev.sh

```bash
Problema: Novo dev demora 2h para configurar ambiente
Solução: Script faz em 5 minutos
Raciocínio:
  1. Valida tudo (fail fast)
  2. Cria .env automaticamente
  3. Sobe containers na ordem certa
  4. Aguarda ficarem prontos (evita race conditions)
  5. Mostra URLs para acessar
```

## 2. deploy-staging.sh

```bash
Problema: Deploy manual é arriscado e inconsistente
Solução: Script automatiza com segurança
Raciocínio:
  1. Backup ANTES (safety first!)
  2. Valida branch (staging só da branch staging)
  3. Pull code + mostrar changelog
  4. Build imagens
  5. Deploy zero downtime
  6. Health check
  7. SE FALHAR: Rollback automático
```

## 3. backup.sh

```bash
Problema: "Temos backup?" → "Backup? 🤔"
Solução: Backup automático diário
Raciocínio:
  1. Determina ambiente (retention policy diferente)
  2. Faz pg_dump
  3. VALIDA backup (crítico!)
  4. Upload remoto (S3) - proteção extra
  5. Cleanup old backups
  6. Metadata para auditoria
```

## 4. logs.sh

```bash
Problema: docker-compose logs é verboso e complicado
Solução: Interface amigável para logs
Raciocínio:
  1. Shortcuts (logs.sh backend)
  2. Cores (ERROR em vermelho, INFO em verde)
  3. Filtros (--grep ERROR)
  4. Análise rápida (conta erros automaticamente)
```

Lembre-se:

"Automatize tarefas repetitivas.
Foque em resolver problemas, não em memorizar comandos."
— DevOps Way
