"""
models.py - Definição das tabelas do banco de dados

SQLAlchemy ORM - Object Relational Mapping
Por que usar ORM?
- Abstração do banco (podemos trocar PostgreSQL por MySQL facilmente)
- Prevenção de SQL Injection (segurança)
- Migrations automáticas
- Type checking
"""

from sqlalchemy import Column, Integer, String, Boolean, DateTime, Text
from sqlalchemy.sql import func
from database import Base

# ==============================================================================
# MODELO: USUÁRIO
# ==============================================================================

class User(Base):
    """
    Tabela de usuários do sistema
    
    Campos:
    - id: Identificador único (chave primária)
    - username: Nome de usuário (único)
    - hashed_password: Senha criptografada (nunca armazenamos senha em texto)
    - role: Papel do usuário (admin, operador, etc)
    - created_at: Data de criação do registro
    """
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    hashed_password = Column(String(255), nullable=False)
    role = Column(String(20), default="operador")  # admin, operador
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    def __repr__(self):
        return f"<User(id={self.id}, username='{self.username}', role='{self.role}')>"


# ==============================================================================
# MODELO: MATERIAL
# ==============================================================================

class Material(Base):
    """
    Tabela de materiais do sistema
    
    Campos principais:
    - id: Identificador único
    - nome: Nome do material
    - bmp: Código BMP (código interno da empresa)
    - setor: Setor onde o material está localizado
    - sala: Sala onde o material está localizado
    - responsavel: Nome do responsável pelo material
    - qr_hash: Hash único gerado para o QR Code (16 caracteres)
    - conferido: Se o material foi conferido (True/False)
    - ultima_conferencia: Data/hora da última conferência
    - created_at: Data de criação do registro
    - updated_at: Data da última atualização
    
    Por que esses campos?
    - qr_hash: Identificador único e curto para QR Code (mais fácil de escanear)
    - conferido: Flag booleana para status rápido (evita queries complexas)
    - timestamps: Auditoria e rastreamento de mudanças
    """
    __tablename__ = "materiais"
    
    # Identificação
    id = Column(Integer, primary_key=True, index=True)
    nome = Column(String(255), nullable=False, index=True)
    bmp = Column(String(100), nullable=False, index=True)
    
    # Localização
    setor = Column(String(100), nullable=False, index=True)
    sala = Column(String(100), nullable=False, index=True)
    responsavel = Column(String(255), nullable=False)
    
    # QR Code
    qr_hash = Column(String(16), unique=True, index=True)  # Hash único de 16 chars
    
    # Status de conferência
    conferido = Column(Boolean, default=False, index=True)
    ultima_conferencia = Column(DateTime(timezone=True), nullable=True)
    
    # Observações (opcional)
    observacoes = Column(Text, nullable=True)
    
    # Timestamps para auditoria
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    def __repr__(self):
        return f"<Material(id={self.id}, nome='{self.nome}', bmp='{self.bmp}', setor='{self.setor}')>"


# ==============================================================================
# ÍNDICES IMPORTANTES
# ==============================================================================
"""
Por que criar índices?

Índices são como "índices de livros" - permitem busca rápida sem varrer toda tabela.

Índices criados automaticamente pelo SQLAlchemy (index=True):
1. users.username - busca de login rápida
2. materiais.nome - busca por nome do material
3. materiais.bmp - busca por código BMP
4. materiais.setor - filtro por setor (usado frequentemente)
5. materiais.sala - filtro por sala (usado frequentemente)
6. materiais.qr_hash - busca por QR Code (CRÍTICO para conferência mobile)
7. materiais.conferido - filtro de materiais conferidos/não conferidos

Trade-off:
✅ Vantagens: Queries 10-100x mais rápidas
❌ Desvantagens: Inserts/Updates um pouco mais lentos, mais espaço em disco

Para este sistema, vale MUITO a pena!
"""


# ==============================================================================
# MODELO FUTURO: HISTÓRICO DE CONFERÊNCIAS (opcional)
# ==============================================================================
"""
Para implementação futura, podemos adicionar uma tabela de histórico:

class ConferenciaHistorico(Base):
    __tablename__ = "conferencias_historico"
    
    id = Column(Integer, primary_key=True)
    material_id = Column(Integer, ForeignKey("materiais.id"))
    usuario_id = Column(Integer, ForeignKey("users.id"))
    setor_anterior = Column(String(100))
    sala_anterior = Column(String(100))
    setor_novo = Column(String(100))
    sala_novo = Column(String(100))
    timestamp = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relacionamentos
    material = relationship("Material")
    usuario = relationship("User")

Vantagens:
- Auditoria completa (quem moveu o quê e quando)
- Rastreamento de movimentações
- Relatórios de atividade
- Compliance

Implemente quando necessário!
"""