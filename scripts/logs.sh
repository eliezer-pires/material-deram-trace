#!/bin/bash

# ==============================================================================
# logs.sh - Visualizar Logs de Forma Amigável
# ==============================================================================
#
# Uso: 
#   ./scripts/logs.sh                       (todos os logs, dev)
#   ./scripts/logs.sh backend               (só backend, dev)
#   ./scripts/logs.sh backend staging       (backend, staging)
#   ./scripts/logs.sh -f                    (follow mode)
#   ./scripts/logs.sh --tail 50             (últimas 50 linhas)
#
# Por quê?
# - Comando docker-compose logs é verboso e difícil de lembrar
# - Script adiciona cores, filtros e shortcuts úteis
# - Facilita troubleshooting e debugging
#
# ==============================================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ==============================================================================
# CONFIGURAÇÃO
# ==============================================================================

SERVICE=${1:-""}  # backend, frontend, db, ou vazio para todos
ENVIRONMENT=${2:-development}
FOLLOW=false
TAIL_LINES=100
GREP_FILTER=""

# Parse argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--follow)
            FOLLOW=true
            shift
            ;;
        --tail)
            TAIL_LINES=$2
            shift 2
            ;;
        --grep)
            GREP_FILTER=$2
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [ -z "$SERVICE" ]; then
                SERVICE=$1
            elif [ "$ENVIRONMENT" == "development" ]; then
                ENVIRONMENT=$1
            fi
            shift
            ;;
    esac
done

# Determinar compose file
case $ENVIRONMENT in
    development|dev)
        COMPOSE_FILE="docker-compose.dev.yml"
        ;;
    staging)
        COMPOSE_FILE="docker-compose.staging.yml"
        ;;
    production|prod)
        COMPOSE_FILE="docker-compose.prod.yml"
        ;;
    *)
        echo -e "${RED}Ambiente inválido: $ENVIRONMENT${NC}"
        exit 1
        ;;
esac

# ==============================================================================
# FUNÇÕES
# ==============================================================================

show_help() {
    cat << EOF
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${BLUE}📋 logs.sh - Visualizar Logs${NC}
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${GREEN}Uso:${NC}
  ./scripts/logs.sh [SERVICE] [ENVIRONMENT] [OPTIONS]

${GREEN}Exemplos:${NC}
  ./scripts/logs.sh                      # Todos os logs (dev)
  ./scripts/logs.sh backend              # Só backend (dev)
  ./scripts/logs.sh frontend staging     # Frontend em staging
  ./scripts/logs.sh -f                   # Follow mode (tempo real)
  ./scripts/logs.sh --tail 50            # Últimas 50 linhas
  ./scripts/logs.sh backend --grep ERROR # Filtrar por "ERROR"

${GREEN}Serviços disponíveis:${NC}
  - backend
  - frontend
  - db
  - redis (se configurado)
  - nginx (se configurado)

${GREEN}Ambientes:${NC}
  - development (padrão)
  - staging
  - production

${GREEN}Opções:${NC}
  -f, --follow          Seguir logs em tempo real
  --tail N              Mostrar últimas N linhas (padrão: 100)
  --grep PATTERN        Filtrar logs por padrão
  -h, --help            Mostrar esta ajuda

${YELLOW}Dica:${NC} Use Ctrl+C para sair do modo follow
EOF
}

show_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📋 Logs - ${SERVICE:-Todos} ($ENVIRONMENT)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

colorize_logs() {
    # Adicionar cores aos logs para melhor leitura
    sed -e "s/\(ERROR\|FATAL\|CRITICAL\)/${RED}\1${NC}/g" \
        -e "s/\(WARN\|WARNING\)/${YELLOW}\1${NC}/g" \
        -e "s/\(INFO\)/${GREEN}\1${NC}/g" \
        -e "s/\(DEBUG\)/${BLUE}\1${NC}/g" \
        -e "s/\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\)/${CYAN}\1${NC}/g"
}

get_logs() {
    local cmd="docker-compose -f docker-compose.yml -f $COMPOSE_FILE logs"
    
    # Adicionar serviço específico
    if [ -n "$SERVICE" ]; then
        cmd="$cmd $SERVICE"
    fi
    
    # Adicionar tail
    cmd="$cmd --tail=$TAIL_LINES"
    
    # Adicionar follow se solicitado
    if [ "$FOLLOW" = true ]; then
        cmd="$cmd -f"
    fi
    
    # Executar comando
    if [ -n "$GREP_FILTER" ]; then
        eval $cmd | grep --color=always "$GREP_FILTER" | colorize_logs
    else
        eval $cmd | colorize_logs
    fi
}

show_container_status() {
    echo -e "${BLUE}Status dos Containers:${NC}"
    docker-compose -f docker-compose.yml -f $COMPOSE_FILE ps
    echo ""
}

# ==============================================================================
# ATALHOS ÚTEIS
# ==============================================================================

show_shortcuts() {
    echo ""
    echo -e "${YELLOW}💡 Atalhos úteis:${NC}"
    echo ""
    echo -e "  ${GREEN}Ver erros apenas:${NC}"
    echo "  ./scripts/logs.sh backend --grep ERROR"
    echo ""
    echo -e "  ${GREEN}Ver últimas 500 linhas:${NC}"
    echo "  ./scripts/logs.sh --tail 500"
    echo ""
    echo -e "  ${GREEN}Monitorar em tempo real:${NC}"
    echo "  ./scripts/logs.sh -f"
    echo ""
    echo -e "  ${GREEN}Ver logs do banco:${NC}"
    echo "  ./scripts/logs.sh db"
    echo ""
}

# ==============================================================================
# ANÁLISE RÁPIDA DE ERROS
# ==============================================================================

quick_error_analysis() {
    echo -e "${YELLOW}🔍 Análise Rápida de Erros:${NC}"
    echo ""
    
    # Contar erros por tipo
    local errors=$(docker-compose -f docker-compose.yml -f $COMPOSE_FILE logs --tail=1000 | \
        grep -i "error\|fatal\|critical" | wc -l)
    
    local warnings=$(docker-compose -f docker-compose.yml -f $COMPOSE_FILE logs --tail=1000 | \
        grep -i "warn" | wc -l)
    
    if [ $errors -gt 0 ]; then
        echo -e "  ${RED}❌ Erros encontrados: $errors${NC}"
        echo ""
        echo -e "  ${BLUE}Últimos 5 erros:${NC}"
        docker-compose -f docker-compose.yml -f $COMPOSE_FILE logs --tail=1000 | \
            grep -i "error\|fatal\|critical" | tail -5 | sed 's/^/    /'
        echo ""
    else
        echo -e "  ${GREEN}✓ Nenhum erro encontrado${NC}"
    fi
    
    if [ $warnings -gt 0 ]; then
        echo -e "  ${YELLOW}⚠️  Warnings encontrados: $warnings${NC}"
    fi
    
    echo ""
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    clear
    show_header
    show_container_status
    
    # Análise rápida se não for follow mode
    if [ "$FOLLOW" = false ]; then
        quick_error_analysis
    fi
    
    # Mostrar logs
    echo -e "${BLUE}Logs:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    get_logs
    
    # Mostrar shortcuts se não for follow
    if [ "$FOLLOW" = false ]; then
        show_shortcuts
    fi
}

main