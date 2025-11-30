# ==============================================================================
# Dockerfile - Backend FastAPI
# ==============================================================================
# 
# Multi-stage build para imagem otimizada
# 
# Stage 1 (builder): Instala dependências e compila
# Stage 2 (runtime): Imagem final enxuta
# 
# Vantagens:
# - Imagem menor (200MB vs 1GB)
# - Mais segura (menos superfície de ataque)
# - Build cache eficiente
# - Separação de dependências de build e runtime
# 
# ==============================================================================

# ==============================================================================
# STAGE 1: BUILDER
# ==============================================================================
FROM python:3.11-slim as builder

# Por que Python 3.11?
# - Type hints melhorados (importante para FastAPI/Pydantic)
# - Performance 10-60% melhor que 3.10
# - Async/await otimizado
# 
# Por que slim?
# - 120MB vs 900MB (full)
# - Inclui ferramentas essenciais
# - Boa para builds

LABEL maintainer="eliezerpiresti@gmail.com"
LABEL version="1.0"
LABEL description="Backend API - Sistema de Controle de Materiais"

# Variáveis de ambiente para Python
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# PYTHONUNBUFFERED=1: Logs em tempo real (não fica em buffer)
# PYTHONDONTWRITEBYTECODE=1: Não gera arquivos .pyc (economiza espaço)
# PIP_NO_CACHE_DIR=1: Não cacheia downloads (economiza espaço)

WORKDIR /app

# Instalar dependências do sistema necessárias para compilação
# Estas são necessárias para instalar alguns pacotes Python
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# build-essential: GCC e ferramentas de compilação
# libpq-dev: Headers do PostgreSQL (necessário para psycopg2)
# curl: Para health checks
# rm -rf /var/lib/apt/lists/*: Limpa cache do apt (economiza ~50MB)

# Copiar apenas requirements.txt primeiro
# Por quê? Docker cache! Se requirements não mudar, reutiliza layer
COPY requirements.txt .

# Instalar dependências Python
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# --no-cache-dir: Não guarda cache do pip (economiza ~100MB)


# ==============================================================================
# STAGE 2: RUNTIME
# ==============================================================================
FROM python:3.11-slim

# Segunda imagem slim (menor, sem ferramentas de build)

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/app/.venv/bin:$PATH"

WORKDIR /app

# Instalar apenas dependências de runtime (não de build!)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# libpq5: Biblioteca PostgreSQL runtime (sem headers de dev)
# Note que NÃO instalamos build-essential aqui!

# Copiar dependências instaladas do stage builder
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Esta é a mágica do multi-stage build!
# Copiamos apenas os pacotes compilados, não o GCC e outras ferramentas

# Criar usuário não-root para segurança
RUN groupadd -r appuser && \
    useradd -r -g appuser -u 1000 appuser && \
    chown -R appuser:appuser /app

# Por que não usar root?
# - Princípio de menor privilégio
# - Se houver vulnerabilidade, dano é limitado
# - Boas práticas de segurança
# - Compliance (PCI-DSS, SOC2, etc)

# Copiar código da aplicação
COPY --chown=appuser:appuser . .

# --chown: Define dono dos arquivos copiados

# Criar diretórios necessários
RUN mkdir -p /app/logs && \
    chown -R appuser:appuser /app/logs

# Mudar para usuário não-root
USER appuser

# Expor porta da aplicação
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Por que health check no Dockerfile?
# - Docker/Docker Compose pode monitorar saúde
# - Kubernetes usa para liveness/readiness probes
# - Facilita troubleshooting

# Comando para iniciar a aplicação
# Usando Uvicorn (servidor ASGI para FastAPI)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]

# Explicação dos parâmetros:
# 
# uvicorn: Servidor ASGI rápido (escrito em Cython)
# main:app: Importa 'app' do arquivo 'main.py'
# --host 0.0.0.0: Aceita conexões de qualquer IP (necessário no Docker)
# --port 8000: Porta da aplicação
# --workers 2: Múltiplos processos (workers)
# 
# Quantos workers usar?
# Fórmula: (2 x CPU cores) + 1
# Exemplo: 2 cores → 5 workers
# 
# Para PRODUÇÃO, adicione:
# --workers 4: Mais workers
# --log-config logging.conf: Logging estruturado
# --access-log: Log de requisições
# --proxy-headers: Para rodar atrás de proxy reverso (Nginx, Traefik)
# 
# Exemplo produção:
# CMD ["uvicorn", "main:app", \
#      "--host", "0.0.0.0", \
#      "--port", "8000", \
#      "--workers", "4", \
#      "--proxy-headers", \
#      "--forwarded-allow-ips", "*"]


# ==============================================================================
# ALTERNATIVA: GUNICORN + UVICORN WORKERS (RECOMENDADO PARA PRODUÇÃO)
# ==============================================================================
# 
# Gunicorn é mais robusto para produção:
# 
# RUN pip install gunicorn
# 
# CMD ["gunicorn", "main:app", \
#      "--workers", "4", \
#      "--worker-class", "uvicorn.workers.UvicornWorker", \
#      "--bind", "0.0.0.0:8000", \
#      "--timeout", "60", \
#      "--graceful-timeout", "30", \
#      "--access-logfile", "-", \
#      "--error-logfile", "-", \
#      "--log-level", "info"]
# 
# Vantagens do Gunicorn:
# - Gerenciamento robusto de workers
# - Graceful reload (zero downtime)
# - Timeouts configuráveis
# - Melhor handling de sinais (SIGTERM, SIGHUP)
# - Production-tested (usado por grandes empresas)
# 
# ==============================================================================


# ==============================================================================
# BUILD E RUN
# ==============================================================================
# 
# Build da imagem:
#   docker build -t material-backend:latest .
# 
# Build com tag de versão:
#   docker build -t material-backend:1.0.0 .
# 
# Run (standalone):
#   docker run -d \
#     --name material-backend \
#     -p 8000:8000 \
#     -e DATABASE_URL=postgresql://user:pass@db:5432/dbname \
#     material-backend:latest
# 
# Verificar logs:
#   docker logs -f material-backend
# 
# Executar shell no container:
#   docker exec -it material-backend bash
# 
# Verificar tamanho da imagem:
#   docker images material-backend
#   # Deve ser ~200-300MB (vs 1GB+ sem multi-stage)
# 
# ==============================================================================


# ==============================================================================
# OTIMIZAÇÕES ADICIONAIS
# ==============================================================================
# 
# 1. .dockerignore (criar na raiz do projeto):
#    __pycache__/
#    *.pyc
#    *.pyo
#    *.pyd
#    .Python
#    env/
#    venv/
#    .git/
#    .gitignore
#    .pytest_cache/
#    .coverage
#    htmlcov/
#    dist/
#    build/
#    *.egg-info/
#    .DS_Store
# 
# 2. Cache de build (BuildKit):
#    DOCKER_BUILDKIT=1 docker build --cache-from material-backend:latest .
# 
# 3. Scanning de segurança:
#    docker scan material-backend:latest
#    # ou
#    trivy image material-backend:latest
# 
# 4. Layer analysis:
#    dive material-backend:latest
# 
# ==============================================================================


# ==============================================================================
# CI/CD INTEGRATION
# ==============================================================================
# 
# GitHub Actions example (.github/workflows/build.yml):
# 
# name: Build and Push
# on: [push]
# jobs:
#   build:
#     runs-on: ubuntu-latest
#     steps:
#       - uses: actions/checkout@v2
#       - name: Build image
#         run: docker build -t material-backend:${{ github.sha }} .
#       - name: Push to registry
#         run: |
#           docker tag material-backend:${{ github.sha }} registry.com/material-backend:latest
#           docker push registry.com/material-backend:latest
# 
# ==============================================================================