export interface Material {
  id: string;
  nome: string;
  bmp: string;
  setor: string;
  sala: string;
  responsavel: string;
  qrCode: string;
  status: 'nao_conferido' | 'conferido_correto' | 'conferido_outro_setor';
  ultimaConferencia?: {
    data: string;
    setorEncontrado: string;
    salaEncontrada: string;
  };
  dataCadastro: string;
}

export interface Setor {
  id: string;
  nome: string;
  salas: string[];
}

export interface ConferenciaSession {
  id: string;
  setor: string;
  sala: string;
  usuarioId: string;
  dataInicio: string;
  dataFim?: string;
  materiaisConferidos: string[];
}

export interface User {
  id: string;
  login: string;
  nome: string;
  tipo: 'admin' | 'operador';
}