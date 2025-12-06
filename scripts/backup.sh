#!/bin/bash

# ==============================================================================
# backup.sh - Backup do Banco de Dados
# ==============================================================================
#
# Uso: 
#   ./scripts/backup.sh                    (desenvolvimento)
#   ./scripts/backup.sh staging            (staging)
#   ./scripts/backup.sh production         (produção)
#
# O que faz:
# 1. Identifica ambiente (dev/staging/prod)
# 2. Cria backup do PostgreSQL (pg_dump)
# 3. Comprime backup (gzip)
# 4. (Opcional) Upload para S3/storage remoto
# 5. Limpa backups antigos (retention policy)
# 6. Valida integridade do backup
#
# Por quê?
# - Proteção contra perda de dados
# - Compliance (LGPD, ISO 27001)
# - Disaster recovery
# - Teste de restauração
# - Auditoria
#
# ==============================================================================

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

# ==============================================================================
# CONFIGURAÇÃO
# ==============================================================================

# Determinar ambiente
ENVIRONMENT=${1:-development}

case $ENVIRONMENT in
    development|dev)
        COMPOSE_FILE="docker-compose.dev.yml"
        DB_NAME="material_control_dev"
        RETENTION_DAYS=7
        ;;
    staging)
        COMPOSE_FILE="docker-compose.staging.yml"
        DB_NAME="material_control_staging"
        RETENTION_DAYS=14
        ;;
    production|prod)
        COMPOSE_FILE="docker-compose.prod.yml"
        DB_NAME="material_control"
        RETENTION_DAYS=30
        ;;
    *)
        print_error "Ambiente inválido: $ENVIRONMENT"
        echo "Uso: $0 [development|staging|production]"
        exit 1
        ;;
esac

# Diretórios
BACKUP_DIR="backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/${ENVIRONMENT}-${DB_NAME}-${TIMESTAMP}.sql"

# ==============================================================================
# CRIAR DIRETÓRIO DE BACKUPS
# ==============================================================================

create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        print_info "Criando diretório de backups..."
        mkdir -p "$BACKUP_DIR"
        print_success "Diretório criado: $BACKUP_DIR"
    fi
}

# ==============================================================================
# VERIFICAR SE BANCO ESTÁ RODANDO
# ==============================================================================

check_database() {
    print_info "Verificando se banco está acessível..."
    
    if docker-compose -f docker-compose.yml -f "$COMPOSE_FILE" exec -T db \
        pg_isready -U postgres > /dev/null 2>&1; then
        print_success "Banco de dados está online"
    else
        print_error "Banco de dados não está acessível!"
        print_info "Verifique: docker-compose -f docker-compose.yml -f $COMPOSE_FILE ps"
        exit 1
    fi
}

# ==============================================================================
# CRIAR BACKUP
# ==============================================================================

create_backup() {
    print_info "Criando backup do banco: $DB_NAME"
    print_info "Arquivo: $BACKUP_FILE"
    
    # pg_dump options:
    # -U postgres     : usuário
    # -Fc             : formato custom (comprimido e otimizado)
    # -v              : verbose
    # --no-owner      : não incluir comandos de ownership
    # --no-privileges : não incluir comandos de privilégios
    
    if docker-compose -f docker-compose.yml -f "$COMPOSE_FILE" exec -T db \
        pg_dump -U postgres -Fc -v --no-owner --no-privileges "$DB_NAME" \
        > "$BACKUP_FILE" 2>/dev/null; then
        
        print_success "Backup SQL criado"
    else
        print_error "Falha ao criar backup!"
        rm -f "$BACKUP_FILE"
        exit 1
    fi
    
    # Comprimir com gzip
    print_info "Comprimindo backup..."
    gzip "$BACKUP_FILE"
    BACKUP_FILE="${BACKUP_FILE}.gz"
    
    # Calcular tamanho
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    print_success "Backup comprimido: $BACKUP_SIZE"
}

# ==============================================================================
# VALIDAR INTEGRIDADE DO BACKUP
# ==============================================================================
# Por quê? Backup corrompido é inútil!
# Melhor descobrir agora que durante restauração de emergência

validate_backup() {
    print_info "Validando integridade do backup..."
    
    # Testar se pode listar conteúdo
    if gunzip -t "$BACKUP_FILE" 2>/dev/null; then
        print_success "Compressão OK"
    else
        print_error "Arquivo corrompido!"
        exit 1
    fi
    
    # Testar se pg_restore consegue ler
    if gunzip -c "$BACKUP_FILE" | \
        docker-compose -f docker-compose.yml -f "$COMPOSE_FILE" exec -T db \
        pg_restore --list > /dev/null 2>&1; then
        print_success "Backup validado - pode ser restaurado"
    else
        print_error "Backup inválido - não pode ser restaurado!"
        exit 1
    fi
}

# ==============================================================================
# CRIAR METADATA DO BACKUP
# ==============================================================================
# Por quê? Útil para auditoria e troubleshooting
# Saber exatamente o que está no backup

create_metadata() {
    print_info "Criando metadata..."
    
    METADATA_FILE="${BACKUP_FILE}.meta"
    
    cat > "$METADATA_FILE" << EOF
# Backup Metadata
BACKUP_FILE=$(basename "$BACKUP_FILE")
ENVIRONMENT=$ENVIRONMENT
DATABASE=$DB_NAME
TIMESTAMP=$TIMESTAMP
DATE=$(date)
USER=$(whoami)
HOSTNAME=$(hostname)
SIZE=$BACKUP_SIZE
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "N/A")
GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "N/A")
EOF
    
    # Contar registros (aproximado)
    print_info "Contando registros..."
    MATERIAL_COUNT=$(docker-compose -f docker-compose.yml -f "$COMPOSE_FILE" exec -T db \
        psql -U postgres -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM materiais" 2>/dev/null | tr -d ' ' || echo "N/A")
    
    echo "MATERIAL_COUNT=$MATERIAL_COUNT" >> "$METADATA_FILE"
    
    print_success "Metadata criada"
}

# ==============================================================================
# UPLOAD PARA ARMAZENAMENTO REMOTO (Opcional)
# ==============================================================================
# Por quê? Proteção contra:
# - Falha do servidor
# - Ransomware
# - Incêndio/desastre físico
# - Erro humano (rm -rf)

upload_to_remote() {
    print_info "Upload para armazenamento remoto..."
    
    # Verificar se AWS CLI está instalado e configurado
    if command -v aws &> /dev/null && [ -n "${AWS_S3_BUCKET:-}" ]; then
        print_info "Fazendo upload para S3: $AWS_S3_BUCKET"
        
        aws s3 cp "$BACKUP_FILE" \
            "s3://$AWS_S3_BUCKET/backups/$ENVIRONMENT/" \
            --storage-class STANDARD_IA \
            --metadata "environment=$ENVIRONMENT,database=$DB_NAME"
        
        aws s3 cp "$METADATA_FILE" \
            "s3://$AWS_S3_BUCKET/backups/$ENVIRONMENT/"
        
        print_success "Upload para S3 concluído"
        
    elif command -v rclone &> /dev/null && [ -n "${RCLONE_REMOTE:-}" ]; then
        # Alternativa: usar rclone (Google Drive, Dropbox, etc)
        print_info "Fazendo upload via rclone: $RCLONE_REMOTE"
        
        rclone copy "$BACKUP_FILE" "$RCLONE_REMOTE:/backups/$ENVIRONMENT/"
        rclone copy "$METADATA_FILE" "$RCLONE_REMOTE:/backups/$ENVIRONMENT/"
        
        print_success "Upload via rclone concluído"
        
    else
        print_warning "Armazenamento remoto não configurado"
        print_info "Configure AWS_S3_BUCKET ou RCLONE_REMOTE para backup remoto"
    fi
}

# ==============================================================================
# LIMPEZA DE BACKUPS ANTIGOS
# ==============================================================================
# Por quê? Economizar espaço em disco
# Retention policy depende do ambiente

cleanup_old_backups() {
    print_info "Limpando backups antigos (retention: $RETENTION_DAYS dias)..."
    
    # Contar backups antes
    BEFORE=$(ls -1 ${BACKUP_DIR}/${ENVIRONMENT}-*.sql.gz 2>/dev/null | wc -l || echo 0)
    
    # Deletar backups mais antigos que RETENTION_DAYS
    find "$BACKUP_DIR" -name "${ENVIRONMENT}-*.sql.gz" \
        -mtime +$RETENTION_DAYS -delete
    
    # Deletar metadata órfãos
    find "$BACKUP_DIR" -name "${ENVIRONMENT}-*.meta" \
        -mtime +$RETENTION_DAYS -delete
    
    # Contar backups depois
    AFTER=$(ls -1 ${BACKUP_DIR}/${ENVIRONMENT}-*.sql.gz 2>/dev/null | wc -l || echo 0)
    DELETED=$((BEFORE - AFTER))
    
    if [ $DELETED -gt 0 ]; then
        print_success "Removidos $DELETED backup(s) antigo(s)"
    else
        print_info "Nenhum backup antigo para remover"
    fi
    
    print_info "Backups mantidos: $AFTER"
}

# ==============================================================================
# LISTAR BACKUPS DISPONÍVEIS
# ==============================================================================

list_backups() {
    print_info "Backups disponíveis para $ENVIRONMENT:"
    echo ""
    
    if ls ${BACKUP_DIR}/${ENVIRONMENT}-*.sql.gz 1> /dev/null 2>&1; then
        printf "%-50s %10s %20s\n" "ARQUIVO" "TAMANHO" "DATA"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        for backup in ${BACKUP_DIR}/${ENVIRONMENT}-*.sql.gz; do
            filename=$(basename "$backup")
            size=$(du -h "$backup" | cut -f1)
            date=$(stat -c %y "$backup" | cut -d. -f1)
            printf "%-50s %10s %20s\n" "$filename" "$size" "$date"
        done
        echo ""
    else
        print_warning "Nenhum backup encontrado para $ENVIRONMENT"
    fi
}

# ==============================================================================
# RELATÓRIO FINAL
# ==============================================================================

show_report() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ Backup Concluído com Sucesso!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}📁 Arquivo:${NC}      $BACKUP_FILE"
    echo -e "${BLUE}📊 Tamanho:${NC}      $BACKUP_SIZE"
    echo -e "${BLUE}🗄️  Banco:${NC}        $DB_NAME"
    echo -e "${BLUE}🌍 Ambiente:${NC}     $ENVIRONMENT"
    echo -e "${BLUE}⏰ Timestamp:${NC}    $TIMESTAMP"
    echo ""
    echo -e "${BLUE}📝 Para restaurar este backup:${NC}"
    echo "   ./scripts/restore.sh $BACKUP_FILE"
    echo ""
}

# ==============================================================================
# FUNÇÃO PRINCIPAL
# ==============================================================================

main() {
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}🗄️  Backup do Banco de Dados - $ENVIRONMENT${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Executar etapas
    create_backup_dir
    check_database
    create_backup
    validate_backup
    create_metadata
    upload_to_remote
    cleanup_old_backups
    show_report
    list_backups
    
    echo ""
    print_success "Processo de backup finalizado!"
}

# Executar
main