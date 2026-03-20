import FormField from "../../../components/FormField";

export function TaskDetailsTab({
  taskId,
  canManage,
  form,
  setForm,
  clients,
  users,
  types,
  taskStatusOptions,
  taskPriorityOptions,
  onSubmit
}) {
  return (
    <form className="card" onSubmit={onSubmit}>
      <div className="inline" style={{ justifyContent: "space-between" }}>
        <h3>Detalhes da tarefa</h3>
        <span className="badge">{taskId ? `#${taskId}` : "Nova"}</span>
      </div>
      {!canManage && <small className="muted">Somente leitura.</small>}
      <fieldset style={{ border: "none", padding: 0, margin: 0 }} disabled={!canManage}>
        <div className="form-grid">
          <FormField
            label="Titulo"
            value={form.title}
            onChange={(value) => setForm((prev) => ({ ...prev, title: value }))}
          />
          <FormField
            label="Status"
            type="select"
            value={form.status}
            options={taskStatusOptions}
            onChange={(value) => setForm((prev) => ({ ...prev, status: value }))}
          />
          <FormField
            label="Prioridade"
            type="select"
            value={form.priority}
            options={taskPriorityOptions}
            onChange={(value) => setForm((prev) => ({ ...prev, priority: value }))}
          />
          <FormField
            label="Cliente"
            type="select"
            value={form.client_id}
            options={clients.map((clientItem) => ({
              value: clientItem.id,
              label: clientItem.name
            }))}
            onChange={(value) => setForm((prev) => ({ ...prev, client_id: value }))}
          />
          <FormField
            label="Responsavel"
            type="select"
            value={form.user_id}
            options={users.map((user) => ({ value: user.id, label: user.name }))}
            onChange={(value) => setForm((prev) => ({ ...prev, user_id: value }))}
          />
          <FormField
            label="Tipo de tarefa"
            type="select"
            value={form.task_type_id}
            options={types.map((type) => ({ value: type.id, label: type.name }))}
            onChange={(value) => setForm((prev) => ({ ...prev, task_type_id: value }))}
          />
          <FormField
            label="Inicio"
            type="date-br"
            value={form.start_date}
            onChange={(value) => setForm((prev) => ({ ...prev, start_date: value }))}
          />
          <FormField
            label="Fim"
            type="date-br"
            value={form.due_date}
            onChange={(value) => setForm((prev) => ({ ...prev, due_date: value }))}
          />
          <FormField
            label="Descrição"
            type="textarea"
            value={form.description}
            onChange={(value) => setForm((prev) => ({ ...prev, description: value }))}
            className="full"
          />
        </div>
        <div className="inline" style={{ marginTop: "16px" }}>
          <button className="btn primary" type="submit" disabled={!canManage}>
            {taskId ? "Atualizar" : "Salvar"}
          </button>
        </div>
      </fieldset>
    </form>
  );
}
