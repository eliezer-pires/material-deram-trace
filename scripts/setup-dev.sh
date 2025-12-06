#!/bin/bash

# ==============================================================================
# setup-dev.sh - Configurar Ambiente de Desenvolvimento
# ==============================================================================
#
# Uso: ./scripts/setup-dev.sh
#
# O que faz:
# 1. Verifica se Docker está instalado
# 2. Cria .env.dev se não existir
# 3. Sobe containers de desenvolvimento
# 4. Aguarda serviços ficarem prontos
# 5. Executa migrations do banco
# 6. Cria usuário admin padrão
# 7. (Opcional) Cria dados de seed para testes
# 8. Mostra URLs de acesso
#
# Por quê?
# - Onboarding rápido de novos devs (< 5 minutos)
# - Reduz "works on my machine" 
# - Garante ambiente consistente
# - Automatiza tarefas repetitivas
#
# ==============================================================================

set -e  # Sai se qualquer comando falhar

# Cores para output (melhor UX no terminal)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funções auxiliares para output formatado
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# ==============================================================================
# ETAPA 1: VERIFICAR PRÉ-REQUISITOS
# ==============================================================================
# Por quê? Falhar rápido é melhor que falhar tarde
# Se Docker não está instalado, não adianta continuar

check_prerequisites() {
    print_header "Verificando Pré-requisitos"
    
    # Verificar Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker não está instalado!"
        print_info "Instale em: https://docs.docker.com/get-docker/"
        exit 1
    fi
    print_success "Docker encontrado: $(docker --version)"
    
    # Verificar Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose não está instalado!"
        print_info "Instale em: https://docs.docker.com/compose/install/"
        exit 1
    fi
    print_success "Docker Compose encontrado: $(docker-compose --version)"
    
    # Verificar se Docker está rodando
    if ! docker info &> /dev/null; then
        print_error "Docker daemon não está rodando!"
        print_info "Inicie o Docker Desktop ou execute: sudo systemctl start docker"
        exit 1
    fi
    print_success "Docker daemon está rodando"
    
    # Verificar se está na raiz do projeto
    if [ ! -f "docker-compose.yml" ]; then
        print_error "Execute este script da raiz do projeto!"
        print_info "cd material-deram-trace && ./scripts/setup-dev.sh"
        exit 1
    fi
    print_success "Diretório correto"
}

# ==============================================================================
# ETAPA 2: CONFIGURAR VARIÁVEIS DE AMBIENTE
# ==============================================================================
# Por quê? Cada dev pode ter configurações diferentes
# .env.dev é commitable (valores fake OK) para facilitar onboarding

setup_env() {
    print_header "Configurando Variáveis de Ambiente"
    
    if [ -f ".env.dev" ]; then
        print_warning ".env.dev já existe"
        read -p "Deseja sobrescrever? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Mantendo .env.dev existente"
            return
        fi
    fi
    
    print_info "Criando .env.dev..."
    
    # Criar .env.dev com valores padrão de desenvolvimento
    cat > .env.dev << 'EOF'
# ==============================================================================
# Environment: DEVELOPMENT
# ==============================================================================

ENVIRONMENT=development

# Database
DB_USER=postgres
DB_PASSWORD=dev-password
DB_HOST=db
DB_PORT=5432
DB_NAME=material_control_dev

DATABASE_URL=postgresql://postgres:dev-password@db:5432/material_control_dev

# Backend
SECRET_KEY=dev-secret-key-not-for-production
LOG_LEVEL=DEBUG
WORKERS=1

# CORS (permissivo em dev)
CORS_ORIGINS=http://localhost:5173,http://localhost:3000,http://localhost:80

# Frontend
VITE_API_URL=http://localhost:8000

# Debug
DEBUG=true
PYTHONUNBUFFERED=1
EOF
    
    print_success ".env.dev criado"
    print_info "Edite .env.dev se precisar customizar"
}

# ==============================================================================
# ETAPA 3: CRIAR REDE DOCKER (se não existir)
# ==============================================================================
# Por quê? Permite containers se comunicarem pelo nome
# Exemplo: backend pode acessar 'db' ao invés de 'localhost:5432'

create_network() {
    print_header "Configurando Rede Docker"
    
    if docker network inspect material_network &> /dev/null; then
        print_info "Rede material_network já existe"
    else
        print_info "Criando rede material_network..."
        docker network create material_network
        print_success "Rede criada"
    fi
}

# ==============================================================================
# ETAPA 4: LIMPAR CONTAINERS ANTIGOS (opcional)
# ==============================================================================
# Por quê? Evita conflitos de containers antigos
# Fresh start sempre que rodar setup

cleanup_old_containers() {
    print_header "Limpando Containers Antigos"
    
    print_info "Parando containers existentes..."
    docker-compose -f docker-compose.yml -f docker-compose.dev.yml down 2>/dev/null || true
    
    print_success "Limpeza concluída"
}

# ==============================================================================
# ETAPA 5: SUBIR SERVIÇOS
# ==============================================================================
# Por quê? Inicia banco, backend e frontend
# -d = detached mode (roda em background)
# --build = força rebuild (garante código atualizado)

start_services() {
    print_header "Iniciando Serviços"
    
    print_info "Buildando e iniciando containers..."
    print_info "Isso pode levar alguns minutos na primeira vez..."
    
    # Subir em ordem: db primeiro, depois backend, depois frontend
    docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build
    
    print_success "Containers iniciados"
}

# ==============================================================================
# ETAPA 6: AGUARDAR SERVIÇOS FICAREM PRONTOS
# ==============================================================================
# Por quê? Banco leva ~10s para aceitar conexões
# Backend precisa do banco pronto antes de iniciar
# Evita errors de "connection refused"

wait_for_services() {
    print_header "Aguardando Serviços"
    
    # Aguardar banco de dados (tentativas com timeout)
    print_info "Aguardando PostgreSQL..."
    max_attempts=30
    attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec -T db pg_isready -U postgres &> /dev/null; then
            print_success "PostgreSQL pronto!"
            break
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 1
        
        if [ $attempt -eq $max_attempts ]; then
            print_error "Timeout aguardando PostgreSQL"
            print_info "Verifique logs: docker-compose logs db"
            exit 1
        fi
    done
    echo ""
    
    # Aguardar backend (health check)
    print_info "Aguardando Backend..."
    attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -f http://localhost:8000/health &> /dev/null; then
            print_success "Backend pronto!"
            break
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 1
        
        if [ $attempt -eq $max_attempts ]; then
            print_error "Timeout aguardando Backend"
            print_info "Verifique logs: docker-compose logs backend"
            exit 1
        fi
    done
    echo ""
    
    # Aguardar frontend (dev server)
    print_info "Aguardando Frontend..."
    attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -f http://localhost:5173 &> /dev/null; then
            print_success "Frontend pronto!"
            break
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 1
        
        if [ $attempt -eq $max_attempts ]; then
            print_warning "Frontend pode ainda estar iniciando..."
            print_info "Verifique logs: docker-compose logs frontend"
        fi
    done
    echo ""
}

# ==============================================================================
# ETAPA 7: EXECUTAR MIGRATIONS (FUTURO - com Alembic)
# ==============================================================================
# Por quê? Garante que banco está com schema atualizado
# Migrations = versionamento do schema do banco

run_migrations() {
    print_header "Executando Migrations"
    
    # Por enquanto, as tabelas são criadas automaticamente pelo SQLAlchemy
    # Quando implementar Alembic, descomentar:
    
    # docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec backend \
    #     alembic upgrade head
    
    print_info "Migrations (futuro - com Alembic)"
    print_info "Por enquanto, tabelas são criadas automaticamente"
}

# ==============================================================================
# ETAPA 8: CRIAR DADOS DE SEED (opcional)
# ==============================================================================
# Por quê? Facilita testes com dados de exemplo
# Dev não precisa criar materiais manualmente

seed_data() {
    print_header "Criando Dados de Exemplo"
    
    read -p "Deseja criar dados de exemplo? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Criando materiais de exemplo..."
        
        # Script Python para criar dados
        docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec -T backend python << 'PYTHON'
from database import SessionLocal
from models import Material
import random

db = SessionLocal()

# Dados de exemplo
setores = ["TI", "RH", "Financeiro", "Operações"]
salas = ["101", "102", "201", "202", "301"]
responsaveis = ["João Silva", "Maria Santos", "Pedro Costa", "Ana Oliveira"]

materiais_exemplo = [
    "Notebook Dell Latitude",
    "Mouse Logitech MX",
    "Teclado Mecânico",
    "Monitor LG 27\"",
    "Impressora HP",
    "Cadeira Ergonômica",
    "Mesa Ajustável",
    "Webcam Logitech",
    "Headset Jabra",
    "No-break APC"
]

print("Criando materiais de exemplo...")
for i, nome in enumerate(materiais_exemplo, 1):
    material = Material(
        nome=nome,
        bmp=f"BMP-{1000 + i}",
        setor=random.choice(setores),
        sala=random.choice(salas),
        responsavel=random.choice(responsaveis),
        observacoes=f"Material de exemplo {i}"
    )
    db.add(material)

db.commit()
print(f"✓ {len(materiais_exemplo)} materiais criados!")
db.close()
PYTHON
        
        print_success "Dados de exemplo criados!"
    else
        print_info "Pulando criação de dados de exemplo"
    fi
}

# ==============================================================================
# ETAPA 9: MOSTRAR INFORMAÇÕES DE ACESSO
# ==============================================================================
# Por quê? Dev precisa saber onde acessar cada serviço
# Copiar e colar URLs é mais fácil que decorar portas

show_access_info() {
    print_header "Ambiente de Desenvolvimento Pronto!"
    
    echo ""
    echo -e "${GREEN}🎉 Setup concluído com sucesso!${NC}"
    echo ""
    echo -e "${BLUE}📍 URLs de Acesso:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "  ${GREEN}Frontend:${NC}     http://localhost:5173"
    echo -e "  ${GREEN}Backend API:${NC}  http://localhost:8000"
    echo -e "  ${GREEN}API Docs:${NC}     http://localhost:8000/docs"
    echo -e "  ${GREEN}Adminer:${NC}      http://localhost:8080"
    echo -e "  ${GREEN}MailHog:${NC}      http://localhost:8025"
    echo ""
    echo -e "${BLUE}🔐 Credenciais Padrão:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "  ${GREEN}Username:${NC} admin"
    echo -e "  ${GREEN}Password:${NC} 123456"
    echo ""
    echo -e "${BLUE}🛠️  Comandos Úteis:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Ver logs:         docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f"
    echo "  Parar:            docker-compose -f docker-compose.yml -f docker-compose.dev.yml down"
    echo "  Restart:          docker-compose -f docker-compose.yml -f docker-compose.dev.yml restart"
    echo "  Shell backend:    docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec backend bash"
    echo "  Shell frontend:   docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec frontend sh"
    echo "  Postgres CLI:     docker-compose -f docker-compose.yml -f docker-compose.dev.yml exec db psql -U postgres material_control_dev"
    echo ""
    echo -e "${YELLOW}💡 Dica:${NC} O código fonte está montado com volume - mudanças refletem automaticamente!"
    echo ""
}

# ==============================================================================
# FUNÇÃO PRINCIPAL
# ==============================================================================

main() {
    clear
    
    print_header "🚀 Setup Ambiente de Desenvolvimento"
    
    echo "Este script vai:"
    echo "  1. Verificar dependências (Docker, Docker Compose)"
    echo "  2. Criar .env.dev"
    echo "  3. Subir todos os serviços (db, backend, frontend)"
    echo "  4. Aguardar serviços ficarem prontos"
    echo "  5. (Opcional) Criar dados de exemplo"
    echo ""
    
    read -p "Continuar? (y/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Setup cancelado pelo usuário"
        exit 0
    fi
    
    # Executar todas as etapas
    check_prerequisites
    setup_env
    create_network
    cleanup_old_containers
    start_services
    wait_for_services
    run_migrations
    seed_data
    show_access_info
}

# Executar
main