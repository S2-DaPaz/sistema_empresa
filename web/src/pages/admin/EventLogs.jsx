import { useEffect, useMemo, useState } from "react";
import { apiGet } from "../../shared/api/http-client";
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
  action: "",
  module: "",
  platform: "",
  outcome: "",
  dateFrom: "",
  dateTo: ""
};

function buildEventSnapshot(log) {
  return [
    `ID: ${log.id}`,
    `Data: ${log.created_at}`,
    `Acao: ${log.action}`,
    `Resultado: ${log.outcome}`,
    `Usuario: ${formatUser(log)}`,
    `Rota: ${log.http_method || "-"} ${log.route_path || "-"}`,
    "",
    "Descricao:",
    log.description || "-",
    "",
    "Metadata:",
    safeJson(log.metadata_json),
    "",
    "Antes:",
    safeJson(log.before_json),
    "",
    "Depois:",
    safeJson(log.after_json)
  ].join("\n");
}

export default function EventLogs() {
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
    error: "",
    notice: ""
  });

  const queryString = useMemo(
    () => buildQueryString(filters, page, 20),
    [filters, page]
  );

  useEffect(() => {
    let active = true;

    async function load() {
      setListState((prev) => ({ ...prev, loading: true, error: "" }));
      try {
        const result = await apiGet(`/admin/event-logs?${queryString}`, {
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
          error: getFriendlyErrorMessage(error, "Nao foi possivel carregar o log de eventos.")
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
      setDetailState({ item: null, loading: false, error: "", notice: "" });
      return;
    }

    let active = true;

    async function loadDetail() {
      setDetailState((prev) => ({ ...prev, loading: true, error: "", notice: "" }));
      try {
        const item = await apiGet(`/admin/event-logs/${selectedId}`);
        if (!active) return;
        setDetailState({ item, loading: false, error: "", notice: "" });
      } catch (error) {
        if (!active) return;
        setDetailState({
          item: null,
          loading: false,
          error: getFriendlyErrorMessage(error, "Nao foi possivel carregar o evento."),
          notice: ""
        });
      }
    }

    loadDetail();

    return () => {
      active = false;
    };
  }, [selectedId]);

  function updateFilter(key, value) {
    setPage(1);
    setFilters((prev) => ({ ...prev, [key]: value }));
  }

  async function handleCopy() {
    if (!detailState.item) return;
    const copied = await copyToClipboard(buildEventSnapshot(detailState.item));
    setDetailState((prev) => ({
      ...prev,
      notice: copied
        ? "Detalhes copiados para a area de transferencia."
        : "Nao foi possivel copiar os detalhes."
    }));
  }

  const totalPages = Math.max(
    1,
    Math.ceil((listState.meta.total || 0) / (listState.meta.pageSize || 20))
  );

  return (
    <section className="section">
      <div className="section-header">
        <div>
          <h2 className="section-title">Log de eventos</h2>
          <p className="muted">
            Auditoria operacional com rastreio de usuario, entidade afetada e resultado.
          </p>
        </div>
        <span className="badge neutral">
          {listState.meta.total || 0} evento{listState.meta.total === 1 ? "" : "s"}
        </span>
      </div>

      <div className="monitoring-filters">
        <label className="form-field full">
          <span>Busca</span>
          <input
            type="search"
            value={filters.search}
            onChange={(event) => updateFilter("search", event.target.value)}
            placeholder="Acao, usuario, descricao ou entidade"
          />
        </label>

        <label className="form-field">
          <span>Acao</span>
          <input
            type="text"
            value={filters.action}
            onChange={(event) => updateFilter("action", event.target.value)}
            placeholder="TASK_UPDATED"
          />
        </label>

        <label className="form-field">
          <span>Modulo</span>
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
          <span>Resultado</span>
          <select
            value={filters.outcome}
            onChange={(event) => updateFilter("outcome", event.target.value)}
          >
            <option value="">Todos</option>
            <option value="success">Sucesso</option>
            <option value="failure">Falha</option>
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
          <span>Ate</span>
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
                  <th>Acao</th>
                  <th>Descricao</th>
                  <th>Usuario</th>
                  <th>Modulo</th>
                  <th>Plataforma</th>
                  <th>Resultado</th>
                </tr>
              </thead>
              <tbody>
                {listState.loading ? (
                  <tr>
                    <td colSpan="7" className="table-empty">
                      Carregando eventos...
                    </td>
                  </tr>
                ) : listState.items.length === 0 ? (
                  <tr>
                    <td colSpan="7" className="table-empty">
                      Nenhum evento encontrado com os filtros atuais.
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
                      <td>{item.action}</td>
                      <td>{item.description}</td>
                      <td>{formatUser(item)}</td>
                      <td>{item.module || "-"}</td>
                      <td>{item.platform || "-"}</td>
                      <td>
                        <span className={`badge ${item.outcome === "success" ? "tone-success" : "tone-warning"}`}>
                          {item.outcome === "success" ? "Sucesso" : "Falha"}
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
              Pagina {listState.meta.page || 1} de {totalPages}
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
                Proxima
              </button>
            </div>
          </div>
        </div>

        <div className="card monitoring-detail">
          {!selectedId ? (
            <div className="empty-state">
              <h3>Selecione um evento</h3>
              <p className="muted">Abra um registro para ver a trilha de auditoria completa.</p>
            </div>
          ) : detailState.loading ? (
            <div className="empty-state">
              <h3>Carregando detalhes</h3>
              <p className="muted">Buscando metadata, antes/depois e resultado da operacao.</p>
            </div>
          ) : detailState.error ? (
            <div className="banner banner-error">{detailState.error}</div>
          ) : (
            detailState.item && (
              <>
                <div className="section-header">
                  <div>
                    <h3 className="section-title">{detailState.item.action}</h3>
                    <p className="muted">{detailState.item.description}</p>
                  </div>
                  <button className="btn secondary" type="button" onClick={handleCopy}>
                    Copiar detalhes
                  </button>
                </div>

                {detailState.notice && <div className="banner banner-info">{detailState.notice}</div>}

                <div className="detail-grid">
                  <div className="card soft">
                    <small className="muted">Data</small>
                    <strong>{formatDateTime(detailState.item.created_at)}</strong>
                  </div>
                  <div className="card soft">
                    <small className="muted">Usuario</small>
                    <strong>{formatUser(detailState.item)}</strong>
                  </div>
                  <div className="card soft">
                    <small className="muted">Entidade</small>
                    <strong>
                      {detailState.item.entity_type || "-"} #{detailState.item.entity_id || "-"}
                    </strong>
                  </div>
                  <div className="card soft">
                    <small className="muted">Rota</small>
                    <strong>
                      {detailState.item.http_method || "-"} {detailState.item.route_path || "-"}
                    </strong>
                  </div>
                </div>

                <div className="form-grid">
                  <label className="form-field full">
                    <span>Metadata</span>
                    <textarea readOnly value={safeJson(detailState.item.metadata_json)} />
                  </label>

                  <label className="form-field full">
                    <span>Antes</span>
                    <textarea readOnly value={safeJson(detailState.item.before_json)} />
                  </label>

                  <label className="form-field full">
                    <span>Depois</span>
                    <textarea readOnly value={safeJson(detailState.item.after_json)} />
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
