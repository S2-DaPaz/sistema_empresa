import { useEffect, useState } from "react";
import { apiDelete, apiGet, apiPost, apiPut } from "../api";
import FormField from "../components/FormField";

const typeOptions = [
  { value: "text", label: "Texto curto" },
  { value: "textarea", label: "Texto longo" },
  { value: "number", label: "Número" },
  { value: "date", label: "Data" },
  { value: "select", label: "Seleção" },
  { value: "yesno", label: "Sim ou não" },
  { value: "checkbox", label: "Caixa de seleção" }
];

function uid() {
  if (typeof crypto !== "undefined" && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return `id_${Date.now()}_${Math.random().toString(16).slice(2)}`;
}

export default function Templates() {
  const [items, setItems] = useState([]);
  const [activeId, setActiveId] = useState(null);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [sections, setSections] = useState([]);
  const [sectionColumns, setSectionColumns] = useState("1");
  const [fieldColumns, setFieldColumns] = useState("1");
  const [optionDrafts, setOptionDrafts] = useState({});
  const [error, setError] = useState("");

  async function loadItems() {
    const data = await apiGet("/report-templates");
    setItems(data || []);
  }

  useEffect(() => {
    loadItems();
  }, []);

  function resetForm() {
    setActiveId(null);
    setName("");
    setDescription("");
    setSections([]);
    setSectionColumns("1");
    setFieldColumns("1");
    setOptionDrafts({});
    setError("");
  }

  function handleEdit(item) {
    setActiveId(item.id);
    setName(item.name || "");
    setDescription(item.description || "");
    setSections(item.structure?.sections || []);
    setSectionColumns(String(item.structure?.layout?.sectionColumns || 1));
    setFieldColumns(String(item.structure?.layout?.fieldColumns || 1));
    setOptionDrafts({});
  }

  function addSection() {
    setSections((prev) => [...prev, { id: uid(), title: "", fields: [] }]);
  }

  function updateSection(id, updates) {
    setSections((prev) => prev.map((section) => (section.id === id ? { ...section, ...updates } : section)));
  }

  function removeSection(id) {
    setSections((prev) => prev.filter((section) => section.id !== id));
  }

  function addField(sectionId) {
    setSections((prev) =>
      prev.map((section) =>
        section.id === sectionId
          ? {
              ...section,
              fields: [
                ...section.fields,
                { id: uid(), label: "", type: "text", required: false, options: [] }
              ]
            }
          : section
      )
    );
  }

  function updateField(sectionId, fieldId, updates) {
    setSections((prev) =>
      prev.map((section) =>
        section.id === sectionId
          ? {
              ...section,
              fields: section.fields.map((field) =>
                field.id === fieldId ? { ...field, ...updates } : field
              )
            }
          : section
      )
    );
  }

  function removeField(sectionId, fieldId) {
    setSections((prev) =>
      prev.map((section) =>
        section.id === sectionId
          ? { ...section, fields: section.fields.filter((field) => field.id !== fieldId) }
          : section
      )
    );
  }

  function updateOptionDraft(fieldId, value) {
    setOptionDrafts((prev) => ({
      ...prev,
      [fieldId]: value
    }));
  }

  function addOption(sectionId, fieldId, currentOptions = []) {
    const draft = (optionDrafts[fieldId] || "").trim();
    if (!draft) return;
    updateField(sectionId, fieldId, {
      options: [...currentOptions, draft]
    });
    updateOptionDraft(fieldId, "");
  }

  function removeOption(sectionId, fieldId, optionIndex, currentOptions = []) {
    updateField(sectionId, fieldId, {
      options: currentOptions.filter((_, index) => index !== optionIndex)
    });
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setError("");

    const payload = {
      name,
      description,
      structure: {
        sections,
        layout: {
          sectionColumns: Number(sectionColumns) || 1,
          fieldColumns: Number(fieldColumns) || 1
        }
      }
    };

    try {
      if (activeId) {
        await apiPut(`/report-templates/${activeId}`, payload);
      } else {
        await apiPost("/report-templates", payload);
      }
      await loadItems();
      resetForm();
    } catch (err) {
      setError(err.message || "Falha ao salvar");
    }
  }

  async function handleDelete(id) {
    setError("");
    try {
      await apiDelete(`/report-templates/${id}`);
      if (activeId === id) {
        resetForm();
      }
      await loadItems();
    } catch (err) {
      setError(err.message || "Falha ao remover");
    }
  }

  return (
    <section className="section">
      <div className="section-header">
        <h2 className="section-title">Modelos de relatório</h2>
        <span className="muted">Crie layouts personalizados por tipo de atendimento</span>
      </div>

      <div className="grid-2">
        <div className="list">
          {items.length === 0 && (
            <div className="card">
              <h3>Nenhum modelo</h3>
              <small>Monte seu primeiro modelo personalizado.</small>
            </div>
          )}
          {items.map((item) => (
            <div key={item.id} className="card">
              <h3>{item.name}</h3>
              <small>{item.description || "Sem descrição"}</small>
              <div className="inline" style={{ marginTop: "12px" }}>
                <button className="btn secondary" onClick={() => handleEdit(item)}>
                  Editar
                </button>
                <button className="btn ghost" onClick={() => handleDelete(item.id)}>
                  Remover
                </button>
              </div>
            </div>
          ))}
        </div>

        <form className="card" onSubmit={handleSubmit}>
          <h3>{activeId ? "Editar modelo" : "Novo modelo"}</h3>
          <div className="form-grid">
            <FormField label="Nome" value={name} onChange={setName} />
            <FormField
              label="Descrição"
              type="textarea"
              value={description}
              onChange={setDescription}
              className="full"
            />
            <FormField
              label="Colunas das seções"
              type="select"
              value={sectionColumns}
              options={[
                { value: "1", label: "1 coluna" },
                { value: "2", label: "2 colunas" },
                { value: "3", label: "3 colunas" }
              ]}
              onChange={setSectionColumns}
            />
            <FormField
              label="Colunas dos campos"
              type="select"
              value={fieldColumns}
              options={[
                { value: "1", label: "1 coluna" },
                { value: "2", label: "2 colunas" },
                { value: "3", label: "3 colunas" }
              ]}
              onChange={setFieldColumns}
            />
          </div>

          <div style={{ marginTop: "18px" }}>
            <div className="section-header">
              <h3 className="section-title">Seções</h3>
              <button className="btn secondary" type="button" onClick={addSection}>
                Adicionar seção
              </button>
            </div>

            <div className="list">
              {sections.length === 0 && (
                <div className="card">
                  <small>Adicione seções e campos para o relatório.</small>
                </div>
              )}
              {sections.map((section) => (
                <div key={section.id} className="card">
                  <div className="inline" style={{ justifyContent: "space-between" }}>
                    <FormField
                      label="Título da seção"
                      value={section.title}
                      onChange={(value) => updateSection(section.id, { title: value })}
                    />
                    <button className="btn ghost" type="button" onClick={() => removeSection(section.id)}>
                      Remover seção
                    </button>
                  </div>

                  <div className="section-header" style={{ marginTop: "12px" }}>
                    <h3 className="section-title">Campos</h3>
                    <button
                      className="btn secondary"
                      type="button"
                      onClick={() => addField(section.id)}
                    >
                      Adicionar campo
                    </button>
                  </div>

                  <div className="list">
                    {section.fields.length === 0 && (
                      <div className="card">
                        <small>Adicione campos a esta seção.</small>
                      </div>
                    )}
                    {section.fields.map((field) => (
                      <div key={field.id} className="card">
                        <div className="form-grid">
                          <FormField
                            label="Label"
                            value={field.label}
                            onChange={(value) => updateField(section.id, field.id, { label: value })}
                          />
                          <FormField
                            label="Tipo"
                            type="select"
                            value={field.type}
                            options={typeOptions}
                            onChange={(value) => updateField(section.id, field.id, { type: value })}
                          />
                          {field.type === "select" && (
                            <div className="card" style={{ padding: "12px" }}>
                              <div className="inline" style={{ justifyContent: "space-between" }}>
                                <FormField
                                  label="Adicionar opção"
                                  value={optionDrafts[field.id] || ""}
                                  onChange={(value) => updateOptionDraft(field.id, value)}
                                />
                                <button
                                  className="btn secondary"
                                  type="button"
                                  onClick={() => addOption(section.id, field.id, field.options || [])}
                                >
                                  Incluir
                                </button>
                              </div>
                              {(field.options || []).length > 0 ? (
                                <div className="list" style={{ marginTop: "10px" }}>
                                  {(field.options || []).map((option, index) => (
                                    <div key={`${field.id}-${option}-${index}`} className="inline">
                                      <span>{option}</span>
                                      <button
                                        className="btn ghost"
                                        type="button"
                                        onClick={() =>
                                          removeOption(section.id, field.id, index, field.options || [])
                                        }
                                      >
                                        Remover
                                      </button>
                                    </div>
                                  ))}
                                </div>
                              ) : (
                                <small className="muted">Nenhuma opção adicionada.</small>
                              )}
                            </div>
                          )}
                          <FormField
                            label="Obrigatório"
                            type="checkbox"
                            value={field.required}
                            onChange={(value) =>
                              updateField(section.id, field.id, { required: value })
                            }
                          />
                        </div>
                        <div className="inline" style={{ marginTop: "10px" }}>
                          <button
                            className="btn ghost"
                            type="button"
                            onClick={() => removeField(section.id, field.id)}
                          >
                            Remover campo
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
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
      </div>
    </section>
  );
}
