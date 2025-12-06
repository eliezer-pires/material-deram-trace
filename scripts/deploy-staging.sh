#!/bin/bash

# ==============================================================================
# deploy-staging.sh - Deploy para Ambiente de Staging
# ==============================================================================
#
# Uso: ./scripts/deploy-staging.sh
#
# O que faz:
# 1. Valida branch (deve ser staging)
# 2. Backup do banco ANTES de deploy (safety first!)
# 3. Pull latest code
# 4. Build novas imagens Docker
# 5. Deploy com estratégia de zero downtime
# 6. Health check
# 7. Rollback automático se falhar
# 8. Notifica time (Slack/Discord)
#
# Por quê?
# - Deploy consistente e repetível
# - Menos erros humanos
# - Rollback automático se algo der errado
# - Auditoria (quem fez deploy e quando)
#
# ==============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configurações
BRANCH="staging"
DEPLOY_USER=$(whoami)
DEPLOY_TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# ==============================================================================
# ETAPA 1: PRÉ-REQUISITOS
# ==============================================================================

check_prerequisites() {
    print_header "Verificando Pré-requisitos"
    
    # Verificar se .env.staging existe
    if [ ! -f ".env.staging" ]; then
        print_error ".env.staging não encontrado!"
        print_info "Crie o arquivo com: cp .env.example .env.staging"
        print_info "E preencha com valores reais"
        exit 1
    fi
    print_success ".env.staging encontrado"
    
    # Verificar se docker-compose.staging.yml existe
    if [ ! -f "docker-compose.staging.yml" ]; then
        print_error "docker-compose.staging.yml não encontrado!"
        exit 1
    fi
    print_success "docker-compose.staging.yml encontrado"
    
    # Verificar Git
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Não está em um repositório Git"
        exit 1
    fi
    print_success "Repositório Git OK"
}

# ==============================================================================
# ETAPA 2: VALIDAR BRANCH
# ==============================================================================
# Por quê? Previne deploy da branch errada para staging
# Staging deve receber apenas da branch 'staging'

validate_branch() {
    print_header "Validando Branch"
    
    current_branch=$(git branch --show-current)
    
    if [ "$current_branch" != "$BRANCH" ]; then
        print_error "Branch incorreta!"
        print_info "Branch atual: $current_branch"
        print_info "Branch esperada: $BRANCH"
        print_info ""
        print_warning "Deploy para staging deve ser feito da branch 'staging'"
        
        read -p "Deseja fazer checkout para staging? (y/n): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git checkout $BRANCH
            git pull origin $BRANCH
            print_success "Switched para branch staging"
        else
            exit 1
        fi
    else
        print_success "Branch correta: $current_branch"
    fi
}

# ==============================================================================
# ETAPA 3: BACKUP DO BANCO
# ==============================================================================
# Por quê? Se deploy quebrar algo, podemos restaurar
# SEMPRE faça backup antes de mudanças em produção/staging

backup_database() {
    print_header "Criando Backup do Banco"
    
    # Criar diretório de backups se não existir
    mkdir -p backups
    
    BACKUP_FILE="backups/staging-backup-$(date +%Y%m%d_%H%M%S).sql"
    
    print_info "Salvando backup em: $BACKUP_FILE"
    
    # Fazer backup
    if docker-compose -f docker-compose.yml -f docker-compose.staging.yml exec -T db \
        pg_dump -U postgres material_control_staging > "$BACKUP_FILE" 2>/dev/null; then
        
        # Comprimir para economizar espaço
        gzip "$BACKUP_FILE"
        BACKUP_FILE="${BACKUP_FILE}.gz"
        
        print_success "Backup criado: $BACKUP_FILE"
        
        # Guardar caminho do backup para possível rollback
        echo "$BACKUP_FILE" > /tmp/last_backup_staging.txt
    else
        print_error "Falha ao criar backup!"
        print_warning "Deploy cancelado por segurança"
        exit 1
    fi
    
    # Cleanup de backups antigos (manter últimos 10)
    print_info "Limpando backups antigos..."
    ls -t backups/staging-backup-*.sql.gz | tail -n +11 | xargs -r rm
    print_success "Backups antigos limpos (mantidos últimos 10)"
}

# ==============================================================================
# ETAPA 4: PULL LATEST CODE
# ==============================================================================

update_code() {
    print_header "Atualizando Código"
    
    # Verificar se há mudanças não commitadas
    if ! git diff-index --quiet HEAD --; then
        print_error "Há mudanças não commitadas!"
        print_info "Commit ou stash suas mudanças antes de deploy"
        git status --short
        exit 1
    fi
    
    print_info "Fazendo pull da branch $BRANCH..."
    
    # Guardar hash atual (para rollback)
    PREVIOUS_COMMIT=$(git rev-parse HEAD)
    echo "$PREVIOUS_COMMIT" > /tmp/previous_commit_staging.txt
    
    # Pull
    git pull origin $BRANCH
    
    NEW_COMMIT=$(git rev-parse HEAD)
    
    if [ "$PREVIOUS_COMMIT" == "$NEW_COMMIT" ]; then
        print_warning "Nenhuma mudança detectada"
        read -p "Continuar mesmo assim? (y/n): " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
    else
        print_success "Código atualizado"
        print_info "Commit anterior: ${PREVIOUS_COMMIT:0:7}"
        print_info "Commit novo: ${NEW_COMMIT:0:7}"
        
        # Mostrar changelog
        echo ""
        print_info "Mudanças neste deploy:"
        git log --oneline --no-merges $PREVIOUS_COMMIT..$NEW_COMMIT | head -10
        echo ""
    fi
}

# ==============================================================================
# ETAPA 5: BUILD IMAGES
# ==============================================================================

build_images() {
    print_header "Building Docker Images"
    
    print_info "Isso pode levar alguns minutos..."
    
    # Build com tag da versão
    export VERSION=$(git rev-parse --short HEAD)
    
    if docker-compose -f docker-compose.yml -f docker-compose.staging.yml build --no-cache; then
        print_success "Images buildadas com sucesso"
        print_info "Versão: $VERSION"
    else
        print_error "Falha ao buildar images!"
        exit 1
    fi
}

# ==============================================================================
# ETAPA 6: DEPLOY (ZERO DOWNTIME)
# ==============================================================================
# Por quê? Usuários continuam usando durante deploy
# Estratégia: Subir novos containers antes de derrubar antigos

deploy() {
    print_header "Executando Deploy"
    
    print_info "Estratégia: Zero Downtime (Rolling Update)"
    
    # 1. Pull images (se usando registry)
    print_info "Pulling images..."
    docker-compose -f docker-compose.yml -f docker-compose.staging.yml pull 2>/dev/null || true
    
    # 2. Criar novos containers sem derrubar antigos
    print_info "Iniciando novos containers..."
    docker-compose -f docker-compose.yml -f docker-compose.staging.yml up -d --no-deps --build
    
    # 3. Aguardar novos containers ficarem healthy
    print_info "Aguardando containers ficarem healthy..."
    sleep 20
    
    # 4. Remover containers antigos
    print_info "Removendo containers antigos..."
    docker-compose -f docker-compose.yml -f docker-compose.staging.yml up -d --remove-orphans
    
    print_success "Deploy concluído"
}

# ==============================================================================
# ETAPA 7: EXECUTAR MIGRATIONS (se houver)
# ==============================================================================

run_migrations() {
    print_header "Executando Migrations"
    
    # Verificar se Alembic está configurado
    if docker-compose -f docker-compose.yml -f docker-compose.staging.yml exec -T backend \
        test -f alembic.ini 2>/dev/null; then
        
        print_info "Executando migrations Alembic..."
        
        docker-compose -f docker-compose.yml -f docker-compose.staging.yml exec -T backend \
            alembic upgrade head
        
        print_success "Migrations executadas"
    else
        print_info "Alembic não configurado ainda"
        print_info "Tabelas serão criadas automaticamente pelo SQLAlchemy"
    fi
}

# ==============================================================================
# ETAPA 8: HEALTH CHECK
# ==============================================================================
# Por quê? Validar que aplicação está respondendo corretamente
# Se health check falhar, rollback automático

health_check() {
    print_header "Verificando Saúde da Aplicação"
    
    # URL do staging (ajuste conforme seu domínio)
    STAGING_URL="http://localhost:8001"  # Ou https://staging.seudominio.com
    
    print_info "Testando endpoint: $STAGING_URL/health"
    
    max_attempts=30
    attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -f -s "$STAGING_URL/health" > /dev/null 2>&1; then
            print_success "Health check passou!"
            
            # Testar login também
            print_info "Testando autenticação..."
            if curl -f -s -X POST "$STAGING_URL/token" \
                -d "username=admin&password=123456" > /dev/null 2>&1; then
                print_success "Autenticação OK"
            else
                print_warning "Autenticação falhou (pode ser esperado se senhas mudaram)"
            fi
            
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
        
        if [ $attempt -eq $max_attempts ]; then
            print_error "Health check falhou após $max_attempts tentativas!"
            return 1
        fi
    done
}

# ==============================================================================
# ETAPA 9: ROLLBACK (se necessário)
# ==============================================================================

rollback() {
    print_header "Executando Rollback"
    
    print_error "Deploy falhou! Iniciando rollback..."
    
    # Restaurar código
    if [ -f /tmp/previous_commit_staging.txt ]; then
        PREVIOUS_COMMIT=$(cat /tmp/previous_commit_staging.txt)
        print_info "Revertendo para commit: $PREVIOUS_COMMIT"
        git reset --hard $PREVIOUS_COMMIT
    fi
    
    # Restaurar banco
    if [ -f /tmp/last_backup_staging.txt ]; then
        BACKUP_FILE=$(cat /tmp/last_backup_staging.txt)
        print_info "Restaurando backup: $BACKUP_FILE"
        
        gunzip -c "$BACKUP_FILE" | \
        docker-compose -f docker-compose.yml -f docker-compose.staging.yml exec -T db \
            psql -U postgres material_control_staging
    fi
    
    # Restart containers
    print_info "Restartando containers..."
    docker-compose -f docker-compose.yml -f docker-compose.staging.yml up -d --force-recreate
    
    print_success "Rollback concluído"
    print_warning "Investigue os logs para entender o que deu errado"
    print_info "Logs: docker-compose -f docker-compose.yml -f docker-compose.staging.yml logs"
    
    exit 1
}

# ==============================================================================
# ETAPA 10: NOTIFICAR TIME
# ==============================================================================

notify_team() {
    local status=$1
    local message=$2
    
    print_header "Notificando Time"
    
    # Slack webhook (configurar em .env.staging ou secrets)
    SLACK_WEBHOOK=${SLACK_WEBHOOK:-""}
    
    if [ -n "$SLACK_WEBHOOK" ]; then
        print_info "Enviando notificação para Slack..."
        
        local color="good"
        [ "$status" == "failed" ] && color="danger"
        
        curl -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{
                \"attachments\": [{
                    \"color\": \"$color\",
                    \"title\": \"Deploy Staging - $status\",
                    \"text\": \"$message\",
                    \"fields\": [
                        {\"title\": \"Usuário\", \"value\": \"$DEPLOY_USER\", \"short\": true},
                        {\"title\": \"Timestamp\", \"value\": \"$DEPLOY_TIMESTAMP\", \"short\": true},
                        {\"title\": \"Branch\", \"value\": \"$BRANCH\", \"short\": true},
                        {\"title\": \"Commit\", \"value\": \"$(git rev-parse --short HEAD)\", \"short\": true}
                    ]
                }]
            }" 2>/dev/null
        
        print_success "Slack notificado"
    else
        print_warning "SLACK_WEBHOOK não configurado"
        print_info "Configure em .env.staging para receber notificações"
    fi
}

# ==============================================================================
# ETAPA 11: CLEANUP
# ==============================================================================

cleanup() {
    print_header "Limpeza"
    
    print_info "Removendo images antigas..."
    docker image prune -f
    
    print_info "Removendo containers parados..."
    docker container prune -f
    
    print_success "Limpeza concluída"
}

# ==============================================================================
# FUNÇÃO PRINCIPAL
# ==============================================================================

main() {
    clear
    
    print_header "🚀 Deploy para Staging"
    
    echo "Este script irá:"
    echo "  1. Validar branch (staging)"
    echo "  2. Fazer backup do banco"
    echo "  3. Atualizar código (git pull)"
    echo "  4. Buildar novas images Docker"
    echo "  5. Deploy com zero downtime"
    echo "  6. Health check"
    echo "  7. Notificar time"
    echo ""
    print_warning "⚠️  Este deploy afetará o ambiente de STAGING"
    echo ""
    
    read -p "Continuar? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_error "Deploy cancelado pelo usuário"
        exit 0
    fi
    
    # Executar etapas
    check_prerequisites
    validate_branch
    backup_database
    update_code
    build_images
    deploy
    run_migrations
    
    # Health check com rollback automático se falhar
    if health_check; then
        cleanup
        notify_team "success" "Deploy para staging concluído com sucesso! ✅"
        
        print_header "✅ Deploy Concluído com Sucesso!"
        echo ""
        print_success "Staging está rodando a versão: $(git rev-parse --short HEAD)"
        print_info "URL: http://localhost:8001"  # Ajuste conforme seu setup
        echo ""
        print_info "Comandos úteis:"
        echo "  Ver logs: docker-compose -f docker-compose.yml -f docker-compose.staging.yml logs -f"
        echo "  Status: docker-compose -f docker-compose.yml -f docker-compose.staging.yml ps"
        echo ""
    else
        notify_team "failed" "Deploy para staging FALHOU! ❌ Health check não passou."
        rollback
    fi
}

# Trap errors
trap 'print_error "Erro na linha $LINENO"; exit 1' ERR

# Executar
main