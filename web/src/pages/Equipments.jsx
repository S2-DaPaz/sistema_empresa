import { useEffect, useMemo, useState } from "react";
import { apiGet } from "../api";
import EntityManager from "../components/EntityManager";
import { PERMISSIONS, useAuth } from "../contexts/AuthContext";

export default function Equipments() {
  const { hasPermission } = useAuth();
  const canView = hasPermission(PERMISSIONS.VIEW_TASKS);
  const canManage = hasPermission(PERMISSIONS.MANAGE_TASKS);
  const [clients, setClients] = useState([]);

  useEffect(() => {
    if (!canView) return;
    apiGet("/clients")
      .then((data) => setClients(data || []))
      .catch(() => setClients([]));
  }, [canView]);

  const clientOptions = useMemo(
    () => clients.map((client) => ({ value: client.id, label: client.name })),
    [clients]
  );

  return (
    <EntityManager
      title="Equipamentos"
      endpoint="/equipments"
      hint="Cadastre equipamentos e vincule aos clientes."
      primaryField="name"
      canManage={canManage}
      canView={canView}
      fields={[
        { name: "name", label: "Nome", type: "text" },
        { name: "client_id", label: "Cliente", type: "select", options: clientOptions },
        { name: "model", label: "Modelo", type: "text" },
        { name: "serial", label: "Série", type: "text" },
        { name: "description", label: "Descrição", type: "textarea", className: "full" }
      ]}
    />
  );
}
