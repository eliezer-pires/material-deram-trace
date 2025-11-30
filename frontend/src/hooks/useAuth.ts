import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { User } from '@/types/material';

interface AuthState {
  user: User | null;
  isAuthenticated: boolean;
  login: (credentials: { login: string; senha: string }) => Promise<boolean>;
  logout: () => void;
}

export const useAuth = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      isAuthenticated: false,
      
      login: async (credentials) => {
        // TODO: Conectar com backend/banco de dados
        // API: POST /api/auth/login
        // Endpoint: http://localhost:3001/api/auth/login
        
        // Mock login - substituir por chamada real da API
        if (credentials.login === 'admin' && credentials.senha === '123456') {
          const user: User = {
            id: '1',
            login: 'admin',
            nome: 'Administrador',
            tipo: 'admin'
          };
          
          set({ user, isAuthenticated: true });
          return true;
        }
        
        return false;
      },
      
      logout: () => {
        set({ user: null, isAuthenticated: false });
      }
    }),
    {
      name: 'auth-storage',
    }
  )
);