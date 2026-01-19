import { useEffect, useState } from "react";
import { apiGet } from "../api";

export default function Dashboard() {
  const [summary, setSummary] = useState(null);
  const [recentReports, setRecentReports] = useState([]);

  useEffect(() => {
    async function load() {
      try {
        const [summaryData, reports] = await Promise.all([
          apiGet("/summary"),
          apiGet("/reports")
        ]);
        setSummary(summaryData);
        setRecentReports((reports || []).slice(0, 4));
      } catch (err) {
        setSummary(null);
        setRecentReports([]);
      }
    }

    load();
  }, []);

  return (
    <div className="content">
      <section className="section">
        <div className="section-header">
          <h2 className="section-title">Painel</h2>
        </div>
        <div className="grid-3 stagger">
          <div className="card">
            <h3>Clientes</h3>
            <small>Total cadastrado</small>
            <p className="badge">{summary?.clients ?? 0}</p>
          </div>
          <div className="card">
            <h3>Tarefas</h3>
            <small>Operações em andamento</small>
            <p className="badge">{summary?.tasks ?? 0}</p>
          </div>
          <div className="card">
            <h3>Relatórios</h3>
            <small>Últimos registros</small>
            <p className="badge">{summary?.reports ?? 0}</p>
          </div>
        </div>
      </section>

      <section className="section">
        <div className="section-header">
          <h2 className="section-title">Últimos relatórios</h2>
        </div>
        <div className="list">
          {recentReports.length === 0 && (
            <div className="card">
              <h3>Nenhum relatório</h3>
              <small>Crie seu primeiro relatório personalizado.</small>
            </div>
          )}
          {recentReports.map((report) => (
            <div key={report.id} className="card">
              <h3>{report.title || report.template_name || "Relatório"}</h3>
              <small>
                {report.client_name ? `Cliente: ${report.client_name}` : "Sem cliente"}{" "}
                {report.created_at ? `| ${report.created_at.slice(0, 10)}` : ""}
              </small>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
