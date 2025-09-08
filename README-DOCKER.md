# 🐳 Sistema de Controle de Materiais - Docker

Este documento explica como executar o Sistema de Controle de Materiais usando Docker.

## 📋 Pré-requisitos

- Docker Desktop instalado
- Docker Compose instalado
- Git (para clonar o repositório)

## 🚀 Como executar

### 1. Clone o repositório
```bash
git clone <seu-repositorio>
cd sistema-controle-materiais
```

### 2. Execute com Docker Compose
```bash
# Iniciar todos os serviços
docker-compose up -d

# Ver logs do frontend
docker-compose logs -f frontend

# Ver logs de todos os serviços
docker-compose logs -f
```

### 3. Acesse o sistema

- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:3001 (em desenvolvimento)
- **Adminer (DB Manager)**: http://localhost:8080
- **Banco PostgreSQL**: localhost:5432

## 🔐 Credenciais de acesso

### Sistema
- **Login**: admin
- **Senha**: 123456

### Banco de dados (Adminer)
- **Sistema**: PostgreSQL
- **Servidor**: database
- **Usuário**: admin
- **Senha**: 123456
- **Base de dados**: controle_materiais

## 📊 Serviços inclusos

| Serviço | Porta | Descrição |
|---------|--------|-----------|
| frontend | 3000 | Interface React/Vite |
| backend | 3001 | API Node.js (em desenvolvimento) |
| database | 5432 | PostgreSQL 15 |
| redis | 6379 | Cache e sessões |
| adminer | 8080 | Interface web do banco |

## 🔧 Comandos úteis

```bash
# Parar todos os serviços
docker-compose down

# Parar e remover volumes (limpa banco)
docker-compose down -v

# Reconstruir imagens
docker-compose build

# Reiniciar apenas um serviço
docker-compose restart frontend

# Ver status dos containers
docker-compose ps

# Acessar bash do container
docker-compose exec frontend sh
docker-compose exec database psql -U admin -d controle_materiais
```

## 🗄️ Estrutura do banco

O banco é inicializado automaticamente com:
- Tabelas: usuarios, setores, salas, materiais, conferencias
- Dados de exemplo (setores, salas, usuário admin)
- Índices otimizados para performance

## ⚠️ Notas importantes

1. **Backend em desenvolvimento**: O backend atualmente é um placeholder. Os endpoints da API precisam ser implementados.

2. **Dados mocados**: O frontend usa dados mockados. Quando o backend estiver pronto, as conexões estão comentadas no código.

3. **Volumes persistentes**: Os dados do banco são persistidos em volumes Docker.

4. **Desenvolvimento**: Para desenvolvimento, monte o volume do código fonte para hot-reload automático.

## 🔗 Endpoints da API (TODO)

Quando implementado, o backend terá os seguintes endpoints:

```
POST /api/auth/login
GET  /api/materials
POST /api/materials
PUT  /api/materials/:id
DELETE /api/materials/:id
POST /api/materials/conferir
GET  /api/setores
GET  /api/qr-codes/generate/:materialId
```

## 🐛 Troubleshooting

**Porta 3000 em uso:**
```bash
# Parar processos na porta
lsof -ti:3000 | xargs kill -9
# Ou mudar a porta no docker-compose.yml
```

**Problemas de permissão:**
```bash
# Linux/Mac
sudo chown -R $USER:$USER .
```

**Limpar tudo e recomeçar:**
```bash
docker-compose down -v
docker system prune -a
docker-compose up -d
```