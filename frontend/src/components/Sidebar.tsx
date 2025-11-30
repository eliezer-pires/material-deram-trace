import { useState } from "react";
import { useNavigate, useLocation } from "react-router-dom";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/hooks/useAuth";
import { 
  LayoutDashboard, 
  Package, 
  Camera, 
  Settings, 
  LogOut,
  Menu,
  X,
  Building2
} from "lucide-react";
import { cn } from "@/lib/utils";

export function Sidebar() {
  const [collapsed, setCollapsed] = useState(false);
  const navigate = useNavigate();
  const location = useLocation();
  const { logout, user } = useAuth();

  const menuItems = [
    {
      title: "Dashboard",
      icon: LayoutDashboard,
      path: "/dashboard",
      description: "Visão geral do sistema"
    },
    {
      title: "Materiais",
      icon: Package,
      path: "/materiais",
      description: "Gerenciar materiais"
    },
    {
      title: "QR Scanner",
      icon: Camera,
      path: "/qr-scanner",
      description: "Escanear QR Codes"
    },
    {
      title: "Setores",
      icon: Building2,
      path: "/setores",
      description: "Materiais por localização"
    }
  ];

  const handleLogout = () => {
    logout();
    navigate("/login");
  };

  return (
    <div className={cn(
      "bg-background border-r border-border transition-all duration-300 flex flex-col",
      collapsed ? "w-16" : "w-64"
    )}>
      {/* Header */}
      <div className="p-4 border-b border-border">
        <div className="flex items-center justify-between">
          {!collapsed && (
            <div className="flex items-center space-x-2">
              <div className="p-2 gradient-primary rounded-lg">
                <Package className="w-5 h-5 text-white" />
              </div>
              <div>
                <h2 className="font-semibold text-foreground">Controle</h2>
                <p className="text-xs text-muted-foreground">Materiais</p>
              </div>
            </div>
          )}
          
          <Button
            variant="ghost"
            size="sm"
            onClick={() => setCollapsed(!collapsed)}
            className="p-2"
          >
            {collapsed ? <Menu className="h-4 w-4" /> : <X className="h-4 w-4" />}
          </Button>
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 p-4 space-y-2">
        {menuItems.map((item) => {
          const isActive = location.pathname === item.path;
          
          return (
            <Button
              key={item.path}
              variant={isActive ? "default" : "ghost"}
              className={cn(
                "w-full justify-start h-12 transition-all duration-200",
                collapsed ? "px-3" : "px-4",
                isActive && "gradient-primary text-white shadow-corporate"
              )}
              onClick={() => navigate(item.path)}
            >
              <item.icon className={cn("h-5 w-5", !collapsed && "mr-3")} />
              {!collapsed && (
                <div className="flex-1 text-left">
                  <div className="font-medium">{item.title}</div>
                  <div className="text-xs opacity-70">{item.description}</div>
                </div>
              )}
            </Button>
          );
        })}
      </nav>

      {/* User Section */}
      <div className="p-4 border-t border-border">
        {!collapsed && (
          <div className="mb-4 p-3 bg-accent/50 rounded-lg">
            <div className="font-medium text-sm text-foreground">
              {user?.nome}
            </div>
            <div className="text-xs text-muted-foreground">
              {user?.tipo === 'admin' ? 'Administrador' : 'Operador'}
            </div>
          </div>
        )}
        
        <div className="space-y-2">
          <Button
            variant="ghost"
            className={cn("w-full justify-start", collapsed && "px-3")}
            onClick={() => navigate("/configuracoes")}
          >
            <Settings className={cn("h-5 w-5", !collapsed && "mr-3")} />
            {!collapsed && "Configurações"}
          </Button>
          
          <Button
            variant="ghost"
            className={cn(
              "w-full justify-start text-destructive hover:text-destructive hover:bg-destructive/10",
              collapsed && "px-3"
            )}
            onClick={handleLogout}
          >
            <LogOut className={cn("h-5 w-5", !collapsed && "mr-3")} />
            {!collapsed && "Sair"}
          </Button>
        </div>
      </div>
    </div>
  );
}