import EntityManager from "../components/EntityManager";

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
  return (
    <EntityManager
      title="Clientes"
      endpoint="/clients"
      fields={fields}
      hint="Cadastre empresas e contatos principais"
      primaryField="name"
    />
  );
}
