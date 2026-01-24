import { useEffect, useMemo, useState } from "react";
import { apiDelete, apiGet, apiPost, apiPut } from "../api";
import FormField from "../components/FormField";
import { PERMISSIONS, useAuth } from "../contexts/AuthContext";

const roleOptions = [
  { value: "administracao", label: "Administração" },
  { value: "gestor", label: "Gestor" },
  { value: "tecnico", label: "Técnico" },
  { value: "visitante", label: "Visitante" }
];

const permissionOptions = [
  { id: PERMISSIONS.VIEW_DASHBOARD, label: "Visualizar painel" },
  { id: PERMISSIONS.VIEW_CLIENTS, label: "Visualizar clientes" },
  { id: PERMISSIONS.MANAGE_CLIENTS, label: "Gerenciar clientes" },
  { id: PERMISSIONS.VIEW_TASKS, label: "Visualizar tarefas" },
  { id: PERMISSIONS.MANAGE_TASKS, label: "Gerenciar tarefas" },
  { id: PERMISSIONS.VIEW_TEMPLATES, label: "Visualizar modelos" },
  { id: PERMISSIONS.MANAGE_TEMPLATES, label: "Gerenciar modelos" },
  { id: PERMISSIONS.VIEW_BUDGETS, label: "Visualizar orçamentos" },
  { id: PERMISSIONS.MANAGE_BUDGETS, label: "Gerenciar orçamentos" },
  { id: PERMISSIONS.VIEW_PRODUCTS, label: "Visualizar produtos" },
  { id: PERMISSIONS.MANAGE_PRODUCTS, label: "Gerenciar produtos" },
  { id: PERMISSIONS.VIEW_TASK_TYPES, label: "Visualizar tipos de tarefa" },
  { id: PERMISSIONS.MANAGE_TASK_TYPES, label: "Gerenciar tipos de tarefa" }
];

export default function Users() {
  const { user, hasPermission } = useAuth();
  const [users, setUsers] = useState([]);
  const [activeId, setActiveId] = useState(null);
  const [form, setForm] = useState({
    name: "",
    email: "",
    role: "visitante",
    password: "",
    permissions: []
  });
  const [error, setError] = useState("");
  const canManageUsers = hasPermission(PERMISSIONS.MANAGE_USERS);

  const roleLabel = useMemo(() => {
    const map = new Map(roleOptions.map((option) => [option.value, option.label]));
    return (value) => map.get(value) || value;
  }, []);

  async function loadUsers() {
    const data = await apiGet("/users");
    setUsers(data || []);
  }

  useEffect(() => {
    loadUsers();
  }, []);

  function resetForm() {
    setActiveId(null);
    setForm({ name: "", email: "", role: "visitante", password: "", permissions: [] });
    setError("");
  }

  function handleEdit(item) {
    setActiveId(item.id);
    setForm({
      name: item.name || "",
      email: item.email || "",
      role: item.role || "visitante",
      password: "",
      permissions: Array.isArray(item.permissions) ? item.permissions : []
    });
  }

  function togglePermission(permission) {
    setForm((prev) => {
      const has = prev.permissions.includes(permission);
      return {
        ...prev,
        permissions: has
          ? prev.permissions.filter((item) => item !== permission)
          : [...prev.permissions, permission]
      };
    });
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setError("");
    if (!canManageUsers) {
      setError("Voc\u00ea n\u00e3o possui permiss\u00e3o para gerenciar usu\u00e1rios.");
      return;
    }

    try {
      if (activeId) {
        await apiPut(`/users/${activeId}`, {
          name: form.name,
          email: form.email,
          role: form.role,
          permissions: form.permissions,
          password: form.password || undefined
        });
      } else {
        await apiPost("/users", form);
      }
      await loadUsers();
      resetForm();
    } catch (err) {
      setError(err.message || "Falha ao salvar");
    }
  }

  async function handleDelete(id) {
    if (!canManageUsers) {
      setError("Voc\u00ea n\u00e3o possui permiss\u00e3o para gerenciar usu\u00e1rios.");
      return;
    }
    if (!window.confirm("Deseja remover este usuário?")) return;
    setError("");
    try {
      await apiDelete(`/users/${id}`);
      await loadUsers();
      if (activeId === id) {
        resetForm();
      }
    } catch (err) {
      setError(err.message || "Falha ao remover");
    }
  }

  return (
    <section className="section">
      <div className="section-header">
        <h2 className="section-title">Usuários</h2>
        <span className="muted">Gerencie cargos e permissões do time</span>
      </div>

      <div className="grid-2">
        <div className="list">
          {users.length === 0 && (
            <div className="card">
              <h3>Nenhum usuário cadastrado</h3>
              <small>Crie o primeiro usuário para iniciar.</small>
            </div>
          )}
          {users.map((item) => (
            <div key={item.id} className="card">
              <div className="inline" style={{ justifyContent: "space-between" }}>
                <h3>{item.name || "Sem nome"}</h3>
                {item.id === user?.id && <span className="badge">Você</span>}
              </div>
              <small>{item.email || "Sem e-mail"}</small>
              <small>Cargo: {roleLabel(item.role)}</small>
              <small>Permissões extras: {(item.permissions || []).length}</small>
              {canManageUsers && (
                <div className="inline" style={{ marginTop: "12px" }}>
                  <button className="btn secondary" onClick={() => handleEdit(item)}>
                    Editar
                  </button>
                  <button
                    className="btn ghost"
                    onClick={() => handleDelete(item.id)}
                    disabled={item.id === user?.id}
                  >
                    Remover
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>

        {canManageUsers ? (
          <form className="card" onSubmit={handleSubmit}>
          <h3>{activeId ? "Editar usuário" : "Novo usuário"}</h3>
          <div className="form-grid">
            <FormField
              label="Nome"
              value={form.name}
              placeholder="Nome completo"
              onChange={(value) => setForm((prev) => ({ ...prev, name: value }))}
            />
            <FormField
              label="E-mail"
              value={form.email}
              placeholder="email@empresa.com"
              onChange={(value) => setForm((prev) => ({ ...prev, email: value }))}
            />
            <FormField
              label="Cargo"
              type="select"
              value={form.role}
              options={roleOptions}
              onChange={(value) => setForm((prev) => ({ ...prev, role: value }))}
            />
            <FormField
              label={activeId ? "Nova senha (opcional)" : "Senha"}
              type="password"
              value={form.password}
              placeholder={activeId ? "Digite para alterar" : "Crie uma senha"}
              onChange={(value) => setForm((prev) => ({ ...prev, password: value }))}
            />
          </div>

          <div style={{ marginTop: "16px" }}>
            <h4 className="section-title">Permissões extras</h4>
            <div className="permission-grid">
              {permissionOptions.map((option) => (
                <label key={option.id} className="permission-item">
                  <input
                    type="checkbox"
                    checked={form.permissions.includes(option.id)}
                    onChange={() => togglePermission(option.id)}
                  />
                  <span>{option.label}</span>
                </label>
              ))}
            </div>
            <small className="muted">
              As permissões do cargo são aplicadas automaticamente. Aqui você adiciona extras.
            </small>
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
            <h3>Acesso somente leitura</h3>
            <p>Voc\u00ea pode visualizar os usu\u00e1rios, mas n\u00e3o tem permiss\u00e3o para editar.</p>
          </div>
        )}
      </div>
    </section>
  );
}
