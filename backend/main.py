
from fastapi import FastAPI, Depends, HTTPException, status, File, UploadFile
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from typing import List, Optional
import io
import qrcode
import hashlib
from datetime import datetime, timedelta
import jwt
from passlib.context import CryptContext

# Importações dos nossos módulos (criaremos depois)
from database import get_db, engine
import models
import schemas

# Criar todas as tabelas no banco de dados
models.Base.metadata.create_all(bind=engine)

# ==============================================================================
# CONFIGURAÇÕES DA API
# ==============================================================================

app = FastAPI(
    title="Sistema de Controle de Materiais",
    description="API para gerenciamento de materiais com QR Code",
    version="1.0.0",
    docs_url="/docs",  # Swagger UI
    redoc_url="/redoc"  # ReDoc
)

# CORS - Permitir que o frontend React acesse a API
# Em produção, substitua "*" pelo domínio específico do frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Frontend React (ajuste conforme necessário)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==============================================================================
# CONFIGURAÇÕES DE SEGURANÇA
# ==============================================================================

# Secret key para JWT (EM PRODUÇÃO, USE VARIÁVEL DE AMBIENTE!)
SECRET_KEY = "sua-chave-secreta-super-segura-aqui-123456"  # MUDE ISSO!
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 480  # 8 horas

# Context para hash de senhas
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# ==============================================================================
# FUNÇÕES AUXILIARES DE AUTENTICAÇÃO
# ==============================================================================

def verify_password(plain_password, hashed_password):
    """Verifica se a senha está correta"""
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    """Gera hash da senha"""
    return pwd_context.hash(password)

def create_access_token(data: dict):
    """Cria token JWT"""
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    """Obtém usuário atual do token JWT"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Credenciais inválidas",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise credentials_exception
    except jwt.PyJWTError:
        raise credentials_exception
    
    user = db.query(models.User).filter(models.User.username == username).first()
    if user is None:
        raise credentials_exception
    return user

def generate_qr_hash(material_id: int, nome: str) -> str:
    """Gera hash único para QR Code baseado no ID e nome do material"""
    data = f"{material_id}-{nome}-{datetime.utcnow().timestamp()}"
    return hashlib.sha256(data.encode()).hexdigest()[:16]

# ==============================================================================
# ROTAS DE AUTENTICAÇÃO
# ==============================================================================

@app.post("/token", tags=["Autenticação"])
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """
    Login do usuário
    
    Credenciais padrão:
    - username: admin
    - password: 123456
    """
    user = db.query(models.User).filter(models.User.username == form_data.username).first()
    
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuário ou senha incorretos",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token = create_access_token(data={"sub": user.username})
    return {"access_token": access_token, "token_type": "bearer", "role": user.role}

@app.get("/users/me", response_model=schemas.User, tags=["Autenticação"])
async def read_users_me(current_user: models.User = Depends(get_current_user)):
    """Retorna dados do usuário logado"""
    return current_user

# ==============================================================================
# ROTAS DE MATERIAIS
# ==============================================================================

@app.post("/materiais", response_model=schemas.Material, tags=["Materiais"])
async def criar_material(
    material: schemas.MaterialCreate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Cria um novo material e gera QR Code automaticamente
    
    Campos obrigatórios:
    - nome: Nome do material
    - bmp: Código BMP
    - setor: Setor onde está localizado
    - sala: Sala onde está localizado
    - responsavel: Nome do responsável
    """
    # Criar material no banco
    db_material = models.Material(**material.dict())
    db.add(db_material)
    db.flush()  # Para obter o ID antes do commit
    
    # Gerar hash único para QR Code
    db_material.qr_hash = generate_qr_hash(db_material.id, db_material.nome)
    
    db.commit()
    db.refresh(db_material)
    return db_material

@app.get("/materiais", response_model=List[schemas.Material], tags=["Materiais"])
async def listar_materiais(
    skip: int = 0,
    limit: int = 100,
    setor: Optional[str] = None,
    sala: Optional[str] = None,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Lista todos os materiais com filtros opcionais
    
    Parâmetros:
    - skip: Número de registros para pular (paginação)
    - limit: Número máximo de registros a retornar
    - setor: Filtrar por setor específico
    - sala: Filtrar por sala específica
    """
    query = db.query(models.Material)
    
    if setor:
        query = query.filter(models.Material.setor == setor)
    if sala:
        query = query.filter(models.Material.sala == sala)
    
    materiais = query.offset(skip).limit(limit).all()
    return materiais

@app.get("/materiais/{material_id}", response_model=schemas.Material, tags=["Materiais"])
async def obter_material(
    material_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Obtém um material específico por ID"""
    material = db.query(models.Material).filter(models.Material.id == material_id).first()
    if not material:
        raise HTTPException(status_code=404, detail="Material não encontrado")
    return material

@app.put("/materiais/{material_id}", response_model=schemas.Material, tags=["Materiais"])
async def atualizar_material(
    material_id: int,
    material: schemas.MaterialUpdate,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Atualiza informações de um material
    
    Permite alterar: setor, sala, responsável, BMP
    """
    db_material = db.query(models.Material).filter(models.Material.id == material_id).first()
    if not db_material:
        raise HTTPException(status_code=404, detail="Material não encontrado")
    
    # Atualizar apenas campos fornecidos
    for key, value in material.dict(exclude_unset=True).items():
        setattr(db_material, key, value)
    
    db.commit()
    db.refresh(db_material)
    return db_material

@app.delete("/materiais/{material_id}", tags=["Materiais"])
async def deletar_material(
    material_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Deleta um material (apenas para admin)
    """
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Apenas administradores podem deletar materiais")
    
    db_material = db.query(models.Material).filter(models.Material.id == material_id).first()
    if not db_material:
        raise HTTPException(status_code=404, detail="Material não encontrado")
    
    db.delete(db_material)
    db.commit()
    return {"message": "Material deletado com sucesso"}

# ==============================================================================
# ROTAS DE QR CODE
# ==============================================================================

@app.get("/materiais/{material_id}/qrcode", tags=["QR Code"])
async def gerar_qrcode(
    material_id: int,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Gera imagem PNG do QR Code para um material específico
    
    O QR Code contém o hash único do material
    """
    material = db.query(models.Material).filter(models.Material.id == material_id).first()
    if not material:
        raise HTTPException(status_code=404, detail="Material não encontrado")
    
    # Gerar QR Code
    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data(material.qr_hash)
    qr.make(fit=True)
    
    img = qr.make_image(fill_color="black", back_color="white")
    
    # Converter para bytes
    img_byte_arr = io.BytesIO()
    img.save(img_byte_arr, format='PNG')
    img_byte_arr.seek(0)
    
    return StreamingResponse(img_byte_arr, media_type="image/png")

@app.post("/conferencia/scan", tags=["Conferência"])
async def scan_qrcode(
    scan_data: schemas.ScanQRCode,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Registra leitura de QR Code durante conferência
    
    Atualiza localização do material se necessário
    """
    # Buscar material pelo hash do QR Code
    material = db.query(models.Material).filter(models.Material.qr_hash == scan_data.qr_hash).first()
    if not material:
        raise HTTPException(status_code=404, detail="Material não encontrado")
    
    # Atualizar localização onde foi lido
    material.setor = scan_data.setor
    material.sala = scan_data.sala
    material.ultima_conferencia = datetime.utcnow()
    material.conferido = True
    
    db.commit()
    db.refresh(material)
    
    return {
        "message": "Conferência registrada com sucesso",
        "material": material
    }

# ==============================================================================
# ROTAS DE SETORES/SALAS
# ==============================================================================

@app.get("/setores", tags=["Setores"])
async def listar_setores(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Lista todos os setores únicos cadastrados"""
    setores = db.query(models.Material.setor).distinct().all()
    return [s[0] for s in setores if s[0]]

@app.get("/setores/{setor}/salas", tags=["Setores"])
async def listar_salas_por_setor(
    setor: str,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Lista todas as salas de um setor específico"""
    salas = db.query(models.Material.sala).filter(
        models.Material.setor == setor
    ).distinct().all()
    return [s[0] for s in salas if s[0]]

@app.get("/setores/{setor}/salas/{sala}/materiais", response_model=List[schemas.Material], tags=["Setores"])
async def listar_materiais_por_local(
    setor: str,
    sala: str,
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Lista todos os materiais de um setor e sala específicos"""
    materiais = db.query(models.Material).filter(
        models.Material.setor == setor,
        models.Material.sala == sala
    ).all()
    return materiais

# ==============================================================================
# ROTAS DE DASHBOARD/ESTATÍSTICAS
# ==============================================================================

@app.get("/dashboard/stats", tags=["Dashboard"])
async def obter_estatisticas(
    current_user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Retorna estatísticas gerais do sistema
    """
    total_materiais = db.query(models.Material).count()
    materiais_conferidos = db.query(models.Material).filter(models.Material.conferido == True).count()
    total_setores = db.query(models.Material.setor).distinct().count()
    
    return {
        "total_materiais": total_materiais,
        "materiais_conferidos": materiais_conferidos,
        "materiais_nao_conferidos": total_materiais - materiais_conferidos,
        "total_setores": total_setores,
        "taxa_conferencia": round((materiais_conferidos / total_materiais * 100) if total_materiais > 0 else 0, 2)
    }

# ==============================================================================
# ROTA DE HEALTH CHECK
# ==============================================================================

@app.get("/health", tags=["Sistema"])
async def health_check():
    """
    Health check para monitoramento (Prometheus, Kubernetes, etc)
    """
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0.0"
    }

# ==============================================================================
# ROTA RAIZ
# ==============================================================================

@app.get("/", tags=["Sistema"])
async def root():
    """Rota raiz - informações da API"""
    return {
        "message": "API Sistema de Controle de Materiais",
        "docs": "/docs",
        "redoc": "/redoc",
        "version": "1.0.0"
    }

# ==============================================================================
# INICIALIZAÇÃO DO BANCO (criar usuário admin)
# ==============================================================================

@app.on_event("startup")
async def startup_event():
    """Cria usuário admin padrão se não existir"""
    db = next(get_db())
    
    # Verificar se admin já existe
    admin = db.query(models.User).filter(models.User.username == "admin").first()
    
    if not admin:
        # Criar admin padrão
        admin_user = models.User(
            username="admin",
            hashed_password=get_password_hash("123456"),
            role="admin"
        )
        db.add(admin_user)
        db.commit()
        print("✅ Usuário admin criado com sucesso!")
        print("   Username: admin")
        print("   Password: 123456")
    
    db.close()