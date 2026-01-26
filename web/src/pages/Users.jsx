import { useEffect, useMemo, useState } from "react";
import { apiDelete, apiGet, apiPost, apiPut } from "../api";
import FormField from "../components/FormField";
import { PERMISSIONS, useAuth } from "../contexts/AuthContext";

const reservedRoleKeys = new Set(["administracao", "gestor", "tecnico", "visitante"]);

const defaultRoleOptions = [
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
  { id: PERMISSIONS.VIEW_USERS, label: "Visualizar usuários" },
  { id: PERMISSIONS.MANAGE_USERS, label: "Gerenciar usuários" },
  { id: PERMISSIONS.VIEW_PRODUCTS, label: "Visualizar produtos" },
  { id: PERMISSIONS.MANAGE_PRODUCTS, label: "Gerenciar produtos" },
  { id: PERMISSIONS.VIEW_TASK_TYPES, label: "Visualizar tipos de tarefa" },
  { id: PERMISSIONS.MANAGE_TASK_TYPES, label: "Gerenciar tipos de tarefa" }
];

export default function Users() {
  const { user, hasPermission } = useAuth();
  const [users, setUsers] = useState([]);
  const [roles, setRoles] = useState([]);
  const [activeId, setActiveId] = useState(null);
  const [activeRoleId, setActiveRoleId] = useState(null);
  const [form, setForm] = useState({
    name: "",
    email: "",
    role: "visitante",
    password: "",
    permissions: []
  });
  const [roleForm, setRoleForm] = useState({
    name: "",
    permissions: [],
    is_admin: false
  });
  const [error, setError] = useState("");
  const [roleError, setRoleError] = useState("");
  const canManageUsers = hasPermission(PERMISSIONS.MANAGE_USERS);
  const canViewUsers = hasPermission(PERMISSIONS.VIEW_USERS);

  const roleOptions = useMemo(() => {
    if (!roles.length) return defaultRoleOptions;
    return roles.map((role) => ({ value: role.key, label: role.name }));
  }, [roles]);

  const roleLabel = useMemo(() => {
    const map = new Map(defaultRoleOptions.map((option) => [option.value, option.label]));
    roles.forEach((role) => map.set(role.key, role.name));
    return (value) => map.get(value) || value;
  }, [roles]);

  async function loadUsers() {
    const data = await apiGet("/users");
    setUsers(data || []);
  }

  async function loadRoles() {
    const data = await apiGet("/roles");
    setRoles(data || []);
  }

  useEffect(() => {
    if (!canViewUsers) return;
    loadUsers();
    loadRoles();
  }, [canViewUsers]);

  function resetForm() {
    setActiveId(null);
    setForm({ name: "", email: "", role: "visitante", password: "", permissions: [] });
    setError("");
  }

  function resetRoleForm() {
    setActiveRoleId(null);
    setRoleForm({ name: "", permissions: [], is_admin: false });
    setRoleError("");
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

  function handleRoleEdit(item) {
    setActiveRoleId(item.id);
    setRoleForm({
      name: item.name || item.key || "",
      permissions: Array.isArray(item.permissions) ? item.permissions : [],
      is_admin: Boolean(item.is_admin)
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

  function toggleRolePermission(permission) {
    setRoleForm((prev) => {
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
      setError("Você não possui permissão para gerenciar usuários.");
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

  async function handleRoleSubmit(event) {
    event.preventDefault();
    setRoleError("");
    if (!canManageUsers) {
      setRoleError("Você não possui permissão para gerenciar cargos.");
      return;
    }

    try {
      const payload = {
        name: roleForm.name,
        permissions: roleForm.is_admin ? [] : roleForm.permissions,
        is_admin: roleForm.is_admin
      };
      if (activeRoleId) {
        await apiPut(`/roles/${activeRoleId}`, payload);
      } else {
        await apiPost("/roles", payload);
      }
      await loadRoles();
      resetRoleForm();
    } catch (err) {
      setRoleError(err.message || "Falha ao salvar");
    }
  }

  async function handleDelete(id) {
    if (!canManageUsers) {
      setError("Você não possui permissão para gerenciar usuários.");
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

  async function handleRoleDelete(role) {
    if (!canManageUsers) {
      setRoleError("Você não possui permissão para gerenciar cargos.");
      return;
    }
    if (reservedRoleKeys.has(role.key)) {
      setRoleError("Este cargo é protegido e não pode ser removido.");
      return;
    }
    if (!window.confirm(`Deseja remover o cargo "${role.name}"?`)) return;
    setRoleError("");
    try {
      await apiDelete(`/roles/${role.id}`);
      await loadRoles();
      if (activeRoleId === role.id) {
        resetRoleForm();
      }
    } catch (err) {
      setRoleError(err.message || "Falha ao remover");
    }
  }

  if (!canViewUsers) {
    return (
      <section className="section">
        <div className="section-header">
          <h2 className="section-title">Usuários</h2>
          <span className="muted">Acesso restrito</span>
        </div>
        <div className="card">
          <h3>Sem permissão</h3>
          <p>Você não possui permissão para visualizar usuários.</p>
        </div>
      </section>
    );
  }

  return (
    <>
      <section className="section">
        <div className="section-header">
          <h2 className="section-title">Usuários</h2>
          <span className="muted">Gerencie acessos individuais do time</span>
        </div>

        <div className="grid-2">
          <div className="list">
            {users.length === 0 && (
              <div className="card">
                <h3>Nenhum usuário cadastrado</h3>
                <small>Crie o primeiro usuário para iniciar.</small>
              </div>
            )}
            {users.map((item) => {
              const roleName = item.role_name || roleLabel(item.role);
              return (
                <div key={item.id} className="card">
                  <div className="inline" style={{ justifyContent: "space-between" }}>
                    <h3>{item.name || "Sem nome"}</h3>
                    {item.id === user?.id && <span className="badge">Você</span>}
                  </div>
                  <small>{item.email || "Sem e-mail"}</small>
                  <small>Cargo: {roleName}</small>
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
              );
            })}
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
              <p>Você pode visualizar os usuários, mas não tem permissão para editar.</p>
            </div>
          )}
        </div>
      </section>

      <section className="section">
        <div className="section-header">
          <h2 className="section-title">Cargos e permissões</h2>
          <span className="muted">Crie cargos personalizados e defina acessos</span>
        </div>

        <div className="grid-2">
          <div className="list">
            {roles.length === 0 && (
              <div className="card">
                <h3>Nenhum cargo cadastrado</h3>
                <small>Crie um cargo para organizar as permissões.</small>
              </div>
            )}
            {roles.map((role) => (
              <div key={role.id} className="card">
                <div className="inline" style={{ justifyContent: "space-between" }}>
                  <h3>{role.name}</h3>
                  <div className="inline">
                    {role.is_admin && <span className="badge">ADM</span>}
                    {reservedRoleKeys.has(role.key) && <span className="badge">Padrão</span>}
                  </div>
                </div>
                <small>Código: {role.key}</small>
                <small>
                  Permissões: {role.is_admin ? "Todas (ADM)" : role.permissions?.length || 0}
                </small>
                {canManageUsers && (
                  <div className="inline" style={{ marginTop: "12px" }}>
                    <button className="btn secondary" onClick={() => handleRoleEdit(role)}>
                      Editar
                    </button>
                    <button
                      className="btn ghost"
                      onClick={() => handleRoleDelete(role)}
                      disabled={reservedRoleKeys.has(role.key)}
                    >
                      Remover
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>

          {canManageUsers ? (
            <form className="card" onSubmit={handleRoleSubmit}>
              <h3>{activeRoleId ? "Editar cargo" : "Novo cargo"}</h3>
              <FormField
                label="Nome do cargo"
                value={roleForm.name}
                placeholder="Ex: Supervisor"
                onChange={(value) => setRoleForm((prev) => ({ ...prev, name: value }))}
              />
              <FormField
                label="Permissões de ADM"
                type="checkbox"
                value={roleForm.is_admin}
                onChange={(value) =>
                  setRoleForm((prev) => ({
                    ...prev,
                    is_admin: value,
                    permissions: value ? [] : prev.permissions
                  }))
                }
              />

              <div style={{ marginTop: "16px" }}>
                <h4 className="section-title">Permissões do cargo</h4>
                <div className="permission-grid" aria-disabled={roleForm.is_admin}>
                  {permissionOptions.map((option) => (
                    <label key={option.id} className="permission-item">
                      <input
                        type="checkbox"
                        checked={roleForm.permissions.includes(option.id)}
                        onChange={() => toggleRolePermission(option.id)}
                        disabled={roleForm.is_admin}
                      />
                      <span>{option.label}</span>
                    </label>
                  ))}
                </div>
                <small className="muted">
                  Ao ativar "Permissões de ADM", o cargo passa a ter acesso total.
                </small>
              </div>

              {roleError && <p className="muted">{roleError}</p>}
              <div className="inline" style={{ marginTop: "16px" }}>
                <button className="btn primary" type="submit">
                  {activeRoleId ? "Atualizar" : "Salvar"}
                </button>
                <button className="btn ghost" type="button" onClick={resetRoleForm}>
                  Limpar
                </button>
              </div>
            </form>
          ) : (
            <div className="card">
              <h3>Acesso somente leitura</h3>
              <p>Você pode visualizar os cargos, mas não tem permissão para editar.</p>
            </div>
          )}
        </div>
      </section>
    </>
  );
}
