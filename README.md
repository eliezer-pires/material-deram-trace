# 🏗️ Sistema de Controle de Materiais - Backend #
## Sistema de gerenciamento de materiais com QR Code, desenvolvido com FastAPI, PostgreSQL e Docker. ##

### 📋 Índice ###

1. Pré-requisitos
2. Estrutura do Projeto
3. Instalação e Setup
4. Rodando a Aplicação
5. Endpoints da API
6. Arquitetura
7. DevOps e Deploy
8. Troubleshooting

### 🔧 Pré-requisitos ###

#### Software Necessário ####
```bash
# Docker e Docker Compose
Docker Engine 20.10+
Docker Compose 2.0+

# Ou localmente (sem Docker):
Python 3.11+
PostgreSQL 15+
```

#### Verificar Instalação ####
```bash
# Docker
docker --version
docker-compose --version

# Python (se rodar localmente)
python --version
psql --version
```

### 📁 Estrutura do Projeto ###
```bash
material-deram-trace/
├── backend/
│   ├── main.py              # Entry point da API
│   ├── models.py            # Modelos do banco (SQLAlchemy)
│   ├── schemas.py           # Schemas de validação (Pydantic)
│   ├── database.py          # Configuração do banco
│   ├── requirements.txt     # Dependências Python
│   └── Dockerfile           # Imagem Docker do backend
│
├── frontend/
│   └── ...                  # Código React
│
├── docker-compose.yml       # Orquestração dos containers
└── README.md               # Esta documentação
```

### 🚀 Instalação e Setup ###

## Opção 1: Com Docker (Recomendado) ##
```bash
# 1. Clone o repositório
git clone https://github.com/eliezer-pires/material-deram-trace.git
cd material-deram-trace

# 2. Crie a estrutura de diretórios do backend
mkdir -p backend

# 3. Coloque os arquivos criados no diretório backend/
# - main.py
# - models.py
# - schemas.py
# - database.py
# - requirements.txt
# - Dockerfile

# 4. Inicie os containers
docker-compose up -d

# 5. Verifique os logs
docker-compose logs -f backend

# 6. Acesse a documentação da API
# http://localhost:8000/docs
```

## Opção 2: Localmente (Desenvolvimento) ##
```bash
# 1. Criar ambiente virtual
python -m venv venv
source venv/bin/activate  # Linux/Mac
# ou
venv\Scripts\activate     # Windows

# 2. Instalar dependências
cd backend
pip install -r requirements.txt

# 3. Configurar banco de dados PostgreSQL
createdb material_control

# 4. Configurar variável de ambiente
export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/material_control"

# 5. Iniciar servidor
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# 6. Acesse: http://localhost:8000/docs
```

## 🎮 Rodando a Aplicação ##

### Comandos Docker ###
```bash
# Iniciar tudo
docker-compose up -d

# Parar tudo
docker-compose down

# Rebuild das imagens
docker-compose build
docker-compose up -d --build

# Ver logs
docker-compose logs -f        # Todos
docker-compose logs -f backend
docker-compose logs -f db

# Executar comandos no container
docker-compose exec backend bash
docker-compose exec db psql -U postgres

# Ver status
docker-compose ps

# Remover volumes (⚠️ DELETA DADOS!)
docker-compose down -v
```

### Verificar Saúde da Aplicação ###
```bash
# Health check do backend
curl http://localhost:8000/health

# Resposta esperada:
# {"status":"healthy","timestamp":"2024-01-01T12:00:00","version":"1.0.0"}

# Verificar banco de dados
docker-compose exec db pg_isready -U postgres
```
## 📡 Endpoints da API ##

### Autenticação ###
```bash
# Login
POST /token
Body: username=admin&password=123456
Response: {"access_token": "...", "token_type": "bearer"}

# Obter usuário atual
GET /users/me
Headers: Authorization: Bearer <token>
```

### Materiais ####
```bash
# Criar material
POST /materiais
Headers: Authorization: Bearer <token>
Body: {
  "nome": "Notebook Dell",
  "bmp": "NB-001",
  "setor": "TI",
  "sala": "Sala 101",
  "responsavel": "João Silva"
}

# Listar materiais
GET /materiais?skip=0&limit=100&setor=TI
Headers: Authorization: Bearer <token>

# Obter material específico
GET /materiais/{id}
Headers: Authorization: Bearer <token>

# Atualizar material
PUT /materiais/{id}
Headers: Authorization: Bearer <token>
Body: {"sala": "Sala 102"}

# Deletar material (apenas admin)
DELETE /materiais/{id}
Headers: Authorization: Bearer <token>
```

### QR Code ###
```bash
# Gerar imagem do QR Code
GET /materiais/{id}/qrcode
Headers: Authorization: Bearer <token>
Response: Imagem PNG

# Registrar conferência (scan)
POST /conferencia/scan
Headers: Authorization: Bearer <token>
Body: {
  "qr_hash": "abc123def456",
  "setor": "TI",
  "sala": "Sala 102"
}
```

### Setores ###
```bash
# Listar setores
GET /setores
Headers: Authorization: Bearer <token>

# Listar salas de um setor
GET /setores/{setor}/salas
Headers: Authorization: Bearer <token>

# Listar materiais por localização
GET /setores/{setor}/salas/{sala}/materiais
Headers: Authorization: Bearer <token>
```

### Dashboard ###
```bash
# Estatísticas gerais
GET /dashboard/stats
Headers: Authorization: Bearer <token>
Response: {
  "total_materiais": 150,
  "materiais_conferidos": 120,
  "materiais_nao_conferidos": 30,
  "total_setores": 5,
  "taxa_conferencia": 80.0
}
```

## 🏛️ Arquitetura ##
### Stack Tecnológico ###
```bash
┌─────────────────────────────────────┐
│         FRONTEND (React)            │
│    Vite + TypeScript + Tailwind     │
└──────────────┬──────────────────────┘
               │ HTTP/REST
               ↓
┌─────────────────────────────────────┐
│         BACKEND (FastAPI)           │
│      Python 3.11 + Uvicorn          │
├─────────────────────────────────────┤
│           SQLAlchemy ORM            │
└──────────────┬──────────────────────┘
               │ SQL
               ↓
┌─────────────────────────────────────┐
│      BANCO DE DADOS (PostgreSQL)    │
│            Version 15               │
└─────────────────────────────────────┘
```

### Camadas da Aplicação ###
```bash
API Layer (main.py)
    ↓
Validation Layer (schemas.py)
    ↓
Business Logic Layer (services - futuro)
    ↓
Data Access Layer (models.py)
    ↓
Database (PostgreSQL)
```

### Fluxo de Dados - Conferência ###
```bash
1. Mobile App lê QR Code
   ↓
2. Obtém qr_hash do código
   ↓
3. POST /conferencia/scan
   ↓
4. Backend busca material pelo hash
   ↓
5. Atualiza localização no banco
   ↓
6. Retorna confirmação + dados do material
```

## 🔐 Segurança ##
### Autenticação JWT ###
```python
python# Token válido por 8 horas
# Secret key DEVE ser alterada em produção!
SECRET_KEY = "sua-chave-secreta-super-segura"  # MUDE ISSO!

# Use variável de ambiente:
SECRET_KEY = os.getenv("SECRET_KEY")
```
### Senhas ###
```python
# Bcrypt para hashing
# Nunca armazenamos senhas em texto plano!
hashed_password = pwd_context.hash("123456")
```

### CORS ###
```python
# Em produção, especifique domínios permitidos:
allow_origins=["https://seu-dominio.com"]
# Nunca use "*" em produção!
```
## 🚢 DevOps e Deploy ##
### Ambiente de Desenvolvimento ###
```bash
# docker-compose.yml (já configurado)
docker-compose up -d
```

## Ambiente de Produção ##
```yaml
yaml# docker-compose.prod.yml
version: '3.8'
services:
  backend:
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - SECRET_KEY=${SECRET_KEY}
      - ENVIRONMENT=production
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
```
```bash
# Deploy produção #
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## CI/CD com GitHub Actions ##
```yaml
# .github/workflows/deploy.yml
name: Deploy to Production
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Build Docker image
        run: docker build -t material-backend:${{ github.sha }} ./backend
      
      - name: Push to registry
        run: |
          echo ${{ secrets.DOCKER_PASSWORD }} | docker login -u ${{ secrets.DOCKER_USERNAME }} --password-stdin
          docker push material-backend:${{ github.sha }}
      
      - name: Deploy to server
        run: |
          ssh user@server "docker pull material-backend:${{ github.sha }}"
          ssh user@server "docker-compose up -d"
```

## Kubernetes (Futuro) ##
```bash
# Gerar manifests do docker-compose
kompose convert -f docker-compose.yml

# Ou criar Helm chart
helm create material-control

# Deploy no K8s
kubectl apply -f manifests/
# ou
helm install material-control ./chart
```

## 📊 Monitoramento ##
### Logs ###
```bash
# Ver logs em tempo real
docker-compose logs -f backend

# Logs estruturados (JSON)
# TODO: Implementar loguru ou estruturar logs
```

### Métricas (Prometheus - Futuro) ###
pythonfrom prometheus_client import Counter, Histogram

# Métricas importantes:
# - Requests por segundo
# - Latência de queries
# - Taxa de erro
# - Uso de recursos

### Health Checks ###
```bash
# Endpoint de health
curl http://localhost:8000/health

# Docker health check (automático)
docker ps  # Veja status "healthy"
```

## 🐛 Troubleshooting ##
### Problema: Container não inicia ###
```bash
# Verificar logs
docker-compose logs backend

# Erros comuns:
# 1. Banco não está pronto
#    → Aguarde health check do PostgreSQL
#
# 2. Porta já em uso
#    → Mude porta em docker-compose.yml
#
# 3. Erro de conexão com banco
#    → Verifique DATABASE_URL
```
### Problema: Erro 401 Unauthorized ##
```bash
# Token expirado ou inválido
# Solução: Faça login novamente

POST /token
Body: username=admin&password=123456
```

### Problema: QR Code não gera ###
```bash
# Verificar se Pillow está instalado
docker-compose exec backend pip list | grep Pillow

# Reinstalar se necessário
docker-compose exec backend pip install Pillow qrcode[pil]
```

### Problema: Banco de dados perdeu dados ###
```bash
# Dados são persistidos em volumes
# Verifique se volume existe:
docker volume ls | grep postgres_data

# Backup manual:
docker-compose exec db pg_dump -U postgres material_control > backup.sql

# Restore:
docker-compose exec -T db psql -U postgres material_control < backup.sql
```

### Reset Completo ###
```bash
# ⚠️ CUIDADO: Deleta TUDO!
docker-compose down -v
docker-compose up -d --build
```

## 🧪 Testes ##
### Testes Manuais ####
```bash
# 1. Health check
curl http://localhost:8000/health

# 2. Login
curl -X POST http://localhost:8000/token \
  -d "username=admin&password=123456"

# 3. Listar materiais
TOKEN="seu-token-aqui"
curl http://localhost:8000/materiais \
  -H "Authorization: Bearer $TOKEN"
```
### Testes Automatizados (Futuro)###
```bash
# Instalar pytest
pip install pytest pytest-asyncio

# Rodar testes
pytest

# Com cobertura
pytest --cov=. --cov-report=html
```

## 📚 Referências ##
### Documentação ###

- FastAPI Docs
- SQLAlchemy Docs
- PostgreSQL Docs
- Docker Docs

### Tutoriais ###

- FastAPI Tutorial
- SQLAlchemy ORM Tutorial
- Docker Compose Tutorial

## 🤝 Contribuindo ##
```bash
# 1. Fork o repositório
# 2. Crie uma branch
git checkout -b feature/nova-funcionalidade

# 3. Commit suas mudanças
git commit -m "Adiciona nova funcionalidade"

# 4. Push para o GitHub
git push origin feature/nova-funcionalidade

# 5. Abra um Pull Request
```

## 📝 Próximos Passos ##

 [] - Implementar testes automatizados
 [] - Adicionar Alembic para migrations
 [] - Implementar cache com Redis
 [] - Adicionar Prometheus + Grafana
 [] - Implementar rate limiting
 [] - Adicionar CI/CD completo
 [] - Documentar API com OpenAPI
 [] - Implementar backup automatizado
 [] - Adicionar autenticação OAuth2
 [] - Migrar para Kubernetes


## 📄 Licença ##
MIT License - Veja LICENSE para detalhes

### 👤 Contato ###

GitHub: @eliezer-pires
Email: seu-email@exemplo.com


## Desenvolvido com ❤️ usando FastAPI + PostgreSQL + Docker ## 