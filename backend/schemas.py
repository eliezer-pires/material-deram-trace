"""
schemas.py - Validação e serialização de dados com Pydantic

Por que Pydantic?
- Validação automática de tipos
- Documentação automática na API (Swagger)
- Conversão de tipos automática
- Mensagens de erro claras
- Performance (escrito em Rust/Cython)

Diferença entre Models e Schemas:
- Models (SQLAlchemy): Representam TABELAS do banco de dados
- Schemas (Pydantic): Representam DADOS que trafegam na API (JSON)
"""

from pydantic import BaseModel, Field, validator
from typing import Optional
from datetime import datetime

# ==============================================================================
# SCHEMAS DE USUÁRIO
# ==============================================================================

class UserBase(BaseModel):
    """Schema base de usuário (campos comuns)"""
    username: str = Field(..., min_length=3, max_length=50, description="Nome de usuário único")
    role: str = Field(default="operador", description="Papel: admin ou operador")

class UserCreate(UserBase):
    """Schema para CRIAR usuário (inclui senha)"""
    password: str = Field(..., min_length=6, description="Senha (mínimo 6 caracteres)")

class User(UserBase):
    """
    Schema para RETORNAR usuário (resposta da API)
    
    Importante: NÃO incluímos hashed_password aqui!
    Nunca exponha senhas (mesmo criptografadas) via API
    """
    id: int
    created_at: datetime
    
    class Config:
        # Permite conversão de ORM model para Pydantic
        orm_mode = True


# ==============================================================================
# SCHEMAS DE MATERIAL
# ==============================================================================

class MaterialBase(BaseModel):
    """
    Schema base de material (campos comuns)
    
    Validações importantes:
    - Campos obrigatórios: nome, bmp, setor, sala, responsavel
    - Comprimento mínimo para evitar dados inválidos
    """
    nome: str = Field(..., min_length=3, max_length=255, description="Nome do material")
    bmp: str = Field(..., min_length=1, max_length=100, description="Código BMP")
    setor: str = Field(..., min_length=2, max_length=100, description="Setor onde está localizado")
    sala: str = Field(..., min_length=1, max_length=100, description="Sala onde está localizado")
    responsavel: str = Field(..., min_length=3, max_length=255, description="Nome do responsável")
    observacoes: Optional[str] = Field(None, description="Observações adicionais")
    
    @validator('nome', 'responsavel')
    def validate_not_empty(cls, v):
        """Validador customizado: não permite strings vazias ou só espaços"""
        if v and not v.strip():
            raise ValueError('Campo não pode ser vazio')
        return v.strip() if v else v
    
    @validator('setor', 'sala')
    def normalize_location(cls, v):
        """Normaliza localização: remove espaços extras, capitaliza"""
        if v:
            return v.strip().title()  # "sala 1" -> "Sala 1"
        return v


class MaterialCreate(MaterialBase):
    """
    Schema para CRIAR material
    
    Nota: qr_hash é gerado automaticamente pelo backend,
    então não precisa estar aqui
    """
    pass


class MaterialUpdate(BaseModel):
    """
    Schema para ATUALIZAR material
    
    Todos os campos são opcionais (Optional)
    Por quê? Permite atualização parcial (PATCH)
    
    Exemplo: Atualizar apenas o setor sem mexer em outros campos
    """
    nome: Optional[str] = Field(None, min_length=3, max_length=255)
    bmp: Optional[str] = Field(None, min_length=1, max_length=100)
    setor: Optional[str] = Field(None, min_length=2, max_length=100)
    sala: Optional[str] = Field(None, min_length=1, max_length=100)
    responsavel: Optional[str] = Field(None, min_length=3, max_length=255)
    observacoes: Optional[str] = None
    
    @validator('*', pre=True)
    def empty_str_to_none(cls, v):
        """Converte strings vazias para None"""
        if v == '':
            return None
        return v


class Material(MaterialBase):
    """
    Schema para RETORNAR material (resposta da API)
    
    Inclui todos os campos do banco, inclusive os gerados automaticamente:
    - id: Gerado pelo banco
    - qr_hash: Gerado pelo backend
    - conferido: Status de conferência
    - timestamps: Datas de criação/atualização
    """
    id: int
    qr_hash: Optional[str] = Field(None, description="Hash único do QR Code")
    conferido: bool = Field(default=False, description="Se foi conferido")
    ultima_conferencia: Optional[datetime] = Field(None, description="Data da última conferência")
    created_at: datetime = Field(..., description="Data de criação")
    updated_at: Optional[datetime] = Field(None, description="Data de atualização")
    
    class Config:
        orm_mode = True  # Permite conversão de SQLAlchemy model


# ==============================================================================
# SCHEMAS DE CONFERÊNCIA (QR CODE SCAN)
# ==============================================================================

class ScanQRCode(BaseModel):
    """
    Schema para registrar scan de QR Code
    
    Fluxo:
    1. Mobile lê QR Code (obtém qr_hash)
    2. Usuário já selecionou setor e sala no app
    3. Envia para API: qr_hash + setor + sala
    4. API atualiza localização do material
    """
    qr_hash: str = Field(..., min_length=16, max_length=16, description="Hash do QR Code lido")
    setor: str = Field(..., min_length=2, max_length=100, description="Setor da conferência")
    sala: str = Field(..., min_length=1, max_length=100, description="Sala da conferência")
    
    @validator('qr_hash')
    def validate_hash_format(cls, v):
        """Valida formato do hash (16 caracteres hexadecimais)"""
        if not all(c in '0123456789abcdef' for c in v.lower()):
            raise ValueError('Hash deve conter apenas caracteres hexadecimais')
        return v.lower()


# ==============================================================================
# SCHEMAS DE RESPOSTA
# ==============================================================================

class MessageResponse(BaseModel):
    """Schema genérico para respostas de sucesso"""
    message: str
    detail: Optional[dict] = None


class DashboardStats(BaseModel):
    """
    Schema para estatísticas do dashboard
    
    Métricas importantes para gestão:
    - Total de materiais cadastrados
    - Quantos foram conferidos
    - Taxa de conferência (%)
    - Número de setores
    """
    total_materiais: int = Field(..., description="Total de materiais cadastrados")
    materiais_conferidos: int = Field(..., description="Materiais já conferidos")
    materiais_nao_conferidos: int = Field(..., description="Materiais não conferidos")
    total_setores: int = Field(..., description="Número de setores únicos")
    taxa_conferencia: float = Field(..., description="Taxa de conferência (%)")


# ==============================================================================
# SCHEMAS PARA EXPORTAÇÃO
# ==============================================================================

class MaterialExport(BaseModel):
    """
    Schema simplificado para exportação Excel
    
    Contém apenas campos essenciais para impressão
    """
    nome: str
    bmp: str
    setor: str
    sala: str
    responsavel: str
    qr_hash: str
    conferido: bool
    
    class Config:
        orm_mode = True


# ==============================================================================
# OBSERVAÇÕES SOBRE DESIGN
# ==============================================================================
"""
Por que separar Create/Update/Response schemas?

1. SEGURANÇA
   - User vs UserCreate: não exponha senhas
   - Material: não permite alterar qr_hash diretamente

2. FLEXIBILIDADE
   - MaterialUpdate: campos opcionais (PATCH)
   - MaterialCreate: campos obrigatórios (POST)

3. CLAREZA
   - Cada schema tem propósito específico
   - Documentação automática fica mais clara
   - Validações diferentes para cada operação

4. VALIDAÇÃO
   - Validators customizados por operação
   - Normalização de dados (strip, title)
   - Conversão de tipos automática

5. VERSIONAMENTO
   - Fácil adicionar schemas v2 sem quebrar v1
   - Deprecar campos gradualmente
   
Este padrão é considerado BEST PRACTICE em FastAPI!
"""