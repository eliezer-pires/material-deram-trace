#!/bin/bash

# ==============================================================================
# Scripts Úteis para DevOps/SRE - Sistema de Controle de Materiais
# ==============================================================================
# 
# Este arquivo contém scripts úteis para gerenciar a aplicação
# Coloque na raiz do projeto e dê permissão de execução:
# chmod +x scripts.sh
# 
# ==============================================================================

set -e  # Sai se algum comando falhar

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ==============================================================================
# FUNÇÕES AUXILIARES
# ==============================================================================

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
    echo -e "${NC}ℹ $1${NC}"
}

# ==============================================================================
# SETUP INICIAL
# ==============================================================================

setup_project() {
    print_info "Configurando projeto..."
    
    # Criar estrutura de diretórios
    mkdir -p backend/{logs,tests}
    mkdir -p frontend/src
    mkdir -p scripts
    mkdir -p .github/workflows
    
    # Criar .gitignore
    cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
ENV/
.venv

# Docker
.docker/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/

# Database
*.db
*.sqlite

# Environment
.env
.env.local
EOF
    
    # Criar .dockerignore
    cat > backend/.dockerignore << 'EOF'
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
env/
venv/
.git/
.gitignore
.pytest_cache/
.coverage
htmlcov/
dist/
build/
*.egg-info/
.DS_Store
*.log
logs/
EOF
    
    print_success "Projeto configurado!"
}

# ==============================================================================
# BUILD E DEPLOY
# ==============================================================================

build_backend() {
    print_info "Building backend..."
    cd backend
    docker build -t material-backend:latest .
    cd ..
    print_success "Backend built!"
}

deploy_dev() {
    print_info "Deploying to development..."
    docker-compose up -d --build
    print_success "Development environment up!"
    
    print_info "Waiting for services to be healthy..."
    sleep 10
    
    # Verificar health
    if curl -f http://localhost:8000/health > /dev/null 2>&1; then
        print_success "Backend is healthy!"
    else
        print_error "Backend health check failed!"
        docker-compose logs backend
    fi
}

deploy_prod() {
    print_warning "Deploying to PRODUCTION..."
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_error "Deployment cancelled"
        exit 1
    fi
    
    # Backup antes do deploy
    backup_database
    
    # Deploy
    docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
    
    print_success "Production deployed!"
}

# ==============================================================================
# BANCO DE DADOS
# ==============================================================================

backup_database() {
    print_info "Backing up database..."
    
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_file="backup_${timestamp}.sql"
    
    docker-compose exec -T db pg_dump -U postgres material_control > "$backup_file"
    
    # Compactar
    gzip "$backup_file"
    
    print_success "Backup saved: ${backup_file}.gz"
}

restore_database() {
    if [ -z "$1" ]; then
        print_error "Usage: $0 restore_database <backup_file.sql>"
        exit 1
    fi
    
    print_warning "This will OVERWRITE the current database!"
    read -p "Continue? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_error "Restore cancelled"
        exit 1
    fi
    
    print_info "Restoring database..."
    
    # Se for .gz, descompactar
    if [[ $1 == *.gz ]]; then
        gunzip -c "$1" | docker-compose exec -T db psql -U postgres material_control
    else
        docker-compose exec -T db psql -U postgres material_control < "$1"
    fi
    
    print_success "Database restored!"
}

init_database() {
    print_info "Initializing database..."
    
    docker-compose exec backend python -c "
from database import init_db
init_db()
print('Database initialized!')
"
    
    print_success "Database initialized!"
}

# ==============================================================================
# LOGS E MONITORAMENTO
# ==============================================================================

show_logs() {
    service=${1:-backend}
    print_info "Showing logs for $service..."
    docker-compose logs -f --tail=100 "$service"
}

show_all_logs() {
    print_info "Showing all logs..."
    docker-compose logs -f --tail=50
}

check_health() {
    print_info "Checking services health..."
    
    # Backend
    if curl -f http://localhost:8000/health > /dev/null 2>&1; then
        print_success "Backend: healthy"
    else
        print_error "Backend: unhealthy"
    fi
    
    # Database
    if docker-compose exec db pg_isready -U postgres > /dev/null 2>&1; then
        print_success "Database: healthy"
    else
        print_error "Database: unhealthy"
    fi
    
    # Frontend
    if curl -f http://localhost:80 > /dev/null 2>&1; then
        print_success "Frontend: healthy"
    else
        print_error "Frontend: unhealthy"
    fi
}

show_stats() {
    print_info "Container statistics:"
    docker stats --no-stream
}

# ==============================================================================
# LIMPEZA E MANUTENÇÃO
# ==============================================================================

clean_containers() {
    print_info "Stopping and removing containers..."
    docker-compose down
    print_success "Containers stopped!"
}

clean_all() {
    print_warning "This will remove containers, images, and volumes!"
    read -p "Continue? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_error "Cleaning cancelled"
        exit 1
    fi
    
    print_info "Cleaning everything..."
    docker-compose down -v --rmi all
    print_success "All cleaned!"
}

clean_logs() {
    print_info "Cleaning logs..."
    rm -rf backend/logs/*.log
    print_success "Logs cleaned!"
}

# ==============================================================================
# TESTES
# ==============================================================================

run_tests() {
    print_info "Running tests..."
    docker-compose exec backend pytest -v
    print_success "Tests completed!"
}

run_tests_coverage() {
    print_info "Running tests with coverage..."
    docker-compose exec backend pytest --cov=. --cov-report=html
    print_success "Tests completed! Check htmlcov/index.html"
}

# ==============================================================================
# SECURITY
# ==============================================================================

scan_security() {
    print_info "Scanning for vulnerabilities..."
    
    # Python dependencies
    print_info "Checking Python dependencies..."
    docker-compose exec backend pip-audit
    
    # Docker image
    print_info "Scanning Docker image..."
    if command -v trivy &> /dev/null; then
        trivy image material-backend:latest
    else
        print_warning "Trivy not installed. Install: https://github.com/aquasecurity/trivy"
    fi
}

update_dependencies() {
    print_info "Updating Python dependencies..."
    docker-compose exec backend pip list --outdated
    print_warning "Review updates manually in requirements.txt"
}

# ==============================================================================
# UTILITÁRIOS
# ==============================================================================

shell_backend() {
    print_info "Opening shell in backend container..."
    docker-compose exec backend bash
}

shell_db() {
    print_info "Opening psql in database..."
    docker-compose exec db psql -U postgres material_control
}

create_migration() {
    if [ -z "$1" ]; then
        print_error "Usage: $0 create_migration <message>"
        exit 1
    fi
    
    print_info "Creating migration: $1"
    docker-compose exec backend alembic revision --autogenerate -m "$1"
    print_success "Migration created!"
}

apply_migrations() {
    print_info "Applying migrations..."
    docker-compose exec backend alembic upgrade head
    print_success "Migrations applied!"
}

# ==============================================================================
# MENU PRINCIPAL
# ==============================================================================

show_menu() {
    echo ""
    echo "=================================="
    echo "  Material Control - DevOps CLI  "
    echo "=================================="
    echo ""
    echo "Setup:"
    echo "  1) Setup project structure"
    echo ""
    echo "Build & Deploy:"
    echo "  2) Build backend"
    echo "  3) Deploy development"
    echo "  4) Deploy production"
    echo ""
    echo "Database:"
    echo "  5) Backup database"
    echo "  6) Restore database"
    echo "  7) Initialize database"
    echo ""
    echo "Monitoring:"
    echo "  8) Show logs (backend)"
    echo "  9) Show all logs"
    echo "  10) Check health"
    echo "  11) Show stats"
    echo ""
    echo "Maintenance:"
    echo "  12) Clean containers"
    echo "  13) Clean all (⚠️  dangerous)"
    echo "  14) Clean logs"
    echo ""
    echo "Testing:"
    echo "  15) Run tests"
    echo "  16) Run tests with coverage"
    echo ""
    echo "Security:"
    echo "  17) Security scan"
    echo "  18) Check outdated dependencies"
    echo ""
    echo "Utils:"
    echo "  19) Shell (backend)"
    echo "  20) Shell (database)"
    echo "  21) Create migration"
    echo "  22) Apply migrations"
    echo ""
    echo "  0) Exit"
    echo ""
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    # Se passar argumento, executar comando direto
    if [ $# -gt 0 ]; then
        case "$1" in
            setup) setup_project ;;
            build) build_backend ;;
            deploy-dev) deploy_dev ;;
            deploy-prod) deploy_prod ;;
            backup) backup_database ;;
            restore) restore_database "$2" ;;
            init-db) init_database ;;
            logs) show_logs "$2" ;;
            health) check_health ;;
            stats) show_stats ;;
            clean) clean_containers ;;
            test) run_tests ;;
            shell) shell_backend ;;
            *) 
                print_error "Unknown command: $1"
                echo "Usage: $0 [setup|build|deploy-dev|deploy-prod|backup|restore|logs|health|stats|clean|test|shell]"
                exit 1
                ;;
        esac
        exit 0
    fi
    
    # Menu interativo
    while true; do
        show_menu
        read -p "Select option: " choice
        
        case $choice in
            1) setup_project ;;
            2) build_backend ;;
            3) deploy_dev ;;
            4) deploy_prod ;;
            5) backup_database ;;
            6) 
                read -p "Backup file: " file
                restore_database "$file"
                ;;
            7) init_database ;;
            8) show_logs backend ;;
            9) show_all_logs ;;
            10) check_health ;;
            11) show_stats ;;
            12) clean_containers ;;
            13) clean_all ;;
            14) clean_logs ;;
            15) run_tests ;;
            16) run_tests_coverage ;;
            17) scan_security ;;
            18) update_dependencies ;;
            19) shell_backend ;;
            20) shell_db ;;
            21) 
                read -p "Migration message: " msg
                create_migration "$msg"
                ;;
            22) apply_migrations ;;
            0) 
                print_info "Goodbye!"
                exit 0
                ;;
            *) 
                print_error "Invalid option!"
                ;;
        esac
        
        echo ""
        read -p "Press enter to continue..."
    done
}

# Executar
main "$@"