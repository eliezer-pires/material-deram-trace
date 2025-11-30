import { create } from 'zustand';
import { Material, Setor } from '@/types/material';

interface MaterialsState {
  materials: Material[];
  setores: Setor[];
  loading: boolean;
  addMaterial: (material: Omit<Material, 'id' | 'qrCode' | 'dataCadastro'>) => void;
  updateMaterial: (id: string, updates: Partial<Material>) => void;
  deleteMaterial: (id: string) => void;
  conferirMaterial: (qrCode: string, setor: string, sala: string) => void;
  fetchMaterials: () => Promise<void>;
}

// Mock data para demonstração
const mockSetores: Setor[] = [
  { id: '1', nome: 'Administração', salas: ['Sala 101', 'Sala 102', 'Recepção'] },
  { id: '2', nome: 'Produção', salas: ['Linha 1', 'Linha 2', 'Estoque'] },
  { id: '3', nome: 'TI', salas: ['Sala Servidores', 'Sala Técnica', 'Escritório TI'] },
  { id: '4', nome: 'RH', salas: ['Sala RH', 'Sala Reunião', 'Arquivo'] }
];

const mockMaterials: Material[] = [
  {
    id: '1',
    nome: 'Computador Desktop Dell',
    bmp: 'BMP001',
    setor: 'TI',
    sala: 'Escritório TI',
    responsavel: 'João Silva',
    qrCode: 'QR_001_HASH_ABC123',
    status: 'conferido_correto',
    ultimaConferencia: {
      data: '2024-01-15T10:30:00Z',
      setorEncontrado: 'TI',
      salaEncontrada: 'Escritório TI'
    },
    dataCadastro: '2024-01-01T08:00:00Z'
  },
  {
    id: '2',
    nome: 'Monitor LG 24"',
    bmp: 'BMP002',
    setor: 'Administração',
    sala: 'Sala 101',
    responsavel: 'Maria Santos',
    qrCode: 'QR_002_HASH_DEF456',
    status: 'conferido_outro_setor',
    ultimaConferencia: {
      data: '2024-01-15T11:15:00Z',
      setorEncontrado: 'TI',
      salaEncontrada: 'Sala Técnica'
    },
    dataCadastro: '2024-01-02T09:15:00Z'
  },
  {
    id: '3',
    nome: 'Impressora HP LaserJet',
    bmp: 'BMP003',
    setor: 'RH',
    sala: 'Sala RH',
    responsavel: 'Carlos Oliveira',
    qrCode: 'QR_003_HASH_GHI789',
    status: 'nao_conferido',
    dataCadastro: '2024-01-03T14:20:00Z'
  }
];

export const useMaterials = create<MaterialsState>((set, get) => ({
  materials: mockMaterials,
  setores: mockSetores,
  loading: false,

  addMaterial: (materialData) => {
    // TODO: Conectar com backend/banco de dados
    // API: POST /api/materials
    // Endpoint: http://localhost:3001/api/materials
    
    const newMaterial: Material = {
      ...materialData,
      id: Date.now().toString(),
      qrCode: `QR_${Date.now()}_HASH_${Math.random().toString(36).substr(2, 6).toUpperCase()}`,
      status: 'nao_conferido',
      dataCadastro: new Date().toISOString()
    };
    
    set((state) => ({
      materials: [...state.materials, newMaterial]
    }));
  },

  updateMaterial: (id, updates) => {
    // TODO: Conectar com backend/banco de dados
    // API: PUT /api/materials/:id
    // Endpoint: http://localhost:3001/api/materials/${id}
    
    set((state) => ({
      materials: state.materials.map(material =>
        material.id === id ? { ...material, ...updates } : material
      )
    }));
  },

  deleteMaterial: (id) => {
    // TODO: Conectar com backend/banco de dados
    // API: DELETE /api/materials/:id
    // Endpoint: http://localhost:3001/api/materials/${id}
    
    set((state) => ({
      materials: state.materials.filter(material => material.id !== id)
    }));
  },

  conferirMaterial: (qrCode, setor, sala) => {
    // TODO: Conectar com backend/banco de dados
    // API: POST /api/materials/conferir
    // Endpoint: http://localhost:3001/api/materials/conferir
    
    const material = get().materials.find(m => m.qrCode === qrCode);
    if (!material) return;

    const isCorrectLocation = material.setor === setor && material.sala === sala;
    const status = isCorrectLocation ? 'conferido_correto' : 'conferido_outro_setor';

    set((state) => ({
      materials: state.materials.map(m =>
        m.qrCode === qrCode
          ? {
              ...m,
              status,
              ultimaConferencia: {
                data: new Date().toISOString(),
                setorEncontrado: setor,
                salaEncontrada: sala
              }
            }
          : m
      )
    }));
  },

  fetchMaterials: async () => {
    // TODO: Conectar com backend/banco de dados
    // API: GET /api/materials
    // Endpoint: http://localhost:3001/api/materials
    
    set({ loading: true });
    
    // Simular delay da API
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Mock data já está carregada no estado inicial
    set({ loading: false });
  }
}));