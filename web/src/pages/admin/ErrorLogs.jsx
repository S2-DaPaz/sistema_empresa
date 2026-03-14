import { useEffect, useMemo, useState } from "react";
import { apiGet, apiPost } from "../../shared/api/http-client";
import { getFriendlyErrorMessage } from "../../shared/errors/error-normalizer";
import {
  buildQueryString,
  copyToClipboard,
  formatDateTime,
  formatUser,
  safeJson
} from "../../features/admin/logs/utils";

const DEFAULT_FILTERS = {
  search: "",
  severity: "",
  module: "",
  platform: "",
  resolved: "",
  dateFrom: "",
  dateTo: ""
};

function buildTechnicalSnapshot(log) {
  return [
    `ID: ${log.id}`,
    `Data: ${log.created_at}`,
    `Severidade: ${log.severity}`,
    `Código: ${log.error_code || "-"}`,
    `Request ID: ${log.request_id || "-"}`,
    `Endpoint: ${log.http_method || "-"} ${log.endpoint || "-"}`,
    "",
    "Mensagem técnica:",
    log.technical_message || "-",
    "",
    "Stack trace:",
    log.stack_trace || "-",
    "",
    "Contexto:",
    safeJson(log.context_json),
    "",
    "Payload:",
    safeJson(log.payload_json)
  ].join("\n");
}

export default function ErrorLogs() {
  const [filters, setFilters] = useState(DEFAULT_FILTERS);
  const [page, setPage] = useState(1);
  const [listState, setListState] = useState({
    items: [],
    meta: { total: 0, page: 1, pageSize: 20 },
    loading: true,
    error: ""
  });
  const [selectedId, setSelectedId] = useState(null);
  const [detailState, setDetailState] = useState({
    item: null,
    loading: false,
    error: ""
  });
  const [resolutionNote, setResolutionNote] = useState("");
  const [detailNotice, setDetailNotice] = useState("");

  const queryString = useMemo(() => buildQueryString(filters, page, 20), [filters, page]);

  useEffect(() => {
    let active = true;

    async function load() {
      setListState((prev) => ({ ...prev, loading: true, error: "" }));
      try {
        const result = await apiGet(`/admin/error-logs?${queryString}`, {
          withMeta: true
        });
        if (!active) return;
        setListState({
          items: result.data || [],
          meta: result.meta || { total: 0, page: 1, pageSize: 20 },
          loading: false,
          error: ""
        });
        setSelectedId((current) =>
          current && result.data.some((item) => item.id === current)
            ? current
            : result.data[0]?.id || null
        );
      } catch (error) {
        if (!active) return;
        setListState((prev) => ({
          ...prev,
          loading: false,
          error: getFriendlyErrorMessage(error, "Não foi possível carregar os logs de erro.")
        }));
      }
    }

    load();

    return () => {
      active = false;
    };
  }, [queryString]);

  useEffect(() => {
    if (!selectedId) {
      setDetailState({ item: null, loading: false, error: "" });
      setResolutionNote("");
      return;
    }

    let active = true;

    async function loadDetail() {
      setDetailState((prev) => ({ ...prev, loading: true, error: "" }));
      setDetailNotice("");
      try {
        const item = await apiGet(`/admin/error-logs/${selectedId}`);
        if (!active) return;
        setDetailState({ item, loading: false, error: "" });
        setResolutionNote(item.resolution_note || "");
      } catch (error) {
        if (!active) return;
        setDetailState({
          item: null,
          loading: false,
          error: getFriendlyErrorMessage(
            error,
            "Não foi possível carregar os detalhes do log."
          )
        });
      }
    }

    loadDetail();

    return () => {
      active = false;
    };
  }, [selectedId]);

  async function handleResolve() {
    if (!detailState.item) return;

    setDetailNotice("");
    try {
      const item = await apiPost(`/admin/error-logs/${detailState.item.id}/resolve`, {
        resolution_note: resolutionNote
      });
      setDetailState({ item, loading: false, error: "" });
      setDetailNotice("Log marcado como resolvido.");
      setListState((prev) => ({
        ...prev,
        items: prev.items.map((entry) => (entry.id === item.id ? { ...entry, ...item } : entry))
      }));
    } catch (error) {
      setDetailNotice(
        getFriendlyErrorMessage(error, "Não foi possível atualizar o status do log.")
      );
    }
  }

  async function handleCopy() {
    if (!detailState.item) return;
    const copied = await copyToClipboard(buildTechnicalSnapshot(detailState.item));
    setDetailNotice(
      copied
        ? "Detalhes copiados para a área de transferência."
        : "Não foi possível copiar os detalhes."
    );
  }

  function updateFilter(key, value) {
    setPage(1);
    setFilters((prev) => ({ ...prev, [key]: value }));
  }

  const totalPages = Math.max(
    1,
    Math.ceil((listState.meta.total || 0) / (listState.meta.pageSize || 20))
  );

  return (
    <section className="section">
      <div className="section-header">
        <div>
          <h2 className="section-title">Logs de erro</h2>
          <p className="muted">
            Falhas técnicas, erros de API e problemas reportados por web ou mobile.
          </p>
        </div>
        <span className="badge neutral">
          {listState.meta.total || 0} registro{listState.meta.total === 1 ? "" : "s"}
        </span>
      </div>

      <div className="monitoring-filters">
        <label className="form-field full">
          <span>Busca</span>
          <input
            type="search"
            value={filters.search}
            onChange={(event) => updateFilter("search", event.target.value)}
            placeholder="Mensagem, usuário, endpoint ou request ID"
          />
        </label>

        <label className="form-field">
          <span>Severidade</span>
          <select
            value={filters.severity}
            onChange={(event) => updateFilter("severity", event.target.value)}
          >
            <option value="">Todas</option>
            <option value="error">Erro</option>
            <option value="warning">Alerta</option>
          </select>
        </label>

        <label className="form-field">
          <span>Módulo</span>
          <input
            type="text"
            value={filters.module}
            onChange={(event) => updateFilter("module", event.target.value)}
            placeholder="tasks, budgets, auth..."
          />
        </label>

        <label className="form-field">
          <span>Plataforma</span>
          <select
            value={filters.platform}
            onChange={(event) => updateFilter("platform", event.target.value)}
          >
            <option value="">Todas</option>
            <option value="web">Web</option>
            <option value="mobile">Mobile</option>
            <option value="backend">Backend</option>
          </select>
        </label>

        <label className="form-field">
          <span>Status</span>
          <select
            value={filters.resolved}
            onChange={(event) => updateFilter("resolved", event.target.value)}
          >
            <option value="">Todos</option>
            <option value="false">Pendentes</option>
            <option value="true">Resolvidos</option>
          </select>
        </label>

        <label className="form-field">
          <span>De</span>
          <input
            type="date"
            value={filters.dateFrom}
            onChange={(event) => updateFilter("dateFrom", event.target.value)}
          />
        </label>

        <label className="form-field">
          <span>Até</span>
          <input
            type="date"
            value={filters.dateTo}
            onChange={(event) => updateFilter("dateTo", event.target.value)}
          />
        </label>
      </div>

      {listState.error && <div className="banner banner-error">{listState.error}</div>}

      <div className="monitoring-layout">
        <div className="card monitoring-list">
          <div className="table-wrap">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Data</th>
                  <th>Severidade</th>
                  <th>Mensagem</th>
                  <th>Módulo</th>
                  <th>Usuário</th>
                  <th>Plataforma</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {listState.loading ? (
                  <tr>
                    <td colSpan="7" className="table-empty">
                      Carregando logs...
                    </td>
                  </tr>
                ) : listState.items.length === 0 ? (
                  <tr>
                    <td colSpan="7" className="table-empty">
                      Nenhum log encontrado com os filtros atuais.
                    </td>
                  </tr>
                ) : (
                  listState.items.map((item) => (
                    <tr
                      key={item.id}
                      className={item.id === selectedId ? "is-selected" : ""}
                      onClick={() => setSelectedId(item.id)}
                    >
                      <td>{formatDateTime(item.created_at)}</td>
                      <td>
                        <span className={`badge tone-${item.severity || "neutral"}`}>
                          {item.severity || "erro"}
                        </span>
                      </td>
                      <td>{item.friendly_message}</td>
                      <td>{item.module || "-"}</td>
                      <td>{formatUser(item)}</td>
                      <td>{item.platform || "-"}</td>
                      <td>
                        <span
                          className={`badge ${item.resolved_at ? "tone-success" : "tone-warning"}`}
                        >
                          {item.resolved_at ? "Resolvido" : "Pendente"}
                        </span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>

          <div className="pagination-row">
            <span className="muted">
              Página {listState.meta.page || 1} de {totalPages}
            </span>
            <div className="inline">
              <button
                className="btn ghost"
                type="button"
                onClick={() => setPage((prev) => Math.max(1, prev - 1))}
                disabled={page <= 1}
              >
                Anterior
              </button>
              <button
                className="btn ghost"
                type="button"
                onClick={() => setPage((prev) => Math.min(totalPages, prev + 1))}
                disabled={page >= totalPages}
              >
                Próxima
              </button>
            </div>
          </div>
        </div>

        <div className="card monitoring-detail">
          {!selectedId ? (
            <div className="empty-state">
              <h3>Selecione um log</h3>
              <p className="muted">
                Escolha um item da lista para inspecionar os detalhes técnicos.
              </p>
            </div>
          ) : detailState.loading ? (
            <div className="empty-state">
              <h3>Carregando detalhes</h3>
              <p className="muted">Buscando stack trace, contexto e payload seguro.</p>
            </div>
          ) : detailState.error ? (
            <div className="banner banner-error">{detailState.error}</div>
          ) : (
            detailState.item && (
              <>
                <div className="section-header">
                  <div>
                    <h3 className="section-title">Log #{detailState.item.id}</h3>
                    <p className="muted">{detailState.item.friendly_message}</p>
                  </div>
                  <div className="inline">
                    <button className="btn secondary" type="button" onClick={handleCopy}>
                      Copiar detalhes
                    </button>
                    {!detailState.item.resolved_at && (
                      <button className="btn primary" type="button" onClick={handleResolve}>
                        Marcar como resolvido
                      </button>
                    )}
                  </div>
                </div>

                {detailNotice && <div className="banner banner-info">{detailNotice}</div>}

                <div className="detail-grid">
                  <div className="card soft">
                    <small className="muted">Data</small>
                    <strong>{formatDateTime(detailState.item.created_at)}</strong>
                  </div>
                  <div className="card soft">
                    <small className="muted">Endpoint</small>
                    <strong>
                      {detailState.item.http_method || "-"} {detailState.item.endpoint || "-"}
                    </strong>
                  </div>
                  <div className="card soft">
                    <small className="muted">Usuário</small>
                    <strong>{formatUser(detailState.item)}</strong>
                  </div>
                  <div className="card soft">
                    <small className="muted">Request ID</small>
                    <strong>{detailState.item.request_id || "-"}</strong>
                  </div>
                </div>

                <div className="form-grid">
                  <label className="form-field full">
                    <span>Mensagem técnica</span>
                    <textarea readOnly value={detailState.item.technical_message || "-"} />
                  </label>

                  <label className="form-field full">
                    <span>Stack trace</span>
                    <textarea readOnly value={detailState.item.stack_trace || "Sem stack trace."} />
                  </label>

                  <label className="form-field full">
                    <span>Contexto</span>
                    <textarea readOnly value={safeJson(detailState.item.context_json)} />
                  </label>

                  <label className="form-field full">
                    <span>Payload seguro</span>
                    <textarea readOnly value={safeJson(detailState.item.payload_json)} />
                  </label>

                  <label className="form-field full">
                    <span>Nota de resolução</span>
                    <textarea
                      value={resolutionNote}
                      onChange={(event) => setResolutionNote(event.target.value)}
                      placeholder="Descreva a causa raiz, a correção aplicada ou o acompanhamento."
                    />
                  </label>
                </div>
              </>
            )
          )}
        </div>
      </div>
    </section>
  );
}
