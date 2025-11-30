import { useEffect } from "react";
import { Navigate } from "react-router-dom";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Layout } from "@/components/ui/layout";
import { useAuth } from "@/hooks/useAuth";
import { useMaterials } from "@/hooks/useMaterials";
import { 
  Package, 
  QrCode, 
  TrendingUp, 
  AlertTriangle,
  CheckCircle,
  XCircle,
  BarChart3,
  Users,
  Building2,
  Download
} from "lucide-react";
import { Sidebar } from "@/components/Sidebar";

export default function Dashboard() {
  const { isAuthenticated, user } = useAuth();
  const { materials, loading, fetchMaterials } = useMaterials();

  useEffect(() => {
    fetchMaterials();
  }, [fetchMaterials]);

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  // Estatísticas
  const totalMaterials = materials.length;
  const conferidosCorretos = materials.filter(m => m.status === 'conferido_correto').length;
  const conferidosOutroSetor = materials.filter(m => m.status === 'conferido_outro_setor').length;
  const naoConferidos = materials.filter(m => m.status === 'nao_conferido').length;
  
  const percentualConferido = totalMaterials > 0 ? 
    Math.round(((conferidosCorretos + conferidosOutroSetor) / totalMaterials) * 100) : 0;

  const stats = [
    {
      title: "Total de Materiais",
      value: totalMaterials,
      description: "Materiais cadastrados",
      icon: Package,
      color: "bg-primary",
      trend: "+12% este mês"
    },
    {
      title: "Conferidos Corretos",
      value: conferidosCorretos,
      description: "Localização correta",
      icon: CheckCircle,
      color: "bg-success",
      trend: `${Math.round((conferidosCorretos / totalMaterials) * 100)}% do total`
    },
    {
      title: "Fora do Local",
      value: conferidosOutroSetor,
      description: "Localização incorreta",
      icon: AlertTriangle,
      color: "bg-warning",
      trend: "Requer atenção"
    },
    {
      title: "Não Conferidos",
      value: naoConferidos,
      description: "Aguardando conferência",
      icon: XCircle,
      color: "bg-destructive",
      trend: "Pendentes"
    }
  ];

  return (
    <Layout className="flex h-screen">
      <Sidebar />
      
      <main className="flex-1 overflow-y-auto">
        <div className="p-6">
          {/* Header */}
          <div className="mb-8">
            <h1 className="text-3xl font-bold text-foreground mb-2">
              Dashboard Principal
            </h1>
            <p className="text-muted-foreground">
              Bem-vindo, {user?.nome}! Acompanhe o status dos materiais em tempo real.
            </p>
          </div>

          {/* Cards de Estatísticas */}
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
            {stats.map((stat, index) => (
              <Card key={index} className="gradient-card shadow-card border-0 animate-slide-up">
                <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                  <CardTitle className="text-sm font-medium text-muted-foreground">
                    {stat.title}
                  </CardTitle>
                  <div className={`p-2 rounded-lg ${stat.color}`}>
                    <stat.icon className="h-4 w-4 text-white" />
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold text-foreground mb-1">
                    {stat.value}
                  </div>
                  <p className="text-xs text-muted-foreground mb-2">
                    {stat.description}
                  </p>
                  <Badge variant="secondary" className="text-xs">
                    {stat.trend}
                  </Badge>
                </CardContent>
              </Card>
            ))}
          </div>

          {/* Resumo de Conferência */}
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
            <Card className="gradient-card shadow-card border-0">
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <BarChart3 className="h-5 w-5 text-primary" />
                  Progresso da Conferência
                </CardTitle>
                <CardDescription>
                  Percentual de materiais conferidos
                </CardDescription>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  <div className="flex justify-between items-center">
                    <span className="text-sm font-medium">Progresso Total</span>
                    <span className="text-2xl font-bold text-primary">
                      {percentualConferido}%
                    </span>
                  </div>
                  
                  <div className="w-full bg-secondary rounded-full h-3">
                    <div 
                      className="gradient-primary h-3 rounded-full transition-all duration-500"
                      style={{ width: `${percentualConferido}%` }}
                    />
                  </div>
                  
                  <div className="grid grid-cols-3 gap-4 text-center">
                    <div>
                      <div className="text-lg font-semibold text-success">
                        {conferidosCorretos}
                      </div>
                      <div className="text-xs text-muted-foreground">Corretos</div>
                    </div>
                    <div>
                      <div className="text-lg font-semibold text-warning">
                        {conferidosOutroSetor}
                      </div>
                      <div className="text-xs text-muted-foreground">Fora do Local</div>
                    </div>
                    <div>
                      <div className="text-lg font-semibold text-destructive">
                        {naoConferidos}
                      </div>
                      <div className="text-xs text-muted-foreground">Pendentes</div>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>

          </div>
        </div>
      </main>
    </Layout>
  );
}