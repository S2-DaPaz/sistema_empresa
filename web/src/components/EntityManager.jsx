import { useEffect, useMemo, useState } from "react";
import { apiDelete, apiGet, apiPost, apiPut } from "../api";
import FormField from "./FormField";

export default function EntityManager({
  title,
  endpoint,
  fields,
  hint,
  primaryField,
  canManage = true,
  canView = true
}) {
  const [items, setItems] = useState([]);
  const [activeId, setActiveId] = useState(null);
  const [error, setError] = useState("");

  const initialForm = useMemo(() => {
    return fields.reduce((acc, field) => {
      acc[field.name] = field.defaultValue ?? "";
      return acc;
    }, {});
  }, [fields]);

  const [form, setForm] = useState(initialForm);

  const optionLabels = useMemo(() => {
    return fields.reduce((acc, field) => {
      if (Array.isArray(field.options)) {
        const map = new Map();
        field.options.forEach((option) => {
          map.set(String(option.value), option.label);
        });
        acc[field.name] = map;
      }
      return acc;
    }, {});
  }, [fields]);

  const fieldFormatters = useMemo(() => {
    return fields.reduce((acc, field) => {
      if (typeof field.format === "function") {
        acc[field.name] = field.format;
      }
      return acc;
    }, {});
  }, [fields]);

  async function loadItems() {
    try {
      const data = await apiGet(endpoint);
      setItems(data || []);
    } catch (err) {
      setError(err.message || "Falha ao carregar");
    }
  }

  useEffect(() => {
    if (canView) {
      loadItems();
    }
  }, [canView]);

  function resetForm() {
    setForm(initialForm);
    setActiveId(null);
    setError("");
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setError("");

    try {
      if (activeId) {
        await apiPut(`${endpoint}/${activeId}`, form);
      } else {
        await apiPost(endpoint, form);
      }
      await loadItems();
      resetForm();
    } catch (err) {
      setError(err.message || "Falha ao salvar");
    }
  }

  function handleEdit(item) {
    setActiveId(item.id);
    setForm(
      fields.reduce((acc, field) => {
        acc[field.name] = item[field.name] ?? "";
        return acc;
      }, {})
    );
  }

  async function handleDelete(id) {
    setError("");
    try {
      await apiDelete(`${endpoint}/${id}`);
      if (activeId === id) {
        resetForm();
      }
      await loadItems();
    } catch (err) {
      setError(err.message || "Falha ao remover");
    }
  }

  const titleField = primaryField || fields[0]?.name;

  if (!canView) {
    return (
      <section className="section">
        <div className="section-header">
          <h2 className="section-title">{title}</h2>
        </div>
        <div className="card">
          <p>Você não tem permissão para visualizar este conteúdo.</p>
        </div>
      </section>
    );
  }

  return (
    <section className="section">
      <div className="section-header">
        <h2 className="section-title">{title}</h2>
        {hint && <span className="muted">{hint}</span>}
      </div>

      <div className="grid-2">
        <div className="list">
          {items.length === 0 && (
            <div className="card">
              <h3>Nenhum registro</h3>
              <small>Cadastre o primeiro item para iniciar.</small>
            </div>
          )}
          {items.map((item) => (
            <div key={item.id} className="card">
              <h3>{item[titleField] || "Sem título"}</h3>
              <small>
                {fields
                  .filter((field) => field.name !== titleField)
                  .map((field) => {
                    const value = item[field.name];
                    const map = optionLabels[field.name];
                    const formatter = fieldFormatters[field.name];
                    let displayValue = value;
                    if (map) {
                      displayValue = map.get(String(value)) || value;
                    }
                    if (formatter) {
                      displayValue = formatter(displayValue, item);
                    }
                    return displayValue;
                  })
                  .filter(Boolean)
                  .join(" | ")}
              </small>
              {canManage && (
                <div className="inline" style={{ marginTop: "12px" }}>
                  <button className="btn secondary" onClick={() => handleEdit(item)}>
                    Editar
                  </button>
                  <button className="btn ghost" onClick={() => handleDelete(item.id)}>
                    Remover
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>

        {canManage ? (
          <form className="card" onSubmit={handleSubmit}>
            <h3>{activeId ? "Editar" : "Novo"}</h3>
            <div className="form-grid">
              {fields.map((field) => (
                <FormField
                  key={field.name}
                  label={field.label}
                  type={field.type}
                  value={form[field.name]}
                  options={field.options}
                  placeholder={field.placeholder}
                  className={field.className}
                  onChange={(value) =>
                    setForm((prev) => ({
                      ...prev,
                      [field.name]: value
                    }))
                  }
                />
              ))}
            </div>
            {error && <p className="muted">{error}</p>}
            <div className="inline" style={{ marginTop: "16px" }}>
              <button className="btn primary" type="submit">
                {activeId ? "Atualizar" : "Salvar"}
              </button>
              <button className="btn ghost" type="button" onClick={resetForm}>
                Limpar
              </button>
            </div>
          </form>
        ) : (
          <div className="card">
            <h3>Somente leitura</h3>
            <small>Você não tem permissão para editar ou criar registros.</small>
          </div>
        )}
      </div>
    </section>
  );
}
