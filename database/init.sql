-- Banco de Dados: Sistema de Controle de Materiais
-- PostgreSQL Schema Initialization

-- Criação das tabelas principais
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Tabela de usuários
CREATE TABLE usuarios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    login VARCHAR(50) UNIQUE NOT NULL,
    senha_hash VARCHAR(255) NOT NULL,
    nome VARCHAR(100) NOT NULL,
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('admin', 'operador')),
    ativo BOOLEAN DEFAULT true,
    data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de setores
CREATE TABLE setores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome VARCHAR(100) NOT NULL UNIQUE,
    descricao TEXT,
    ativo BOOLEAN DEFAULT true,
    data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de salas
CREATE TABLE salas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome VARCHAR(100) NOT NULL,
    setor_id UUID NOT NULL REFERENCES setores(id),
    descricao TEXT,
    ativo BOOLEAN DEFAULT true,
    data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(nome, setor_id)
);

-- Tabela de materiais
CREATE TABLE materiais (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome VARCHAR(200) NOT NULL,
    bmp VARCHAR(50) UNIQUE NOT NULL,
    setor_id UUID NOT NULL REFERENCES setores(id),
    sala_id UUID NOT NULL REFERENCES salas(id),
    responsavel VARCHAR(100) NOT NULL,
    qr_code VARCHAR(255) UNIQUE NOT NULL,
    status VARCHAR(30) DEFAULT 'nao_conferido' CHECK (status IN ('nao_conferido', 'conferido_correto', 'conferido_outro_setor')),
    observacoes TEXT,
    data_cadastro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de conferências
CREATE TABLE conferencias (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    material_id UUID NOT NULL REFERENCES materiais(id),
    usuario_id UUID NOT NULL REFERENCES usuarios(id),
    setor_encontrado_id UUID NOT NULL REFERENCES setores(id),
    sala_encontrada_id UUID NOT NULL REFERENCES salas(id),
    data_conferencia TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    observacoes TEXT
);

-- Tabela de sessões de conferência
CREATE TABLE sessoes_conferencia (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id),
    setor_id UUID NOT NULL REFERENCES setores(id),
    sala_id UUID NOT NULL REFERENCES salas(id),
    data_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_fim TIMESTAMP,
    total_materiais_conferidos INTEGER DEFAULT 0
);

-- Índices para otimização
CREATE INDEX idx_materiais_qr_code ON materiais(qr_code);
CREATE INDEX idx_materiais_status ON materiais(status);
CREATE INDEX idx_conferencias_data ON conferencias(data_conferencia);
CREATE INDEX idx_conferencias_material ON conferencias(material_id);

-- Inserção de dados iniciais
INSERT INTO usuarios (login, senha_hash, nome, tipo) VALUES 
('admin', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Administrador', 'admin');
-- Senha hash para: 123456

INSERT INTO setores (nome, descricao) VALUES 
('Administração', 'Setor administrativo da empresa'),
('Produção', 'Área de produção e manufatura'),
('TI', 'Tecnologia da Informação'),
('RH', 'Recursos Humanos');

INSERT INTO salas (nome, setor_id, descricao) VALUES 
('Sala 101', (SELECT id FROM setores WHERE nome = 'Administração'), 'Sala da diretoria'),
('Sala 102', (SELECT id FROM setores WHERE nome = 'Administração'), 'Sala de reuniões'),
('Recepção', (SELECT id FROM setores WHERE nome = 'Administração'), 'Área de recepção'),
('Linha 1', (SELECT id FROM setores WHERE nome = 'Produção'), 'Linha de produção 1'),
('Linha 2', (SELECT id FROM setores WHERE nome = 'Produção'), 'Linha de produção 2'),
('Estoque', (SELECT id FROM setores WHERE nome = 'Produção'), 'Área de estoque'),
('Sala Servidores', (SELECT id FROM setores WHERE nome = 'TI'), 'Data center'),
('Sala Técnica', (SELECT id FROM setores WHERE nome = 'TI'), 'Suporte técnico'),
('Escritório TI', (SELECT id FROM setores WHERE nome = 'TI'), 'Desenvolvimento'),
('Sala RH', (SELECT id FROM setores WHERE nome = 'RH'), 'Departamento de RH'),
('Sala Reunião', (SELECT id FROM setores WHERE nome = 'RH'), 'Sala de reuniões RH'),
('Arquivo', (SELECT id FROM setores WHERE nome = 'RH'), 'Arquivo de documentos');

-- Triggers para atualização automática de timestamps
CREATE OR REPLACE FUNCTION update_data_atualizacao()
RETURNS TRIGGER AS $$
BEGIN
    NEW.data_atualizacao = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_materiais
    BEFORE UPDATE ON materiais
    FOR EACH ROW
    EXECUTE FUNCTION update_data_atualizacao();

CREATE TRIGGER trigger_update_usuarios
    BEFORE UPDATE ON usuarios
    FOR EACH ROW
    EXECUTE FUNCTION update_data_atualizacao();