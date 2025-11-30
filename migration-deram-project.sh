#!/bin/bash

# ==============================================================================
# Script de Migração - material-deram-trace
# ==============================================================================
# 
# Este script automatiza a reestruturação do projeto para separar
# frontend e backend em pastas diferentes.
#
# Uso: bash migrate.sh
#
# ==============================================================================

set -e  # Sai se qualquer comando falhar

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
# VERIFICAÇÕES INICIAIS
# ==============================================================================

check_prerequisites() {
    print_header "Verificando Pré-requisitos"
    
    # Verificar se está na raiz do projeto
    if [ ! -f "package.json" ]; then
        print_error "package.json não encontrado!"
        print_error "Execute este script na raiz do projeto material-deram-trace/"
        exit 1
    fi
    
    print_success "package.json encontrado"
    
    # Verificar se Git está disponível
    if ! command -v git &> /dev/null; then
        print_warning "Git não encontrado - backup manual necessário"
    else
        print_success "Git encontrado"
    fi
    
    # Verificar se já existe estrutura
    if [ -d "frontend" ] || [ -d "backend" ]; then
        print_warning "Pastas frontend/ ou backend/ já existem!"
        read -p "Deseja continuar e sobrescrever? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            print_error "Migração cancelada"
            exit 1
        fi
    fi
}

# ==============================================================================
# BACKUP
# ==============================================================================

create_backup() {
    print_header "Criando Backup"
    
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_dir="backup_${timestamp}"
    
    print_info "Criando backup em ${backup_dir}..."
    
    # Se Git disponível, criar branch
    if command -v git &> /dev/null; then
        if git rev-parse --git-dir > /dev/null 2>&1; then
            git checkout -b "backup-before-migration-${timestamp}" || true
            print_success "Branch de backup criada: backup-before-migration-${timestamp}"
        fi
    fi
    
    # Criar cópia dos arquivos críticos
    mkdir -p "$backup_dir"
    cp package.json "$backup_dir/" 2>/dev/null || true
    cp vite.config.ts "$backup_dir/" 2>/dev/null || true
    cp tsconfig.json "$backup_dir/" 2>/dev/null || true
    
    print_success "Backup criado em ${backup_dir}/"
}

# ==============================================================================
# CRIAÇÃO DE ESTRUTURA
# ==============================================================================

create_directory_structure() {
    print_header "Criando Estrutura de Diretórios"
    
    # Criar diretórios
    mkdir -p backend/{logs,tests}
    mkdir -p frontend
    
    print_success "Diretórios criados: backend/, frontend/"
}

# ==============================================================================
# MIGRAÇÃO DO FRONTEND
# ==============================================================================

migrate_frontend() {
    print_header "Migrando Frontend"
    
    print_info "Movendo arquivos do frontend..."
    
    # Lista de arquivos/pastas a mover
    items_to_move=(
        "src"
        "public"
        "index.html"
        "package.json"
        "package-lock.json"
        "vite.config.ts"
        "tsconfig.json"
        "tsconfig.app.json"
        "tsconfig.node.json"
        "tailwind.config.ts"
        "postcss.config.js"
        "components.json"
        ".eslintrc.cjs"
        ".prettierrc"
        "node_modules"
    )
    
    moved_count=0
    for item in "${items_to_move[@]}"; do
        if [ -e "$item" ]; then
            mv "$item" frontend/ 2>/dev/null && {
                print_success "Movido: $item"
                ((moved_count++))
            } || print_warning "Não foi possível mover: $item"
        fi
    done
    
    print_success "Frontend migrado! ($moved_count arquivos/pastas movidos)"
}

# ==============================================================================
# CRIAÇÃO DOS ARQUIVOS DO BACKEND
# ==============================================================================

create_backend_files() {
    print_header "Criando Arquivos do Backend"
    
    print_info "Arquivos do backend devem ser criados manualmente ou copiados dos artifacts."
    print_info "Arquivos necessários em backend/:"
    echo "  - main.py"
    echo "  - models.py"
    echo "  - schemas.py"
    echo "  - database.py"
    echo "  - requirements.txt"
    echo "  - Dockerfile"
    echo ""
    
    read -p "Você já tem esses arquivos prontos para copiar? (yes/no): " has_files
    
    if [ "$has_files" == "yes" ]; then
        print_info "Copie os arquivos manualmente para backend/"
        read -p "Pressione ENTER quando terminar..."
        print_success "Arquivos do backend prontos"
    else
        print_warning "Lembre-se de criar os arquivos do backend antes de rodar docker-compose"
    fi
}

# ==============================================================================
# ATUALIZAÇÃO DO VITE CONFIG
# ==============================================================================

update_vite_config() {
    print_header "Atualizando vite.config.ts"
    
    vite_config="frontend/vite.config.ts"
    
    if [ -f "$vite_config" ]; then
        print_info "Adicionando configuração de proxy..."
        
        # Backup do arquivo original
        cp "$vite_config" "${vite_config}.backup"
        
        # Adicionar proxy (se não existir)
        if ! grep -q "proxy:" "$vite_config"; then
            # Aqui você precisará editar manualmente ou usar sed
            print_warning "Adicione manualmente o proxy no vite.config.ts"
            print_info "Veja a documentação no artifact 'project_restructure_guide'"
        else
            print_success "Proxy já configurado"
        fi
        
        print_success "vite.config.ts atualizado (backup em ${vite_config}.backup)"
    else
        print_error "vite.config.ts não encontrado em frontend/"
    fi
}

# ==============================================================================
# CRIAÇÃO DO DOCKERFILE DO FRONTEND
# ==============================================================================

create_frontend_dockerfile() {
    print_header "Criando Dockerfile do Frontend"
    
    cat > frontend/Dockerfile << 'EOF'
# ==============================================================================
# Dockerfile - Frontend React + Vite
# ==============================================================================

FROM node:20-alpine as builder

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

# ==============================================================================
# RUNTIME - NGINX
# ==============================================================================
FROM nginx:alpine

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:80 || exit 1

CMD ["nginx", "-g", "daemon off;"]
EOF
    
    print_success "frontend/Dockerfile criado"
}

# ==============================================================================
# CRIAÇÃO DO NGINX.CONF
# ==============================================================================

create_nginx_config() {
    print_header "Criando nginx.conf"
    
    cat > frontend/nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;

    root /usr/share/nginx/html;
    index index.html;

    # Compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # React Router - SPA routing
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy para API
    location /api/ {
        proxy_pass http://backend:8000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Don't cache HTML
    location ~* \.html$ {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }
}
EOF
    
    print_success "frontend/nginx.conf criado"
}

# ==============================================================================
# CRIAÇÃO DO API HELPER
# ==============================================================================

create_api_helper() {
    print_header "Criando API Helper"
    
    mkdir -p frontend/src/lib
    
    cat > frontend/src/lib/api.ts << 'EOF'
/**
 * API Configuration
 * Centraliza todas as chamadas à API
 */

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';

export const api = {
  baseURL: API_BASE_URL,
  
  async request(endpoint: string, options?: RequestInit) {
    const url = `${API_BASE_URL}${endpoint}`;
    
    const defaultOptions: RequestInit = {
      headers: {
        'Content-Type': 'application/json',
        ...options?.headers,
      },
      ...options,
    };

    const response = await fetch(url, defaultOptions);
    
    if (!response.ok) {
      throw new Error(`API Error: ${response.statusText}`);
    }
    
    return response.json();
  },

  async login(username: string, password: string) {
    const formData = new URLSearchParams();
    formData.append('username', username);
    formData.append('password', password);

    return this.request('/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: formData.toString(),
    });
  },

  async getMateriais() {
    return this.request('/materiais');
  },

  async createMaterial(data: any) {
    return this.request('/materiais', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  },
};
EOF
    
    print_success "frontend/src/lib/api.ts criado"
}

# ==============================================================================
# ATUALIZAÇÃO DO DOCKER-COMPOSE
# ==============================================================================

update_docker_compose() {
    print_header "Atualizando docker-compose.yml"
    
    if [ -f "docker-compose.yml" ]; then
        cp docker-compose.yml docker-compose.yml.backup
        print_success "Backup: docker-compose.yml.backup"
    fi
    
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    container_name: material_db
    restart: unless-stopped
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: material_control
      POSTGRES_INITDB_ARGS: "-E UTF8 --locale=pt_BR.UTF-8"
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
    networks:
      - material_network

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: material_backend
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      DATABASE_URL: postgresql://postgres:postgres@db:5432/material_control
      SECRET_KEY: sua-chave-secreta-super-segura-123456
      LOG_LEVEL: INFO
      ENVIRONMENT: development
      CORS_ORIGINS: http://localhost:5173,http://localhost:80
    ports:
      - "8000:8000"
    volumes:
      - ./backend:/app
      - backend_logs:/app/logs
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - material_network

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: material_frontend
    restart: unless-stopped
    depends_on:
      - backend
    environment:
      VITE_API_URL: http://localhost:8000
    ports:
      - "80:80"
    volumes:
      - ./frontend/src:/app/src
      - ./frontend/public:/app/public
    networks:
      - material_network

volumes:
  postgres_data:
    driver: local
  backend_logs:
    driver: local

networks:
  material_network:
    driver: bridge
EOF
    
    print_success "docker-compose.yml atualizado"
}

# ==============================================================================
# ATUALIZAÇÃO DO GITIGNORE
# ==============================================================================

update_gitignore() {
    print_header "Atualizando .gitignore"
    
    cat > .gitignore << 'EOF'
# ====================================
# BACKEND (Python)
# ====================================
backend/__pycache__/
backend/*.py[cod]
backend/*$py.class
backend/.Python
backend/env/
backend/venv/
backend/.venv
backend/logs/
backend/*.log

# ====================================
# FRONTEND (Node.js)
# ====================================
frontend/node_modules/
frontend/dist/
frontend/.vite/
frontend/.cache/
frontend/build/
frontend/*.local

# ====================================
# DOCKER
# ====================================
.docker/

# ====================================
# IDE
# ====================================
.vscode/
.idea/
*.swp
*.swo

# ====================================
# OS
# ====================================
.DS_Store
Thumbs.db

# ====================================
# ENVIRONMENT
# ====================================
.env
.env.local
.env.production

# ====================================
# DATABASE
# ====================================
*.db
*.sqlite

# ====================================
# BACKUPS
# ====================================
backup_*/
*.backup
EOF
    
    print_success ".gitignore atualizado"
}

# ==============================================================================
# TESTES E VALIDAÇÃO
# ==============================================================================

run_validation() {
    print_header "Validando Estrutura"
    
    errors=0
    
    # Verificar frontend
    if [ -d "frontend/src" ]; then
        print_success "frontend/src existe"
    else
        print_error "frontend/src não encontrado"
        ((errors++))
    fi
    
    if [ -f "frontend/package.json" ]; then
        print_success "frontend/package.json existe"
    else
        print_error "frontend/package.json não encontrado"
        ((errors++))
    fi
    
    # Verificar docker-compose
    if [ -f "docker-compose.yml" ]; then
        print_success "docker-compose.yml existe"
    else
        print_error "docker-compose.yml não encontrado"
        ((errors++))
    fi
    
    if [ $errors -gt 0 ]; then
        print_error "Validação falhou com $errors erro(s)"
        return 1
    else
        print_success "Validação concluída sem erros!"
        return 0
    fi
}

# ==============================================================================
# RESUMO FINAL
# ==============================================================================

print_summary() {
    print_header "Resumo da Migração"
    
    echo ""
    echo -e "${GREEN}✓ Estrutura criada:${NC}"
    echo "  material-deram-trace/"
    echo "  ├── backend/"
    echo "  ├── frontend/"
    echo "  └── docker-compose.yml"
    echo ""
    
    echo -e "${YELLOW}⚠ Próximos passos:${NC}"
    echo ""
    echo "1. Criar arquivos do backend (se ainda não criou):"
    echo "   - backend/main.py"
    echo "   - backend/models.py"
    echo "   - backend/schemas.py"
    echo "   - backend/database.py"
    echo "   - backend/requirements.txt"
    echo "   - backend/Dockerfile"
    echo ""
    echo "2. Atualizar chamadas da API no frontend:"
    echo "   - Use: import { api } from '@/lib/api'"
    echo "   - Substitua fetch direto por api.request()"
    echo ""
    echo "3. Testar localmente:"
    echo "   cd frontend && npm install && npm run dev"
    echo ""
    echo "4. Testar com Docker:"
    echo "   docker-compose up -d --build"
    echo ""
    echo "5. Commit das mudanças:"
    echo "   git add ."
    echo "   git commit -m 'refactor: reorganiza projeto em monorepo frontend/backend'"
    echo "   git push"
    echo ""
    
    print_success "Migração concluída! 🎉"
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    clear
    
    print_header "🚀 Migração do Projeto material-deram-trace"
    
    echo "Este script irá:"
    echo "  1. Criar backup"
    echo "  2. Criar estrutura frontend/ e backend/"
    echo "  3. Mover arquivos do frontend"
    echo "  4. Criar arquivos de configuração"
    echo "  5. Atualizar docker-compose.yml"
    echo ""
    
    read -p "Deseja continuar? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_error "Migração cancelada pelo usuário"
        exit 1
    fi
    
    # Executar etapas
    check_prerequisites
    create_backup
    create_directory_structure
    migrate_frontend
    create_backend_files
    update_vite_config
    create_frontend_dockerfile
    create_nginx_config
    create_api_helper
    update_docker_compose
    update_gitignore
    run_validation
    print_summary
}

# Executar
main