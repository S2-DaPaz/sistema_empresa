import EntityManager from "../components/EntityManager";

const fields = [
  { name: "name", label: "Nome", type: "text", placeholder: "Nome completo" },
  { name: "email", label: "E-mail", type: "text", placeholder: "email@empresa.com" },
  { name: "role", label: "Função", type: "text", placeholder: "Técnico, gestor, administrador" }
];

export default function Users() {
  return (
    <EntityManager
      title="Usuários"
      endpoint="/users"
      fields={fields}
      hint="Controle de usuários do sistema"
      primaryField="name"
    />
  );
}
