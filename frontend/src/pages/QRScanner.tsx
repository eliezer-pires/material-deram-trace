import { useState, useRef } from "react";
import { Navigate } from "react-router-dom";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
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
  QrCode, 
  Camera, 
  MapPin,
  CheckCircle,
  XCircle
} from "lucide-react";
import { useToast } from "@/hooks/use-toast";

export default function QRScanner() {
  const { isAuthenticated } = useAuth();
  const { setores, conferirMaterial } = useMaterials();
  const { toast } = useToast();
  const [selectedSetor, setSelectedSetor] = useState("");
  const [selectedSala, setSelectedSala] = useState("");
  const [isScanning, setIsScanning] = useState(false);
  const [scanResult, setScanResult] = useState<any>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const streamRef = useRef<MediaStream | null>(null);

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  const getSalasDoSetor = (setor: string) => {
    const setorObj = setores.find(s => s.nome === setor);
    return setorObj ? setorObj.salas : [];
  };

  const startScanning = async () => {
    if (!selectedSetor || !selectedSala) {
      toast({
        title: "Erro",
        description: "Selecione o setor e a sala antes de iniciar a conferência",
        variant: "destructive"
      });
      return;
    }

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ 
        video: { facingMode: 'environment' } // Câmera traseira
      });
      
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        streamRef.current = stream;
        setIsScanning(true);
      }
    } catch (error) {
      toast({
        title: "Erro",
        description: "Não foi possível acessar a câmera",
        variant: "destructive"
      });
    }
  };

  const stopScanning = () => {
    if (streamRef.current) {
      streamRef.current.getTracks().forEach(track => track.stop());
      streamRef.current = null;
    }
    setIsScanning(false);
    setScanResult(null);
  };

  const handleQRCodeDetected = (qrCodeData: string) => {
    // TODO: Conectar com backend para verificar e atualizar material
    // API: POST /api/materials/conferir
    // Endpoint: http://localhost:3001/api/materials/conferir
    
    conferirMaterial(qrCodeData, selectedSetor, selectedSala);
    
    setScanResult({
      qrCode: qrCodeData,
      setor: selectedSetor,
      sala: selectedSala,
      timestamp: new Date().toISOString()
    });

    toast({
      title: "QR Code Lido!",
      description: `Material conferido em ${selectedSetor} - ${selectedSala}`,
    });

    // Para da câmera após leitura
    stopScanning();
  };

  // Simulação de leitura de QR Code (em produção, usar biblioteca real)
  const simulateQRScan = () => {
    const mockQRCodes = [
      'QR_001_HASH_ABC123',
      'QR_002_HASH_DEF456',
      'QR_003_HASH_GHI789'
    ];
    const randomQR = mockQRCodes[Math.floor(Math.random() * mockQRCodes.length)];
    handleQRCodeDetected(randomQR);
  };

  return (
    <Layout className="flex h-screen">
      <Sidebar />
      
      <main className="flex-1 overflow-y-auto">
        <div className="p-6">
          {/* Header */}
          <div className="mb-8">
            <h1 className="text-3xl font-bold text-foreground mb-2">
              Scanner QR Code
            </h1>
            <p className="text-muted-foreground">
              Selecione o local da conferência e escaneie os QR Codes dos materiais
            </p>
          </div>

          {/* Configuração da Conferência */}
          <Card className="mb-6 gradient-card shadow-card border-0">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <MapPin className="h-5 w-5 text-primary" />
                Local da Conferência
              </CardTitle>
              <CardDescription>
                Selecione o setor e sala onde você está fazendo a conferência
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
                      setSelectedSala("");
                    }}
                    disabled={isScanning}
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
                  <label className="text-sm font-medium mb-2 block">Sala</label>
                  <Select 
                    value={selectedSala} 
                    onValueChange={setSelectedSala}
                    disabled={!selectedSetor || isScanning}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Selecione a sala" />
                    </SelectTrigger>
                    <SelectContent>
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

          {/* Scanner */}
          <Card className="gradient-card shadow-card border-0">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <QrCode className="h-5 w-5 text-primary" />
                Scanner de QR Code
              </CardTitle>
              <CardDescription>
                {isScanning ? 'Aponte a câmera para o QR Code do material' : 'Configure o local e inicie a conferência'}
              </CardDescription>
            </CardHeader>
            <CardContent>
              {!isScanning ? (
                <div className="text-center py-12">
                  <Camera className="mx-auto h-16 w-16 text-muted-foreground mb-4" />
                  <h3 className="text-lg font-medium text-foreground mb-2">
                    Câmera Desativada
                  </h3>
                  <p className="text-muted-foreground mb-6">
                    Selecione o setor e sala, depois inicie a conferência
                  </p>
                  <Button 
                    onClick={startScanning}
                    disabled={!selectedSetor || !selectedSala}
                    className="gradient-primary text-white"
                  >
                    <Camera className="mr-2 h-4 w-4" />
                    Iniciar Conferência
                  </Button>
                </div>
              ) : (
                <div className="space-y-4">
                  {/* Área da Câmera */}
                  <div className="relative bg-muted rounded-lg overflow-hidden">
                    <video
                      ref={videoRef}
                      autoPlay
                      playsInline
                      className="w-full h-64 object-cover"
                    />
                    <div className="absolute inset-0 border-2 border-primary opacity-50 pointer-events-none">
                      <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2">
                        <div className="w-48 h-48 border-2 border-white rounded-lg"></div>
                      </div>
                    </div>
                  </div>

                  {/* Informações da Conferência */}
                  <div className="flex items-center justify-between p-4 bg-background rounded-lg border border-border">
                    <div className="flex items-center gap-3">
                      <Badge variant="outline" className="bg-primary/10 text-primary">
                        {selectedSetor}
                      </Badge>
                      <Badge variant="outline" className="bg-secondary/10">
                        {selectedSala}
                      </Badge>
                    </div>
                    <div className="flex gap-2">
                      <Button onClick={simulateQRScan} variant="outline" size="sm">
                        Simular Leitura
                      </Button>
                      <Button onClick={stopScanning} variant="destructive" size="sm">
                        Parar Scanner
                      </Button>
                    </div>
                  </div>
                </div>
              )}

              {/* Resultado da Leitura */}
              {scanResult && (
                <div className="mt-4 p-4 bg-success/10 border border-success/20 rounded-lg">
                  <div className="flex items-center gap-2 mb-2">
                    <CheckCircle className="h-5 w-5 text-success" />
                    <span className="font-medium text-success">QR Code Lido com Sucesso!</span>
                  </div>
                  <div className="text-sm text-muted-foreground">
                    <p>QR Code: {scanResult.qrCode}</p>
                    <p>Local: {scanResult.setor} - {scanResult.sala}</p>
                    <p>Horário: {new Date(scanResult.timestamp).toLocaleString('pt-BR')}</p>
                  </div>
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      </main>
    </Layout>
  );
}