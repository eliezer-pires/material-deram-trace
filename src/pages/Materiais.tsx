import { useState } from "react";
import { Navigate } from "react-router-dom";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
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
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
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
  Package, 
  Plus, 
  Search,
  Edit,
  Trash2,
  QrCode,
  Filter,
  Download
} from "lucide-react";
import * as XLSX from 'xlsx';
import { Material } from "@/types/material";

export default function Materiais() {
  const { isAuthenticated, user } = useAuth();
  const { materials, setores, addMaterial, updateMaterial, deleteMaterial } = useMaterials();
  const [searchTerm, setSearchTerm] = useState("");
  const [filterStatus, setFilterStatus] = useState<string>("all");
  const [isAddDialogOpen, setIsAddDialogOpen] = useState(false);
  const [editingMaterial, setEditingMaterial] = useState<Material | null>(null);
  
  const [newMaterial, setNewMaterial] = useState({
    nome: "",
    bmp: "",
    setor: "",
    sala: "",
    responsavel: ""
  });

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  // Filtrar materiais
  const filteredMaterials = materials.filter(material => {
    const matchesSearch = material.nome.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         material.bmp.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         material.responsavel.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesStatus = filterStatus === "all" || material.status === filterStatus;
    
    return matchesSearch && matchesStatus;
  });

  const handleAddMaterial = () => {
    // TODO: Validação dos dados
    if (!newMaterial.nome || !newMaterial.bmp || !newMaterial.setor || !newMaterial.sala) {
      return;
    }

    addMaterial({
      ...newMaterial,
      status: 'nao_conferido' as const
    });
    setNewMaterial({ nome: "", bmp: "", setor: "", sala: "", responsavel: "" });
    setIsAddDialogOpen(false);
  };

  const handleEditMaterial = (material: Material) => {
    setEditingMaterial(material);
    setNewMaterial({
      nome: material.nome,
      bmp: material.bmp,
      setor: material.setor,
      sala: material.sala,
      responsavel: material.responsavel
    });
  };

  const handleUpdateMaterial = () => {
    if (!editingMaterial || !newMaterial.nome || !newMaterial.bmp || !newMaterial.setor || !newMaterial.sala) {
      return;
    }

    updateMaterial(editingMaterial.id, {
      nome: newMaterial.nome,
      bmp: newMaterial.bmp,
      setor: newMaterial.setor,
      sala: newMaterial.sala,
      responsavel: newMaterial.responsavel
    });
    
    setEditingMaterial(null);
    setNewMaterial({ nome: "", bmp: "", setor: "", sala: "", responsavel: "" });
  };

  const handleDeleteMaterial = (id: string) => {
    if (confirm("Tem certeza que deseja excluir este material?")) {
      deleteMaterial(id);
    }
  };

  const handleExportExcel = () => {
    const exportData = materials.map(material => ({
      'Nome': material.nome,
      'BMP': material.bmp,
      'Setor': material.setor,
      'Sala': material.sala,
      'Responsável': material.responsavel,
      'Status': material.status === 'conferido_correto' ? 'Conferido' :
                material.status === 'conferido_outro_setor' ? 'Fora do Local' : 'Não Conferido',
      'QR Code Hash': material.qrCode,
      'Data Cadastro': new Date(material.dataCadastro).toLocaleDateString('pt-BR')
    }));

    const ws = XLSX.utils.json_to_sheet(exportData);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Materiais');
    XLSX.writeFile(wb, `materiais_${new Date().toISOString().split('T')[0]}.xlsx`);
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

  const getSalasDoSetor = (setor: string) => {
    const setorObj = setores.find(s => s.nome === setor);
    return setorObj ? setorObj.salas : [];
  };

  return (
    <Layout className="flex h-screen">
      <Sidebar />
      
      <main className="flex-1 overflow-y-auto">
        <div className="p-6">
          {/* Header */}
          <div className="mb-8">
            <div className="flex items-center justify-between">
              <div>
                <h1 className="text-3xl font-bold text-foreground mb-2">
                  Gerenciamento de Materiais
                </h1>
                <p className="text-muted-foreground">
                  Cadastre, edite e gerencie todos os materiais da empresa
                </p>
              </div>
              
              <div className="flex gap-2">
                <Dialog open={isAddDialogOpen} onOpenChange={setIsAddDialogOpen}>
                  <DialogTrigger asChild>
                    <Button className="gradient-primary text-white shadow-corporate">
                      <Plus className="mr-2 h-4 w-4" />
                      Novo Material
                    </Button>
                  </DialogTrigger>
                <DialogContent className="sm:max-w-md">
                  <DialogHeader>
                    <DialogTitle>{editingMaterial ? 'Editar Material' : 'Cadastrar Novo Material'}</DialogTitle>
                    <DialogDescription>
                      {editingMaterial ? 'Altere as informações do material' : 'Preencha as informações do material para gerar o QR Code'}
                    </DialogDescription>
                  </DialogHeader>
                  
                  <div className="space-y-4">
                    <div>
                      <Label htmlFor="nome">Nome do Material</Label>
                      <Input
                        id="nome"
                        value={newMaterial.nome}
                        onChange={(e) => setNewMaterial({...newMaterial, nome: e.target.value})}
                        placeholder="Ex: Computador Desktop Dell"
                      />
                    </div>
                    
                    <div>
                      <Label htmlFor="bmp">BMP</Label>
                      <Input
                        id="bmp"
                        value={newMaterial.bmp}
                        onChange={(e) => setNewMaterial({...newMaterial, bmp: e.target.value})}
                        placeholder="Ex: BMP001"
                      />
                    </div>
                    
                    <div>
                      <Label htmlFor="setor">Setor</Label>
                      <Select 
                        value={newMaterial.setor} 
                        onValueChange={(value) => setNewMaterial({...newMaterial, setor: value, sala: ""})}
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
                      <Label htmlFor="sala">Sala</Label>
                      <Select 
                        value={newMaterial.sala} 
                        onValueChange={(value) => setNewMaterial({...newMaterial, sala: value})}
                        disabled={!newMaterial.setor}
                      >
                        <SelectTrigger>
                          <SelectValue placeholder="Selecione a sala" />
                        </SelectTrigger>
                        <SelectContent>
                          {getSalasDoSetor(newMaterial.setor).map((sala) => (
                            <SelectItem key={sala} value={sala}>
                              {sala}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                    
                    <div>
                      <Label htmlFor="responsavel">Responsável</Label>
                      <Input
                        id="responsavel"
                        value={newMaterial.responsavel}
                        onChange={(e) => setNewMaterial({...newMaterial, responsavel: e.target.value})}
                        placeholder="Ex: João Silva"
                      />
                    </div>
                    
                    <div className="flex justify-end space-x-2 pt-4">
                      <Button variant="outline" onClick={() => setIsAddDialogOpen(false)}>
                        Cancelar
                      </Button>
                      <Button onClick={editingMaterial ? handleUpdateMaterial : handleAddMaterial} className="gradient-primary text-white">
                        <QrCode className="mr-2 h-4 w-4" />
                        {editingMaterial ? 'Atualizar Material' : 'Cadastrar e Gerar QR'}
                      </Button>
                    </div>
                  </div>
                </DialogContent>
              </Dialog>
              </div>
            </div>
          </div>

          {/* Filtros e Busca */}
          <Card className="mb-6 gradient-card shadow-card border-0">
            <CardContent className="pt-6">
              <div className="flex flex-col sm:flex-row gap-4">
                <div className="flex-1">
                  <div className="relative">
                    <Search className="absolute left-3 top-3 h-4 w-4 text-muted-foreground" />
                    <Input
                      placeholder="Buscar por nome, BMP ou responsável..."
                      value={searchTerm}
                      onChange={(e) => setSearchTerm(e.target.value)}
                      className="pl-10"
                    />
                  </div>
                </div>
                
                <div className="w-full sm:w-48">
                  <Select value={filterStatus} onValueChange={setFilterStatus}>
                    <SelectTrigger>
                      <Filter className="mr-2 h-4 w-4" />
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="all">Todos os Status</SelectItem>
                      <SelectItem value="nao_conferido">Não Conferido</SelectItem>
                      <SelectItem value="conferido_correto">Conferido</SelectItem>
                      <SelectItem value="conferido_outro_setor">Fora do Local</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Tabela de Materiais */}
          <Card className="gradient-card shadow-card border-0">
            <CardHeader>
              <CardTitle className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Package className="h-5 w-5 text-primary" />
                  Lista de Materiais
                </div>
                <Button onClick={handleExportExcel} variant="outline" size="sm">
                  <Download className="mr-2 h-4 w-4" />
                  Exportar Excel
                </Button>
              </CardTitle>
              <CardDescription>
                {filteredMaterials.length} de {materials.length} materiais
              </CardDescription>
            </CardHeader>
            <CardContent>
              <div className="rounded-md border border-border overflow-hidden">
                <Table>
                  <TableHeader>
                    <TableRow className="bg-muted/50">
                      <TableHead>Material</TableHead>
                      <TableHead>BMP</TableHead>
                      <TableHead>Localização</TableHead>
                      <TableHead>Responsável</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead>QR Code</TableHead>
                      <TableHead className="text-right">Ações</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {filteredMaterials.map((material) => (
                      <TableRow key={material.id} className="hover:bg-muted/50">
                        <TableCell>
                          <div>
                            <div className="font-medium text-foreground">
                              {material.nome}
                            </div>
                            <div className="text-sm text-muted-foreground">
                              Cadastrado em {new Date(material.dataCadastro).toLocaleDateString('pt-BR')}
                            </div>
                          </div>
                        </TableCell>
                        <TableCell>
                          <Badge variant="outline">{material.bmp}</Badge>
                        </TableCell>
                        <TableCell>
                          <div>
                            <div className="font-medium">{material.setor}</div>
                            <div className="text-sm text-muted-foreground">{material.sala}</div>
                          </div>
                        </TableCell>
                        <TableCell>{material.responsavel}</TableCell>
                        <TableCell>{getStatusBadge(material.status)}</TableCell>
                        <TableCell>
                          <Badge variant="secondary" className="font-mono text-xs">
                            {material.qrCode.slice(-8)}
                          </Badge>
                        </TableCell>
                        <TableCell className="text-right">
                          <div className="flex justify-end space-x-2">
                            <Button 
                              variant="ghost" 
                              size="sm"
                              onClick={() => handleEditMaterial(material)}
                            >
                              <Edit className="h-4 w-4" />
                            </Button>
                            {user?.tipo === 'admin' && (
                              <Button 
                                variant="ghost" 
                                size="sm"
                                onClick={() => handleDeleteMaterial(material.id)}
                                className="text-destructive hover:text-destructive"
                              >
                                <Trash2 className="h-4 w-4" />
                              </Button>
                            )}
                          </div>
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </div>
              
              {filteredMaterials.length === 0 && (
                <div className="text-center py-8">
                  <Package className="mx-auto h-12 w-12 text-muted-foreground mb-4" />
                  <h3 className="text-lg font-medium text-foreground mb-2">
                    Nenhum material encontrado
                  </h3>
                  <p className="text-muted-foreground">
                    {searchTerm || filterStatus !== "all" 
                      ? "Tente ajustar os filtros de busca" 
                      : "Comece cadastrando o primeiro material"}
                  </p>
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      </main>
    </Layout>
  );
}