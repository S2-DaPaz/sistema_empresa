import FormField from "../../../components/FormField";

export function TaskReportsTab({
  taskId,
  canManage,
  selectedTemplate,
  reportOptions,
  activeReportId,
  onReportSelect,
  reportStatus,
  reportStatusOptions,
  onReportStatusChange,
  activeReport,
  reportPhotos,
  onAddPhotos,
  onRemovePhoto,
  reportSections,
  reportLayoutStyle,
  renderReportField,
  reportMessage,
  onCreateReport,
  onDeleteReport,
  onSaveReport,
  formClientId,
  logo
}) {
  return (
    <div className="list">
      {!taskId && (
        <div className="card">
          <small>Salve a tarefa para habilitar o relatório.</small>
        </div>
      )}

      {taskId && !selectedTemplate && (
        <div className="card">
          <small>Este tipo de tarefa ainda não possui modelo de relatório.</small>
        </div>
      )}

      {taskId && selectedTemplate && reportOptions.length === 0 && (
        <div className="card">
          <div className="section-header">
            <h3 className="section-title">Relatórios da tarefa</h3>
            <div className="inline">
              <button className="btn primary" type="button" onClick={onCreateReport} disabled={!canManage}>
                Adicionar relatório
              </button>
            </div>
          </div>
          <small>Nenhum relatório cadastrado.</small>
          {!formClientId && <small>Selecione um cliente para criar o relatório.</small>}
          {reportMessage && <small className="muted">{reportMessage}</small>}
        </div>
      )}

      {taskId && reportOptions.length > 0 && (
        <div className="card">
          <div className="section-header">
            <div>
              <h3 className="section-title">Relatórios da tarefa</h3>
              <span className="muted">Selecione o relatório para editar</span>
            </div>
            <div className="inline">
              <button className="btn secondary" type="button" onClick={onCreateReport} disabled={!canManage}>
                Adicionar relatório
              </button>
              <button
                className="btn ghost"
                type="button"
                onClick={onDeleteReport}
                disabled={!canManage || !activeReport || activeReport.equipment_id}
              >
                Excluir relatório
              </button>
              <img className="report-logo" src={logo} alt="Logo" />
            </div>
          </div>

          <div className="form-grid">
            <FormField
              label="Relatório"
              type="select"
              value={activeReportId || ""}
              options={reportOptions}
              onChange={onReportSelect}
            />
            <FormField
              label="Status do relatório"
              type="select"
              value={reportStatus}
              options={reportStatusOptions}
              onChange={onReportStatusChange}
              disabled={!canManage}
            />
          </div>

          {activeReport?.equipment_id && (
            <small className="muted">Relatórios de equipamentos são gerenciados na aba Equipamentos.</small>
          )}

          <div className="section-divider" />
          <div className="section-header">
            <h3 className="section-title">Fotos</h3>
            <label className="btn secondary">
              Adicionar fotos
              <input
                type="file"
                accept="image/*"
                multiple
                onChange={(event) => onAddPhotos(event.target.files)}
                disabled={!canManage}
                hidden
              />
            </label>
          </div>

          {reportPhotos.length === 0 && <small>Sem fotos anexadas.</small>}
          {reportPhotos.length > 0 && (
            <div className="photo-grid">
              {reportPhotos.map((photo) => (
                <div key={photo.id} className="photo-card">
                  <img src={photo.dataUrl} alt={photo.name} />
                  <button className="btn ghost" type="button" onClick={() => onRemovePhoto(photo.id)} disabled={!canManage}>
                    Remover
                  </button>
                </div>
              ))}
            </div>
          )}

          <div className="section-divider" />
          <div className="section-header">
            <h3 className="section-title">Formulario</h3>
            <span className="muted">Preencha os dados do relatório</span>
          </div>

          {reportSections.length === 0 && <small>Este modelo ainda não possui campos.</small>}

          <div className="report-sections" style={reportLayoutStyle}>
            {reportSections.map((section) => (
              <div key={section.id} className="card">
                <h3>{section.title || "Seção"}</h3>
                <div className="report-section-fields">
                  {(section.fields || []).map((field) => renderReportField(field))}
                </div>
              </div>
            ))}
          </div>

          {reportMessage && <small className="muted">{reportMessage}</small>}
          <div className="inline" style={{ marginTop: "12px" }}>
            <button className="btn primary" type="button" onClick={onSaveReport} disabled={!canManage}>
              Salvar relatório
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
