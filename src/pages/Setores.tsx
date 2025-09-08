import { useState } from "react";
import { Navigate } from "react-router-dom";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { 
  Table, 
  TableBody, 
  TableCell, 
  TableHead, 
  TableHeader, 
  TableRow 
} from "@/components/ui/table";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Layout } from "@/components/ui/layout";
import { useAuth } from "@/hooks/useAuth";
import { useMaterials } from "@/hooks/useMaterials";
import { Sidebar } from "@/components/Sidebar";
import { 
  Building2, 
  MapPin,
  Package,
  Printer
} from "lucide-react";

export default function Setores() {
  const { isAuthenticated } = useAuth();
  const { materials, setores } = useMaterials();
  const [selectedSetor, setSelectedSetor] = useState("");
  const [selectedSala, setSelectedSala] = useState("");

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  const getSalasDoSetor = (setor: string) => {
    const setorObj = setores.find(s => s.nome === setor);
    return setorObj ? setorObj.salas : [];
  };

  const filteredMaterials = materials.filter(material => {
    if (!selectedSetor) return false;
    if (!selectedSala || selectedSala === "all") return material.setor === selectedSetor;
    return material.setor === selectedSetor && material.sala === selectedSala;
  });

  const handlePrint = () => {
    const printContent = `
      <html>
        <head>
          <title>Relatório de Materiais - ${selectedSetor} ${selectedSala ? `- ${selectedSala}` : ''}</title>
          <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            h1 { color: #333; border-bottom: 2px solid #333; padding-bottom: 10px; }
            table { width: 100%; border-collapse: collapse; margin-top: 20px; }
            th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
            th { background-color: #f5f5f5; font-weight: bold; }
            .header { margin-bottom: 20px; }
            .info { background-color: #f9f9f9; padding: 10px; border-radius: 5px; margin-bottom: 20px; }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>Relatório de Materiais</h1>
            <div class="info">
              <p><strong>Setor:</strong> ${selectedSetor}</p>
              ${selectedSala ? `<p><strong>Sala:</strong> ${selectedSala}</p>` : '<p><strong>Escopo:</strong> Todo o setor</p>'}
              <p><strong>Data:</strong> ${new Date().toLocaleDateString('pt-BR')}</p>
              <p><strong>Total de Materiais:</strong> ${filteredMaterials.length}</p>
            </div>
          </div>
          <table>
            <thead>
              <tr>
                <th>Nome</th>
                <th>BMP</th>
                <th>Responsável</th>
                <th>Sala</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              ${filteredMaterials.map(material => `
                <tr>
                  <td>${material.nome}</td>
                  <td>${material.bmp}</td>
                  <td>${material.responsavel}</td>
                  <td>${material.sala}</td>
                  <td>${
                    material.status === 'conferido_correto' ? 'Conferido' :
                    material.status === 'conferido_outro_setor' ? 'Fora do Local' : 
                    'Não Conferido'
                  }</td>
                </tr>
              `).join('')}
            </tbody>
          </table>
        </body>
      </html>
    `;

    const printWindow = window.open('', '_blank');
    if (printWindow) {
      printWindow.document.write(printContent);
      printWindow.document.close();
      printWindow.print();
    }
  };

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'conferido_correto':
        return <Badge className="bg-success text-success-foreground">Conferido</Badge>;
      case 'conferido_outro_setor':
        return <Badge className="bg-warning text-warning-foreground">Fora do Local</Badge>;
      case 'nao_conferido':
        return <Badge className="bg-destructive text-destructive-foreground">Não Conferido</Badge>;
      default:
        return <Badge variant="secondary">Desconhecido</Badge>;
    }
  };

  return (
    <Layout className="flex h-screen">
      <Sidebar />
      
      <main className="flex-1 overflow-y-auto">
        <div className="p-6">
          {/* Header */}
          <div className="mb-8">
            <h1 className="text-3xl font-bold text-foreground mb-2">
              Materiais por Setor
            </h1>
            <p className="text-muted-foreground">
              Visualize todos os materiais cadastrados por localização
            </p>
          </div>

          {/* Filtros de Localização */}
          <Card className="mb-6 gradient-card shadow-card border-0">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Building2 className="h-5 w-5 text-primary" />
                Seleção de Local
              </CardTitle>
              <CardDescription>
                Selecione o setor e opcionalmente a sala para filtrar os materiais
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="text-sm font-medium mb-2 block">Setor</label>
                  <Select 
                    value={selectedSetor} 
                    onValueChange={(value) => {
                      setSelectedSetor(value);
                      setSelectedSala("all");
                    }}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Selecione o setor" />
                    </SelectTrigger>
                    <SelectContent>
                      {setores.map((setor) => (
                        <SelectItem key={setor.id} value={setor.nome}>
                          {setor.nome}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                
                <div>
                  <label className="text-sm font-medium mb-2 block">Sala (Opcional)</label>
                  <Select 
                    value={selectedSala} 
                    onValueChange={setSelectedSala}
                    disabled={!selectedSetor}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Todas as salas" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">Todas as salas</SelectItem>
                      {getSalasDoSetor(selectedSetor).map((sala) => (
                        <SelectItem key={sala} value={sala}>
                          {sala}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Lista de Materiais */}
          {selectedSetor && (
            <Card className="gradient-card shadow-card border-0">
              <CardHeader>
                <CardTitle className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <Package className="h-5 w-5 text-primary" />
                    Materiais - {selectedSetor} {selectedSala && selectedSala !== "all" && `- ${selectedSala}`}
                  </div>
                  {filteredMaterials.length > 0 && (
                    <Button onClick={handlePrint} variant="outline" size="sm">
                      <Printer className="mr-2 h-4 w-4" />
                      Imprimir Lista
                    </Button>
                  )}
                </CardTitle>
                <CardDescription>
                  {filteredMaterials.length} materiais encontrados nesta localização
                </CardDescription>
              </CardHeader>
              <CardContent>
                {filteredMaterials.length === 0 ? (
                  <div className="text-center py-8">
                    <MapPin className="mx-auto h-12 w-12 text-muted-foreground mb-4" />
                    <h3 className="text-lg font-medium text-foreground mb-2">
                      Nenhum material encontrado
                    </h3>
                    <p className="text-muted-foreground">
                      Não há materiais cadastrados nesta localização
                    </p>
                  </div>
                ) : (
                  <div className="rounded-md border border-border overflow-hidden">
                    <Table>
                      <TableHeader>
                        <TableRow className="bg-muted/50">
                          <TableHead>Nome</TableHead>
                          <TableHead>BMP</TableHead>
                          <TableHead>Responsável</TableHead>
                          <TableHead>Sala</TableHead>
                          <TableHead>Status</TableHead>
                          <TableHead>Data Cadastro</TableHead>
                        </TableRow>
                      </TableHeader>
                      <TableBody>
                        {filteredMaterials.map((material) => (
                          <TableRow key={material.id} className="hover:bg-muted/50">
                            <TableCell>
                              <div className="font-medium text-foreground">
                                {material.nome}
                              </div>
                            </TableCell>
                            <TableCell>
                              <Badge variant="outline">{material.bmp}</Badge>
                            </TableCell>
                            <TableCell>{material.responsavel}</TableCell>
                            <TableCell>
                              <div className="flex items-center gap-1">
                                <MapPin className="h-3 w-3 text-muted-foreground" />
                                {material.sala}
                              </div>
                            </TableCell>
                            <TableCell>{getStatusBadge(material.status)}</TableCell>
                            <TableCell>
                              {new Date(material.dataCadastro).toLocaleDateString('pt-BR')}
                            </TableCell>
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                  </div>
                )}
              </CardContent>
            </Card>
          )}

          {!selectedSetor && (
            <Card className="gradient-card shadow-card border-0">
              <CardContent className="text-center py-12">
                <Building2 className="mx-auto h-16 w-16 text-muted-foreground mb-4" />
                <h3 className="text-lg font-medium text-foreground mb-2">
                  Selecione um Setor
                </h3>
                <p className="text-muted-foreground">
                  Escolha um setor acima para visualizar os materiais cadastrados
                </p>
              </CardContent>
            </Card>
          )}
        </div>
      </main>
    </Layout>
  );
}