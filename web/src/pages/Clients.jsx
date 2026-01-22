import EntityManager from "../components/EntityManager";
import { PERMISSIONS, useAuth } from "../contexts/AuthContext";

const fields = [
  { name: "name", label: "Nome", type: "text", placeholder: "Nome do cliente" },
  { name: "cnpj", label: "CPF/CNPJ", type: "document", placeholder: "CPF ou CNPJ" },
  {
    name: "address",
    label: "Endereço",
    type: "address",
    placeholder: "Endereço completo",
    className: "full"
  },
  { name: "contact", label: "Contato", type: "text", placeholder: "Telefone ou e-mail" }
];

export default function Clients() {
  const { hasPermission } = useAuth();
  const canView = hasPermission(PERMISSIONS.VIEW_CLIENTS);
  const canManage = hasPermission(PERMISSIONS.MANAGE_CLIENTS);

  return (
    <EntityManager
      title="Clientes"
      endpoint="/clients"
      fields={fields}
      hint="Cadastre empresas e contatos principais"
      primaryField="name"
      canView={canView}
      canManage={canManage}
    />
  );
}
