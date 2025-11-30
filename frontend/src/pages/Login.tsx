import { useState } from "react";
import { Navigate } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Layout } from "@/components/ui/layout";
import { useAuth } from "@/hooks/useAuth";
import { useToast } from "@/hooks/use-toast";
import { Package, Lock, User } from "lucide-react";

export default function Login() {
  const [credentials, setCredentials] = useState({ login: "", senha: "" });
  const [loading, setLoading] = useState(false);
  const { login, isAuthenticated } = useAuth();
  const { toast } = useToast();

  if (isAuthenticated) {
    return <Navigate to="/dashboard" replace />;
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      const success = await login(credentials);
      
      if (success) {
        toast({
          title: "Login realizado com sucesso",
          description: "Bem-vindo ao sistema de controle de materiais!",
        });
      } else {
        toast({
          title: "Erro no login",
          description: "Credenciais inválidas. Tente novamente.",
          variant: "destructive",
        });
      }
    } catch (error) {
      toast({
        title: "Erro no sistema",
        description: "Ocorreu um erro inesperado. Tente novamente.",
        variant: "destructive",
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <Layout className="flex items-center justify-center p-4">
      <div className="w-full max-w-md animate-fade-in">
        {/* Logo e Título */}
        <div className="text-center mb-8">
          <div className="flex justify-center mb-4">
            <div className="p-4 rounded-2xl gradient-primary shadow-corporate">
              <Package className="w-12 h-12 text-white" />
            </div>
          </div>
          <h1 className="text-3xl font-bold text-foreground mb-2">
            Sistema de Controle
          </h1>
          <p className="text-muted-foreground">
            Controle de Materiais com QR Code
          </p>
        </div>

        {/* Card de Login */}
        <Card className="shadow-elevated gradient-card border-0">
          <CardHeader className="text-center pb-4">
            <CardTitle className="text-xl font-semibold">
              Acesso ao Sistema
            </CardTitle>
            <CardDescription>
              Entre com suas credenciais para continuar
            </CardDescription>
          </CardHeader>
          
          <CardContent>
            <form onSubmit={handleSubmit} className="space-y-6">
              <div className="space-y-2">
                <Label htmlFor="login" className="text-sm font-medium">
                  Login
                </Label>
                <div className="relative">
                  <User className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
                  <Input
                    id="login"
                    type="text"
                    placeholder="Digite seu login"
                    value={credentials.login}
                    onChange={(e) =>
                      setCredentials({ ...credentials, login: e.target.value })
                    }
                    className="pl-10 h-12"
                    required
                  />
                </div>
              </div>

              <div className="space-y-2">
                <Label htmlFor="senha" className="text-sm font-medium">
                  Senha
                </Label>
                <div className="relative">
                  <Lock className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
                  <Input
                    id="senha"
                    type="password"
                    placeholder="Digite sua senha"
                    value={credentials.senha}
                    onChange={(e) =>
                      setCredentials({ ...credentials, senha: e.target.value })
                    }
                    className="pl-10 h-12"
                    required
                  />
                </div>
              </div>

              <Button
                type="submit"
                className="w-full h-12 gradient-primary text-white font-medium shadow-corporate hover:shadow-elevated transition-all duration-200"
                disabled={loading}
              >
                {loading ? "Entrando..." : "Entrar no Sistema"}
              </Button>
            </form>

            {/* Credenciais de teste */}
            <div className="mt-6 p-4 bg-accent/50 rounded-lg border border-border">
              <p className="text-sm font-medium text-accent-foreground mb-2">
                Credenciais de teste:
              </p>
              <div className="text-sm text-muted-foreground space-y-1">
                <p><strong>Login:</strong> admin</p>
                <p><strong>Senha:</strong> 123456</p>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Rodapé */}
        <div className="text-center mt-8 text-sm text-muted-foreground">
          <p>Sistema desenvolvido para controle empresarial</p>
          <p className="mt-1">© 2024 - Todos os direitos reservados</p>
        </div>
      </div>
    </Layout>
  );
}