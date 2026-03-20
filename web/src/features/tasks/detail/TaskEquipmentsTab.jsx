import FormField from "../../../components/FormField";

export function TaskEquipmentsTab({
  taskId,
  taskEquipments,
  canManage,
  onOpenEquipmentReport,
  onDetachEquipment,
  selectedEquipmentId,
  setSelectedEquipmentId,
  equipments,
  onAttachEquipment,
  newEquipment,
  setNewEquipment,
  onCreateEquipment
}) {
  return (
    <div className="list">
      {!taskId && (
        <div className="card">
          <small>Salve a tarefa para adicionar equipamentos.</small>
        </div>
      )}

      {taskId && (
        <>
          <div className="card">
            <div className="section-header">
              <h3 className="section-title">Equipamentos da tarefa</h3>
            </div>
            {taskEquipments.length === 0 && <small>Nenhum equipamento vinculado.</small>}
            {taskEquipments.map((equipment) => (
              <div key={equipment.id} className="card">
                <div className="inline" style={{ justifyContent: "space-between" }}>
                  <strong>{equipment.name}</strong>
                  <span className="badge">{equipment.model || "Sem modelo"}</span>
                </div>
                <small>Serie: {equipment.serial || "-"}</small>
                {equipment.description && <small>{equipment.description}</small>}
                <div className="inline" style={{ marginTop: "10px" }}>
                  <button className="btn secondary" type="button" onClick={() => onOpenEquipmentReport(equipment.id)}>
                    Abrir relatório
                  </button>
                  <button className="btn ghost" type="button" onClick={() => onDetachEquipment(equipment.id)} disabled={!canManage}>
                    Remover
                  </button>
                </div>
              </div>
            ))}
          </div>

          <div className="card">
            <div className="section-header">
              <h3 className="section-title">Vincular equipamento existente</h3>
            </div>
            <div className="form-grid">
              <FormField
                label="Equipamento"
                type="select"
                value={selectedEquipmentId}
                options={equipments.map((item) => ({ value: item.id, label: item.name }))}
                onChange={setSelectedEquipmentId}
                disabled={!canManage}
              />
            </div>
            <div className="inline" style={{ marginTop: "12px" }}>
              <button className="btn secondary" type="button" onClick={onAttachEquipment} disabled={!canManage}>
                Vincular
              </button>
            </div>
          </div>

          <div className="card">
            <div className="section-header">
              <h3 className="section-title">Cadastrar novo equipamento</h3>
            </div>
            <div className="form-grid">
              <FormField
                label="Nome"
                value={newEquipment.name}
                onChange={(value) => setNewEquipment((prev) => ({ ...prev, name: value }))}
                disabled={!canManage}
              />
              <FormField
                label="Modelo"
                value={newEquipment.model}
                onChange={(value) => setNewEquipment((prev) => ({ ...prev, model: value }))}
                disabled={!canManage}
              />
              <FormField
                label="Serie"
                value={newEquipment.serial}
                onChange={(value) => setNewEquipment((prev) => ({ ...prev, serial: value }))}
                disabled={!canManage}
              />
              <FormField
                label="Descrição"
                type="textarea"
                value={newEquipment.description}
                onChange={(value) => setNewEquipment((prev) => ({ ...prev, description: value }))}
                className="full"
                disabled={!canManage}
              />
            </div>
            <div className="inline" style={{ marginTop: "12px" }}>
              <button className="btn primary" type="button" onClick={onCreateEquipment} disabled={!canManage}>
                Cadastrar e vincular
              </button>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
