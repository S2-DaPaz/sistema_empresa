import FormField from "../../../components/FormField";
import SignaturePad from "../../../components/SignaturePad";

export function TaskSignaturesTab({
  taskId,
  canManage,
  signatureMode,
  setSignatureMode,
  signatureScope,
  setSignatureScope,
  signatureModeOptions,
  signatureScopeOptions,
  signatureClient,
  setSignatureClient,
  signatureTech,
  setSignatureTech,
  signaturePageItems,
  signaturePages,
  updateSignaturePage,
  onSaveTask
}) {
  return (
    <div className="list">
      {!taskId && (
        <div className="card">
          <small>Salve a tarefa para configurar assinaturas.</small>
        </div>
      )}

      {taskId && (
        <div className="card">
          <div className="section-header">
            <h3 className="section-title">Assinaturas do PDF</h3>
          </div>
          <div className="form-grid">
            <FormField
              label="Assinaturas"
              type="select"
              value={signatureMode}
              options={signatureModeOptions}
              onChange={setSignatureMode}
              disabled={!canManage}
            />
            <FormField
              label="Aplicação"
              type="select"
              value={signatureScope}
              options={signatureScopeOptions}
              onChange={setSignatureScope}
              disabled={!canManage}
            />
          </div>

          {signatureScope === "last_page" && (
            <>
              {(signatureMode === "client" || signatureMode === "both") && (
                <div className="card">
                  <h3>Assinatura do cliente</h3>
                  <SignaturePad value={signatureClient} onChange={setSignatureClient} disabled={!canManage} />
                  {canManage && signatureClient && (
                    <button className="btn ghost" type="button" onClick={() => setSignatureClient("")}>
                      Remover assinatura
                    </button>
                  )}
                </div>
              )}

              {(signatureMode === "tech" || signatureMode === "both") && (
                <div className="card">
                  <h3>Assinatura do técnico</h3>
                  <SignaturePad value={signatureTech} onChange={setSignatureTech} disabled={!canManage} />
                  {canManage && signatureTech && (
                    <button className="btn ghost" type="button" onClick={() => setSignatureTech("")}>
                      Remover assinatura
                    </button>
                  )}
                </div>
              )}
            </>
          )}

          {signatureScope === "all_pages" && (
            <>
              {signaturePageItems.length === 0 && <small>Nenhuma página disponível para assinatura por etapa.</small>}
              {signaturePageItems.map((page) => {
                const pageSignature = signaturePages[page.key] || {};
                return (
                  <div key={page.key} className="card">
                    <h3>{page.label}</h3>
                    {(signatureMode === "client" || signatureMode === "both") && (
                      <>
                        <h4>Assinatura do cliente</h4>
                        <SignaturePad
                          value={pageSignature.client || ""}
                          onChange={(value) => updateSignaturePage(page.key, "client", value)}
                          disabled={!canManage}
                        />
                      </>
                    )}
                    {(signatureMode === "tech" || signatureMode === "both") && (
                      <>
                        <h4>Assinatura do técnico</h4>
                        <SignaturePad
                          value={pageSignature.tech || ""}
                          onChange={(value) => updateSignaturePage(page.key, "tech", value)}
                          disabled={!canManage}
                        />
                      </>
                    )}
                  </div>
                );
              })}
            </>
          )}

          <div className="inline" style={{ marginTop: "12px" }}>
            <button className="btn primary" type="button" onClick={onSaveTask} disabled={!canManage}>
              Salvar assinaturas
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
