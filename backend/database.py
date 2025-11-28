"""
database.py - Configuração da conexão com PostgreSQL

SQLAlchemy Engine & Session Management

Conceitos importantes:
- Engine: Conexão com o banco (pool de conexões)
- SessionLocal: Factory para criar sessões
- Base: Classe base para todos os models
- get_db(): Dependency injection para FastAPI
"""

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os

# ==============================================================================
# CONFIGURAÇÃO DO BANCO DE DADOS
# ==============================================================================

"""
DATABASE_URL: String de conexão PostgreSQL

Formato: postgresql://usuario:senha@host:porta/nome_banco

Componentes:
- usuario: Usuário do PostgreSQL (padrão: postgres)
- senha: Senha do usuário (padrão: postgres)
- host: Endereço do servidor (localhost ou nome do container Docker)
- porta: Porta do PostgreSQL (padrão: 5432)
- nome_banco: Nome do banco de dados (material_control)

IMPORTANTE EM PRODUÇÃO:
- Use variáveis de ambiente (nunca hardcode credenciais!)
- Use secrets management (AWS Secrets Manager, Vault, etc)
- Use SSL/TLS para conexões externas
"""

# Tenta ler de variável de ambiente, senão usa valores padrão para desenvolvimento
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    # ⚠️ ATENÇÃO: No Docker Compose, o host é o nome do serviço (db)
    # ⚠️ Localmente (sem Docker), o host seria "localhost"
    "postgresql://postgres:postgres@db:5432/material_control"
    # Para rodar FORA do Docker, use:
    # "postgresql://postgres:postgres@localhost:5432/material_control"
)

# ==============================================================================
# ENGINE - CONEXÃO COM O BANCO
# ==============================================================================

"""
create_engine: Cria o pool de conexões

Parâmetros importantes:

1. pool_pre_ping=True
   - Testa conexão antes de usar
   - Previne erros de conexão perdida
   - Pequeno overhead, mas MUITO útil

2. pool_size=5
   - Número de conexões mantidas no pool
   - Para ambientes pequenos: 5-10 é suficiente
   - Para produção alta carga: 20-50

3. max_overflow=10
   - Conexões extras além do pool_size
   - Total máximo: pool_size + max_overflow = 15 conexões
   - Ajuste conforme carga esperada

4. pool_recycle=3600
   - Recicla conexões a cada hora (3600 segundos)
   - Previne "MySQL has gone away" / "connection closed"
   - PostgreSQL é mais robusto, mas não custa nada

Por que pool de conexões?
- Criar conexão é CARO (100-200ms)
- Reusar conexões é RÁPIDO (< 1ms)
- Controla carga no banco (evita sobrecarga)
"""

engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,      # Testa conexão antes de usar
    pool_size=5,             # 5 conexões no pool
    max_overflow=10,         # Até 10 conexões extras
    pool_recycle=3600,       # Recicla conexões a cada hora
    echo=False               # True para debug SQL (muito verbose!)
)

# ==============================================================================
# SESSION FACTORY
# ==============================================================================

"""
SessionLocal: Factory para criar sessões do banco

Parâmetros:

1. autocommit=False
   - Transações explícitas (você controla quando commitar)
   - Previne commits acidentais
   - ACID compliance

2. autoflush=False
   - Não envia automaticamente para o banco
   - Mais controle sobre quando fazer flush
   - Performance (menos roundtrips)

3. bind=engine
   - Vincula à engine criada acima

Por que usar sessions?
- Isolamento de transações
- Controle de commit/rollback
- Unit of Work pattern
- Garante consistência dos dados
"""

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

# ==============================================================================
# BASE CLASS PARA MODELS
# ==============================================================================

"""
Base: Classe base para todos os models SQLAlchemy

Todos os models herdam desta classe:
- class User(Base): ...
- class Material(Base): ...

Ela fornece:
- Metadata (informações sobre tabelas)
- __tablename__ automático (opcional)
- Métodos auxiliares
"""

Base = declarative_base()

# ==============================================================================
# DEPENDENCY INJECTION - GET_DB
# ==============================================================================

"""
get_db(): Generator function para FastAPI Dependency Injection

Como funciona:

1. FastAPI chama get_db()
2. Cria uma sessão (db = SessionLocal())
3. Injeta a sessão na rota
4. Executa a lógica da rota
5. Fecha a sessão (finally: db.close())

Vantagens:
- Garante que sessão SEMPRE será fechada
- Evita connection leaks
- Código limpo (DRY - Don't Repeat Yourself)
- Fácil de testar (pode mockar get_db)

Exemplo de uso:
@app.get("/materiais")
def listar_materiais(db: Session = Depends(get_db)):
    return db.query(Material).all()
"""

def get_db():
    """
    Cria e fornece uma sessão do banco de dados
    
    Uso com FastAPI Dependency Injection:
    db: Session = Depends(get_db)
    
    Garante que a sessão será sempre fechada,
    mesmo se ocorrer exception
    """
    db = SessionLocal()
    try:
        yield db  # Fornece a sessão para a rota
    finally:
        db.close()  # SEMPRE fecha a sessão


# ==============================================================================
# FUNÇÕES AUXILIARES PARA DEVOPS/SRE
# ==============================================================================

def init_db():
    """
    Inicializa o banco de dados (cria todas as tabelas)
    
    Uso:
    - Scripts de deployment
    - Testes automatizados
    - Ambiente de desenvolvimento
    
    ⚠️ NÃO use em produção com dados!
    Use migrations (Alembic) para produção
    """
    Base.metadata.create_all(bind=engine)
    print("✅ Banco de dados inicializado!")


def drop_all_tables():
    """
    CUIDADO: Deleta TODAS as tabelas!
    
    Uso apenas para:
    - Desenvolvimento local
    - Testes automatizados
    - Reset completo do ambiente
    
    ⚠️ NUNCA use em produção!
    """
    Base.metadata.drop_all(bind=engine)
    print("⚠️ Todas as tabelas foram deletadas!")


def check_connection():
    """
    Verifica se a conexão com o banco está OK
    
    Útil para:
    - Health checks
    - Scripts de deployment
    - Troubleshooting
    """
    try:
        engine.connect()
        print("✅ Conexão com banco OK!")
        return True
    except Exception as e:
        print(f"❌ Erro na conexão: {e}")
        return False


# ==============================================================================
# MIGRATIONS COM ALEMBIC (PARA PRODUÇÃO)
# ==============================================================================

"""
Para PRODUÇÃO, use Alembic para migrations:

1. Instalar Alembic:
   pip install alembic

2. Inicializar:
   alembic init alembic

3. Configurar alembic.ini:
   sqlalchemy.url = postgresql://user:pass@host/db

4. Criar migration:
   alembic revision --autogenerate -m "Initial migration"

5. Aplicar migration:
   alembic upgrade head

Vantagens do Alembic:
- Versionamento do schema
- Rollback de mudanças
- Histórico completo
- Zero downtime deployments
- Review de mudanças no Git

Migrations são ESSENCIAIS em produção!
"""

# ==============================================================================
# MONITORAMENTO E MÉTRICAS (PARA SRE)
# ==============================================================================

"""
Para ambientes de produção, adicione:

1. Logging de queries lentas:
   from sqlalchemy import event
   
   @event.listens_for(Engine, "before_cursor_execute")
   def receive_before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
       conn.info.setdefault('query_start_time', []).append(time.time())
   
   @event.listens_for(Engine, "after_cursor_execute")
   def receive_after_cursor_execute(conn, cursor, statement, parameters, context, executemany):
       total = time.time() - conn.info['query_start_time'].pop(-1)
       if total > 1.0:  # Queries > 1 segundo
           logger.warning(f"Slow query ({total:.2f}s): {statement}")

2. Prometheus metrics:
   from prometheus_client import Counter, Histogram
   
   db_query_duration = Histogram('db_query_duration_seconds', 'Database query duration')
   db_query_total = Counter('db_query_total', 'Total database queries')

3. Connection pool monitoring:
   engine.pool.size()       # Conexões no pool
   engine.pool.checked_in() # Conexões disponíveis
   engine.pool.overflow()   # Conexões extras
   
Implemente quando necessário para observabilidade!
"""