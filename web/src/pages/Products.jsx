import EntityManager from "../components/EntityManager";

const fields = [
  { name: "name", label: "Nome", type: "text", placeholder: "Produto" },
  { name: "sku", label: "SKU", type: "text", placeholder: "Código interno" },
  { name: "unit", label: "Unidade", type: "text", placeholder: "un, h, cx" },
  { name: "price", label: "Preço", type: "number", placeholder: "0" }
];

export default function Products() {
  return (
    <EntityManager
      title="Produtos"
      endpoint="/products"
      fields={fields}
      hint="Produtos usados nos orçamentos"
      primaryField="name"
    />
  );
}
