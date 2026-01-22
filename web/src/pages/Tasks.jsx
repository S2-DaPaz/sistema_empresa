import { useEffect, useMemo, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { apiDelete, apiGet } from "../api";
import { PERMISSIONS, useAuth } from "../contexts/AuthContext";

function formatDateKey(value) {
  if (!value) return null;
  return value.slice(0, 10);
}

function getTaskDate(task) {
  return formatDateKey(task.start_date || task.due_date || "");
}

function formatDateFromDate(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function getMonthLabel(date) {
  return date.toLocaleDateString("pt-BR", { month: "long", year: "numeric" });
}

function buildCalendarDays(monthDate) {
  const year = monthDate.getFullYear();
  const month = monthDate.getMonth();
  const firstDay = new Date(year, month, 1);
  const startOffset = firstDay.getDay();
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const days = [];

  for (let i = 0; i < startOffset; i += 1) {
    days.push(null);
  }

  for (let day = 1; day <= daysInMonth; day += 1) {
    days.push(new Date(year, month, day));
  }

  while (days.length % 7 !== 0) {
    days.push(null);
  }

  return days;
}

function normalizeText(value) {
  if (!value) return "";
  return value
    .toString()
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "");
}

export default function Tasks() {
  const navigate = useNavigate();
  const { hasPermission } = useAuth();
  const canView = hasPermission(PERMISSIONS.VIEW_TASKS);
  const canManage = hasPermission(PERMISSIONS.MANAGE_TASKS);
  const [searchParams] = useSearchParams();

  const [tasks, setTasks] = useState([]);
  const [viewMode, setViewMode] = useState("list");
  const [calendarMonth, setCalendarMonth] = useState(new Date());
  const [selectedDate, setSelectedDate] = useState(null);
  const [error, setError] = useState("");

  const statusLabels = {
    aberta: "Aberta",
    em_andamento: "Em andamento",
    concluida: "Concluída"
  };
  const priorityLabels = {
    alta: "Alta",
    media: "Média",
    baixa: "Baixa"
  };

  const searchTerm = searchParams.get("q") || "";
  const statusFilter = searchParams.get("status") || "all";
  const priorityFilter = searchParams.get("priority") || "all";

  function formatStatus(value) {
    return statusLabels[value] || value || "Aberta";
  }

  function formatPriority(value) {
    return priorityLabels[value] || value || "Média";
  }

  async function loadTasks() {
    try {
      const data = await apiGet("/tasks");
      setTasks(data || []);
    } catch (err) {
      setError(err.message || "Falha ao carregar tarefas");
    }
  }

  useEffect(() => {
    if (canView) {
      loadTasks();
    }
  }, [canView]);

  async function handleDelete(id) {
    if (!canManage) return;
    setError("");
    if (!window.confirm("Remover esta tarefa?")) return;
    try {
      await apiDelete(`/tasks/${id}`);
      await loadTasks();
    } catch (err) {
      setError(err.message || "Falha ao remover");
    }
  }

  const filteredTasks = useMemo(() => {
    const query = normalizeText(searchTerm.trim());
    return tasks.filter((task) => {
      const matchesStatus = statusFilter === "all" || task.status === statusFilter;
      const matchesPriority = priorityFilter === "all" || task.priority === priorityFilter;
      if (!matchesStatus || !matchesPriority) return false;
      if (!query) return true;
      const haystack = [
        task.title,
        task.client_name,
        task.task_type_name,
        task.id?.toString()
      ]
        .map(normalizeText)
        .join(" ");
      return haystack.includes(query);
    });
  }, [tasks, searchTerm, statusFilter, priorityFilter]);

  const tasksByDate = useMemo(() => {
    return filteredTasks.reduce((acc, task) => {
      const key = getTaskDate(task);
      if (!key) return acc;
      if (!acc[key]) acc[key] = [];
      acc[key].push(task);
      return acc;
    }, {});
  }, [filteredTasks]);

  const calendarDays = useMemo(() => buildCalendarDays(calendarMonth), [calendarMonth]);

  const tasksForSelectedDate = useMemo(() => {
    if (!selectedDate) return [];
    return tasksByDate[selectedDate] || [];
  }, [selectedDate, tasksByDate]);

  if (!canView) {
    return (
      <section className="section">
        <div className="section-header">
          <h2 className="section-title">Tarefas</h2>
        </div>
        <div className="card">
          <p>Você não tem permissão para visualizar tarefas.</p>
        </div>
      </section>
    );
  }

  return (
    <section className="section">
      <div className="section-header">
        <h2 className="section-title">Tarefas</h2>
        <div className="inline">
          <button
            className={`btn ${viewMode === "list" ? "primary" : "secondary"}`}
            type="button"
            onClick={() => setViewMode("list")}
          >
            Lista
          </button>
          <button
            className={`btn ${viewMode === "calendar" ? "primary" : "secondary"}`}
            type="button"
            onClick={() => setViewMode("calendar")}
          >
            Calendário
          </button>
          {canManage && (
            <button
              className="btn primary"
              type="button"
              onClick={() => navigate("/tarefas/nova")}
            >
              Nova tarefa
            </button>
          )}
        </div>
      </div>

      {error && <p className="muted">{error}</p>}

      {viewMode === "calendar" && (
        <div className="card">
          <div className="calendar-header">
            <button
              className="btn ghost"
              type="button"
              onClick={() => {
                const next = new Date(calendarMonth);
                next.setMonth(calendarMonth.getMonth() - 1);
                setCalendarMonth(next);
              }}
            >
              Mês anterior
            </button>
            <strong>{getMonthLabel(calendarMonth)}</strong>
            <button
              className="btn ghost"
              type="button"
              onClick={() => {
                const next = new Date(calendarMonth);
                next.setMonth(calendarMonth.getMonth() + 1);
                setCalendarMonth(next);
              }}
            >
              Próximo mês
            </button>
          </div>
          <div className="calendar-grid">
            {["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"].map((day) => (
              <div key={day} className="calendar-head">
                {day}
              </div>
            ))}
            {calendarDays.map((date, index) => {
              if (!date) {
                return <div key={`empty-${index}`} className="calendar-day is-empty" />;
              }
              const key = formatDateFromDate(date);
              const count = tasksByDate[key]?.length || 0;
              const isSelected = selectedDate === key;
              return (
                <button
                  key={key}
                  type="button"
                  className={`calendar-day ${isSelected ? "is-selected" : ""}`}
                  onClick={() => setSelectedDate(key)}
                >
                  <span>{date.getDate()}</span>
                  {count > 0 && <span className="calendar-count">{count}</span>}
                </button>
              );
            })}
          </div>
          <div className="list" style={{ marginTop: "16px" }}>
            {!selectedDate && filteredTasks.length === 0 && (
              <div className="card">
                <small>Nenhuma tarefa com os filtros atuais.</small>
              </div>
            )}
            {selectedDate && tasksForSelectedDate.length === 0 && (
              <div className="card">
                <small>Nenhuma tarefa para este dia.</small>
              </div>
            )}
            {tasksForSelectedDate.map((task) => (
              <div key={task.id} className="card">
                <h3>{task.title}</h3>
                <small>
                  {task.client_name ? `Cliente: ${task.client_name}` : "Sem cliente"}
                </small>
                <div className="inline" style={{ marginTop: "8px" }}>
                  <span className="badge">{formatStatus(task.status)}</span>
                  <span className="badge">{formatPriority(task.priority)}</span>
                </div>
                <div className="inline" style={{ marginTop: "12px" }}>
                  <button
                    className="btn secondary"
                    onClick={() => navigate(`/tarefas/${task.id}`)}
                  >
                    Abrir
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {viewMode === "list" && (
        <div className="list">
          {filteredTasks.length === 0 && (
            <div className="card">
              <h3>{tasks.length === 0 ? "Nenhuma tarefa" : "Nenhuma tarefa encontrada"}</h3>
              <small>
                {tasks.length === 0
                  ? "Cadastre a primeira tarefa para iniciar."
                  : "Ajuste a busca ou os filtros para ver resultados."}
              </small>
            </div>
          )}
          {filteredTasks.map((task) => (
            <div key={task.id} className="card">
              <h3>{task.title}</h3>
              <small>
                {task.client_name ? `Cliente: ${task.client_name}` : "Sem cliente"} |{" "}
                {task.task_type_name || "Sem tipo"}
              </small>
              <div className="inline" style={{ marginTop: "8px" }}>
                <span className="badge">{formatStatus(task.status)}</span>
                <span className="badge">{formatPriority(task.priority)}</span>
              </div>
              <div className="inline" style={{ marginTop: "12px" }}>
                <button
                  className="btn secondary"
                  onClick={() => navigate(`/tarefas/${task.id}`)}
                >
                  Abrir
                </button>
                {canManage && (
                  <button className="btn ghost" onClick={() => handleDelete(task.id)}>
                    Remover
                  </button>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </section>
  );
}
