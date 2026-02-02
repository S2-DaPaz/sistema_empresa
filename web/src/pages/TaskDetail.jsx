import { useEffect, useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { apiDelete, apiGet, apiPost, apiPut } from "../api";
import { PERMISSIONS, useAuth } from "../contexts/AuthContext";
import BudgetForm from "../components/BudgetForm";
import FormField from "../components/FormField";
import SignaturePad from "../components/SignaturePad";
import { buildTaskPdfHtml, openPrintWindow } from "../utils/pdf";
import logo from "../assets/Logo.png";

const statusOptions = [
  { value: "aberta", label: "Aberta" },
  { value: "em_andamento", label: "Em andamento" },
  { value: "concluida", label: "Concluída" }
];

const priorityOptions = [
  { value: "alta", label: "Alta" },
  { value: "media", label: "Média" },
  { value: "baixa", label: "Baixa" }
];

const reportStatusOptions = [
  { value: "rascunho", label: "Rascunho" },
  { value: "enviado", label: "Enviado" },
  { value: "finalizado", label: "Finalizado" }
];

const signatureModeOptions = [
  { value: "none", label: "Sem assinatura" },
  { value: "client", label: "Cliente" },
  { value: "tech", label: "Técnico" },
  { value: "both", label: "Cliente e Técnico" }
];

const signatureScopeOptions = [
  { value: "all_pages", label: "Assinar todas as páginas" },
  { value: "last_page", label: "Assinar apenas no final" }
];

const tabs = [
  { id: "detalhes", label: "Detalhes da tarefa" },
  { id: "relatorio", label: "Relatório" },
  { id: "orcamentos", label: "Orçamentos" },
  { id: "equipamentos", label: "Equipamentos" },
  { id: "assinaturas", label: "Assinaturas" }
];

function uid() {
  if (typeof crypto !== "undefined" && crypto.randomUUID) {
    return crypto.randomUUID();
  }
  return `id_${Date.now()}_${Math.random().toString(16).slice(2)}`;
}

function buildReportText({ reportTitle, taskTitle, clientName, equipmentName, sections, answers }) {
  const formatAnswer = (field, value) => {
    if (field.type === "checkbox") return value ? "Sim" : "Não";
    if (field.type === "yesno") {
      if (value === "sim") return "Sim";
      if (value === "nao") return "Não";
      return "-";
    }
    if (value === 0 || value === "0") return "0";
    return value || "-";
  };

  const lines = [];
  lines.push(`Relatório: ${reportTitle || taskTitle || "Relatório"}`);
  if (clientName) {
    lines.push(`Cliente: ${clientName}`);
  }
  if (equipmentName) {
    lines.push(`Equipamento: ${equipmentName}`);
  }
  lines.push("");

  (sections || []).forEach((section) => {
    lines.push(section.title || "Seção");
    (section.fields || []).forEach((field) => {
      const value = answers?.[field.id];
      lines.push(`- ${field.label}: ${formatAnswer(field, value)}`);
    });
    lines.push("");
  });

  return lines.join("\n");
}

export default function TaskDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { user, hasPermission } = useAuth();
  const isNew = id === "nova";
  const [taskId, setTaskId] = useState(isNew ? null : Number(id));
  const [activeTab, setActiveTab] = useState("detalhes");
  const canView = hasPermission(PERMISSIONS.VIEW_TASKS);
  const canManage = hasPermission(PERMISSIONS.MANAGE_TASKS);
  const canManageBudgets = hasPermission(PERMISSIONS.MANAGE_BUDGETS);

  const [clients, setClients] = useState([]);
  const [users, setUsers] = useState([]);
  const [types, setTypes] = useState([]);
  const [templates, setTemplates] = useState([]);
  const [products, setProducts] = useState([]);
  const [equipments, setEquipments] = useState([]);
  const [taskEquipments, setTaskEquipments] = useState([]);

  const [reports, setReports] = useState([]);
  const [activeReportId, setActiveReportId] = useState(null);
  const [reportSections, setReportSections] = useState([]);
  const [reportAnswers, setReportAnswers] = useState({});
  const [reportPhotos, setReportPhotos] = useState([]);
  const [reportStatus, setReportStatus] = useState("rascunho");
  const [reportMessage, setReportMessage] = useState("");

  const [budgets, setBudgets] = useState([]);

  const [signatureMode, setSignatureMode] = useState("none");
  const [signatureScope, setSignatureScope] = useState("last_page");
  const [signatureClient, setSignatureClient] = useState("");
  const [signatureTech, setSignatureTech] = useState("");
  const [signaturePages, setSignaturePages] = useState({});

  const [selectedEquipmentId, setSelectedEquipmentId] = useState("");
  const [newEquipment, setNewEquipment] = useState({
    name: "",
    model: "",
    serial: "",
    description: ""
  });

  const [form, setForm] = useState({
    title: "",
    description: "",
    client_id: "",
    user_id: "",
    task_type_id: "",
    status: "aberta",
    priority: "media",
    start_date: "",
    due_date: ""
  });
  const [error, setError] = useState("");
  const formatter = useMemo(
    () => new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }),
    []
  );

  const activeReport = reports.find((item) => item.id === activeReportId) || null;
  const client = clients.find((item) => item.id === Number(form.client_id));
  const generalReport = reports.find((item) => !item.equipment_id) || null;
  const selectedType = types.find((item) => item.id === Number(form.task_type_id));
  const selectedTemplate = templates.find(
    (item) => item.id === Number(selectedType?.report_template_id)
  );
  const reportLayout = useMemo(() => {
    const templateId =
      activeReport?.template_id || selectedTemplate?.id || selectedType?.report_template_id;
    const template = templates.find((item) => item.id === Number(templateId));
    const layout = {
      ...template?.structure?.layout,
      ...activeReport?.content?.layout
    };
    const sectionColumns = Math.min(Math.max(Number(layout.sectionColumns) || 1, 1), 3);
    const fieldColumns = Math.min(Math.max(Number(layout.fieldColumns) || 1, 1), 3);
    return { sectionColumns, fieldColumns };
  }, [activeReport, selectedTemplate, selectedType, templates]);
  const reportLayoutStyle = useMemo(
    () => ({
      "--section-cols": reportLayout.sectionColumns,
      "--field-cols": reportLayout.fieldColumns
    }),
    [reportLayout]
  );
  const signaturePageItems = useMemo(() => {
    const reportPages = reports.map((report) => ({
      key: `report:${report.id}`,
      label:
        report.title ||
        (report.equipment_name ? `Relatório - ${report.equipment_name}` : "Relatório")
    }));
    const budgetPages = budgets.map((budget) => ({
      key: `budget:${budget.id}`,
      label: `Orçamento #${budget.id}`
    }));
    return [...reportPages, ...budgetPages];
  }, [reports, budgets]);

  useEffect(() => {
    if (isNew) {
      setTaskId(null);
    } else {
      setTaskId(Number(id));
    }
  }, [id, isNew]);

  useEffect(() => {
    if (!canView) return;
    async function loadPage() {
      const [clientsData, usersData, typesData, templatesData, productsData] =
        await Promise.all([
          apiGet("/clients"),
          user?.role === "administracao" ? apiGet("/users") : Promise.resolve([]),
          apiGet("/task-types"),
          apiGet("/report-templates"),
          apiGet("/products")
        ]);
      setClients(clientsData || []);
      setUsers(usersData || []);
      setTypes(typesData || []);
      setTemplates(templatesData || []);
      setProducts(productsData || []);

      if (!taskId) {
        setReports([]);
        setBudgets([]);
        setTaskEquipments([]);
        return;
      }

      const task = await apiGet(`/tasks/${taskId}`);
      setForm({
        title: task.title || "",
        description: task.description || "",
        client_id: task.client_id || "",
        user_id: task.user_id || "",
        task_type_id: task.task_type_id || "",
        status: task.status || "aberta",
        priority: task.priority || "media",
        start_date: task.start_date || "",
        due_date: task.due_date || ""
      });
      setSignatureMode(task.signature_mode || "none");
      setSignatureScope(task.signature_scope || "last_page");
      setSignatureClient(task.signature_client || "");
      setSignatureTech(task.signature_tech || "");
      setSignaturePages(task.signature_pages || {});

      const reportsData = await loadReports(task.task_type_id, typesData, templatesData);
      await loadBudgets(reportsData);
      await loadTaskEquipments();
    }

    loadPage();
  }, [taskId, canManage, user?.role, canView]);

  useEffect(() => {
    async function loadClientEquipments() {
      if (!form.client_id) {
        setEquipments([]);
        return;
      }
      const data = await apiGet(`/equipments?clientId=${form.client_id}`);
      setEquipments(data || []);
    }
    loadClientEquipments();
  }, [form.client_id]);

  async function loadReports(taskTypeId, typesData = types, templatesData = templates) {
    if (!taskId) return [];
    const data = await apiGet(`/reports?taskId=${taskId}`);
    const list = data || [];
    setReports(list);
    const defaultReport =
      list.find((item) => !item.equipment_id) || list[0] || null;
    if (defaultReport) {
      setActiveReportId(defaultReport.id);
      applyReportData(defaultReport, taskTypeId, typesData, templatesData);
    } else {
      setActiveReportId(null);
      setReportSections([]);
      setReportAnswers({});
      setReportPhotos([]);
      setReportStatus("rascunho");
    }
    return list;
  }

  async function loadBudgets(reportList = reports) {
    if (!taskId) return;
    const byTask = await apiGet(`/budgets?taskId=${taskId}&includeItems=1`);
    const reportIds = (reportList || []).map((item) => item.id);
    const byReports = await Promise.all(
      reportIds.map((reportId) => apiGet(`/budgets?reportId=${reportId}&includeItems=1`))
    );
    const merged = new Map();
    (byTask || []).forEach((budget) => merged.set(budget.id, budget));
    byReports.flat().forEach((budget) => merged.set(budget.id, budget));
    setBudgets(Array.from(merged.values()));
  }

  async function loadTaskEquipments() {
    if (!taskId) return;
    const data = await apiGet(`/tasks/${taskId}/equipments`);
    setTaskEquipments(data || []);
  }

  function applyReportData(reportData, taskTypeId, typesData = types, templatesData = templates) {
    const content = reportData?.content || {};
    let sections = content.sections || [];

    if (sections.length === 0 && taskTypeId) {
      const type = typesData.find((item) => item.id === Number(taskTypeId));
      const template = templatesData.find(
        (item) => item.id === Number(type?.report_template_id)
      );
      sections = template?.structure?.sections || [];
    }

    setReportSections(sections);
    setReportAnswers(content.answers || {});
    setReportPhotos(content.photos || []);
    setReportStatus(reportData?.status || "rascunho");
  }

  function handleAnswerChange(fieldId, value) {
    if (!canManage) return;
    setReportAnswers((prev) => ({ ...prev, [fieldId]: value }));
  }

  function renderReportField(field) {
    const value = reportAnswers[field.id];

    if (field.type === "textarea") {
      return (
        <FormField
          key={field.id}
          label={field.required ? `${field.label} *` : field.label}
          type="textarea"
          value={value}
          onChange={(val) => handleAnswerChange(field.id, val)}
          disabled={!canManage}
          className="full"
        />
      );
    }

    if (field.type === "select") {
      const options = (field.options || []).map((option) => ({
        value: option,
        label: option
      }));
      return (
        <FormField
          key={field.id}
          label={field.required ? `${field.label} *` : field.label}
          type="select"
          value={value}
          options={options}
          onChange={(val) => handleAnswerChange(field.id, val)}
          disabled={!canManage}
        />
      );
    }

    if (field.type === "yesno") {
      return (
        <FormField
          key={field.id}
          label={field.required ? `${field.label} *` : field.label}
          type="select"
          value={value}
          options={[
            { value: "sim", label: "Sim" },
            { value: "nao", label: "Não" }
          ]}
          onChange={(val) => handleAnswerChange(field.id, val)}
          disabled={!canManage}
        />
      );
    }

    if (field.type === "checkbox") {
      return (
        <FormField
          key={field.id}
          label={field.required ? `${field.label} *` : field.label}
          type="checkbox"
          value={Boolean(value)}
          onChange={(val) => handleAnswerChange(field.id, val)}
          disabled={!canManage}
        />
      );
    }

    return (
      <FormField
        key={field.id}
        label={field.required ? `${field.label} *` : field.label}
        type={field.type || "text"}
        value={value}
        onChange={(val) => handleAnswerChange(field.id, val)}
        disabled={!canManage}
      />
    );
  }

  async function saveTask() {
    setError("");
    if (!canManage) {
      setError("Sem permissão para editar esta tarefa.");
      return;
    }

    const payload = {
      ...form,
      client_id: form.client_id ? Number(form.client_id) : null,
      user_id: form.user_id ? Number(form.user_id) : null,
      task_type_id: form.task_type_id ? Number(form.task_type_id) : null,
      signature_mode: signatureMode,
      signature_scope: signatureScope,
      signature_client: signatureClient || null,
      signature_tech: signatureTech || null,
      signature_pages: signaturePages
    };

    try {
      let savedTask;
      if (taskId) {
        savedTask = await apiPut(`/tasks/${taskId}`, payload);
      } else {
        savedTask = await apiPost("/tasks", payload);
        setTaskId(savedTask.id);
        navigate(`/tarefas/${savedTask.id}`);
      }
      if (savedTask?.id) {
        await loadReports(savedTask.task_type_id);
        await loadBudgets();
      }
    } catch (err) {
      setError(err.message || "Falha ao salvar");
    }
  }

  async function handleSubmit(event) {
    event.preventDefault();
    await saveTask();
  }

  async function handleSaveReport() {
    if (!canManage) {
      setReportMessage("Sem permissão para editar relatórios.");
      return;
    }
    if (!activeReport?.id) {
      setReportMessage("Salve a tarefa para gerar o relatório.");
      return;
    }

    const type = types.find((item) => item.id === Number(form.task_type_id));
    const templateId = activeReport.template_id || type?.report_template_id;
    const payload = {
      title: activeReport.title || form.title || "Relatório",
      task_id: taskId,
      client_id: form.client_id ? Number(form.client_id) : null,
      template_id: templateId ? Number(templateId) : null,
      equipment_id: activeReport.equipment_id ? Number(activeReport.equipment_id) : null,
      status: reportStatus,
      content: {
        sections: reportSections,
        layout: reportLayout,
        answers: reportAnswers,
        photos: reportPhotos
      }
    };

    try {
      await apiPut(`/reports/${activeReport.id}`, payload);
      setReportMessage("Relatório salvo com sucesso.");
      await loadReports(form.task_type_id);
    } catch (err) {
      setReportMessage(err.message || "Falha ao salvar relatório");
    }
  }

  function handleExportTaskPdf() {
    if (!taskId) return;
    const exportReports = reports.map((report) => {
      const template = templates.find((item) => item.id === Number(report.template_id));
      const nextLayout =
        report.content?.layout ||
        template?.structure?.layout || {
          sectionColumns: 1,
          fieldColumns: 1
        };
      if (report.id === activeReportId) {
        return {
          ...report,
          status: reportStatus,
          content: {
            sections: reportSections,
            layout: reportLayout,
            answers: reportAnswers,
            photos: reportPhotos
          }
        };
      }
      return {
        ...report,
        content: {
          ...(report.content || {}),
          layout: nextLayout
        }
      };
    });
    const html = buildTaskPdfHtml({
      task: { ...form, id: taskId, title: form.title || "Tarefa" },
      client,
      reports: exportReports,
      budgets,
      signatureMode,
      signatureScope,
      signatureClient,
      signatureTech,
      signaturePages,
      logoUrl: logo
    });
    openPrintWindow(html);
  }

  function handleSendReportEmail() {
    if (!activeReport) return;
    const emailMatch = (client?.contact || "").match(
      /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/i
    );
    const email = emailMatch ? emailMatch[0] : "";
    const body = buildReportText({
      reportTitle: activeReport.title,
      taskTitle: form.title,
      clientName: client?.name,
      equipmentName: activeReport.equipment_name,
      sections: reportSections,
      answers: reportAnswers
    });
    const subject = `Relatório - ${form.title || "Tarefa"}`;
    const mailto = `mailto:${email}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
    window.location.href = mailto;
  }

  async function ensureTaskPublicLink() {
    if (!taskId) {
      alert("Salve a tarefa para gerar o link.");
      return null;
    }
    const response = await apiPost(`/tasks/${taskId}/public-link`, {});
    return response?.url;
  }

  async function handleSharePublicLink() {
    try {
      const url = await ensureTaskPublicLink();
      if (!url) return;
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(url);
        alert("Link copiado para a área de transferência.");
      } else {
        window.prompt("Copie o link abaixo:", url);
      }
    } catch (err) {
      alert(err.message || "Falha ao gerar link.");
    }
  }

  async function handleOpenPublicPage() {
    try {
      const url = await ensureTaskPublicLink();
      if (!url) return;
      window.open(url, "_blank", "noopener");
    } catch (err) {
      alert(err.message || "Falha ao abrir link.");
    }
  }

  async function ensureBudgetPublicLink(budgetId) {
    if (!budgetId) return null;
    const response = await apiPost(`/budgets/${budgetId}/public-link`, {});
    return response?.url;
  }

  async function handleShareBudgetLink(budgetId) {
    try {
      const url = await ensureBudgetPublicLink(budgetId);
      if (!url) return;
      if (navigator.clipboard?.writeText) {
        await navigator.clipboard.writeText(url);
        alert("Link copiado para a área de transferência.");
      } else {
        window.prompt("Copie o link abaixo:", url);
      }
    } catch (err) {
      alert(err.message || "Falha ao gerar link.");
    }
  }

  async function handleOpenBudgetPage(budgetId) {
    try {
      const url = await ensureBudgetPublicLink(budgetId);
      if (!url) return;
      window.open(url, "_blank", "noopener");
    } catch (err) {
      alert(err.message || "Falha ao abrir link.");
    }
  }

  function handleReportSelect(value) {
    const reportItem = reports.find((item) => item.id === Number(value));
    if (!reportItem) return;
    setActiveReportId(reportItem.id);
    applyReportData(reportItem, form.task_type_id);
  }

  async function handleCreateReport() {
    if (!canManage) {
      setReportMessage("Sem permissão para criar relatórios.");
      return;
    }
    if (!taskId) return;
    if (!form.client_id) {
      setReportMessage("Selecione um cliente antes de criar o relatório.");
      return;
    }
    if (!selectedTemplate) {
      setReportMessage("Este tipo de tarefa ainda não possui modelo de relatório.");
      return;
    }
    const baseIndex = reports.filter((item) => !item.equipment_id).length + 1;
    const payload = {
      title: `Relatório adicional ${baseIndex}`,
      task_id: taskId,
      client_id: Number(form.client_id),
      template_id: Number(selectedTemplate.id),
      equipment_id: null,
      status: "rascunho",
      content: {
        sections: selectedTemplate.structure?.sections || [],
        layout: selectedTemplate.structure?.layout || {
          sectionColumns: 1,
          fieldColumns: 1
        },
        answers: {},
        photos: []
      }
    };

    try {
      const created = await apiPost("/reports", payload);
      await loadReports(form.task_type_id);
      setActiveReportId(created.id);
      applyReportData(created, form.task_type_id, types, templates);
      setReportMessage("Relatório criado com sucesso.");
    } catch (err) {
      setReportMessage(err.message || "Falha ao criar relatório");
    }
  }

  async function handleDeleteReport() {
    if (!canManage) {
      setReportMessage("Sem permissão para excluir relatórios.");
      return;
    }
    if (!activeReport?.id) return;
    if (activeReport.equipment_id) {
      setReportMessage("Remova o equipamento para excluir este relatório.");
      return;
    }
    const confirmed = window.confirm("Deseja excluir este relatório?");
    if (!confirmed) return;
    try {
      await apiDelete(`/reports/${activeReport.id}`);
      await loadReports(form.task_type_id);
      await loadBudgets();
      setReportMessage("Relatório excluído.");
    } catch (err) {
      setReportMessage(err.message || "Falha ao excluir relatório");
    }
  }

  function handleAddPhotos(files) {
    if (!canManage) return;
    const list = Array.from(files || []);
    if (list.length === 0) return;
    Promise.all(
      list.map(
        (file) =>
          new Promise((resolve) => {
            const reader = new FileReader();
            reader.onload = () =>
              resolve({
                id: uid(),
                name: file.name,
                dataUrl: reader.result
              });
            reader.readAsDataURL(file);
          })
      )
    ).then((items) => {
      setReportPhotos((prev) => [...prev, ...items]);
    });
  }

  function handleRemovePhoto(photoId) {
    if (!canManage) return;
    setReportPhotos((prev) => prev.filter((photo) => photo.id !== photoId));
  }

  function updateSignaturePage(pageKey, role, value) {
    if (!canManage) return;
    setSignaturePages((prev) => ({
      ...prev,
      [pageKey]: {
        ...(prev[pageKey] || {}),
        [role]: value
      }
    }));
  }

  async function handleAttachEquipment() {
    if (!canManage) return;
    if (!taskId || !selectedEquipmentId) return;
    try {
      await apiPost(`/tasks/${taskId}/equipments`, {
        equipment_id: Number(selectedEquipmentId)
      });
      setSelectedEquipmentId("");
      await loadTaskEquipments();
      await loadReports(form.task_type_id);
    } catch (err) {
      setError(err.message || "Falha ao vincular equipamento");
    }
  }

  async function handleCreateEquipment() {
    if (!canManage) return;
    if (!taskId) return;
    if (!form.client_id) {
      setError("Selecione um cliente antes de cadastrar o equipamento.");
      return;
    }
    if (!newEquipment.name) {
      setError("Informe o nome do equipamento.");
      return;
    }
    try {
      const created = await apiPost("/equipments", {
        client_id: Number(form.client_id),
        ...newEquipment
      });
      setNewEquipment({ name: "", model: "", serial: "", description: "" });
      await apiPost(`/tasks/${taskId}/equipments`, { equipment_id: created.id });
      await loadTaskEquipments();
      await loadReports(form.task_type_id);
    } catch (err) {
      setError(err.message || "Falha ao cadastrar equipamento");
    }
  }

  async function handleDetachEquipment(equipmentId) {
    if (!canManage) return;
    if (!taskId) return;
    try {
      await apiDelete(`/tasks/${taskId}/equipments/${equipmentId}`);
      const reportToDelete = reports.find(
        (item) => item.equipment_id === equipmentId
      );
      if (reportToDelete) {
        await apiDelete(`/reports/${reportToDelete.id}`);
      }
      await loadTaskEquipments();
      await loadReports(form.task_type_id);
    } catch (err) {
      setError(err.message || "Falha ao remover equipamento");
    }
  }

  function handleOpenEquipmentReport(equipmentId) {
    const reportItem = reports.find((item) => item.equipment_id === equipmentId);
    if (!reportItem) return;
    setActiveTab("relatorio");
    setActiveReportId(reportItem.id);
    applyReportData(reportItem, form.task_type_id);
  }

  const reportOptions = reports.map((item) => ({
    value: item.id,
    label:
      item.title ||
      (item.equipment_name ? `Equipamento: ${item.equipment_name}` : "Relatório")
  }));

  if (!canView) {
    return (
      <section className="section">
        <div className="section-header">
          <h2 className="section-title">Tarefa</h2>
        </div>
        <div className="card">
          <p>Você não tem permissão para visualizar esta tarefa.</p>
        </div>
      </section>
    );
  }

  return (
    <section className="section">
      <div className="section-header">
        <div>
          <h2 className="section-title">{taskId ? "Configurar tarefa" : "Nova tarefa"}</h2>
          <span className="muted">Gerencie relatórios, orçamentos e equipamentos</span>
        </div>
        <div className="inline">
          {activeTab === "relatorio" && (
            <>
              <button
                className="btn secondary"
                type="button"
                onClick={handleSendReportEmail}
                disabled={!activeReport}
              >
                Enviar e-mail
              </button>
                <button
                  className="btn ghost"
                  type="button"
                  onClick={handleExportTaskPdf}
                  disabled={!taskId}
                >
                  Exportar PDF
                </button>
                <button
                  className="btn ghost"
                  type="button"
                  onClick={handleSharePublicLink}
                  disabled={!taskId}
                >
                  Compartilhar link
                </button>
                <button
                  className="btn secondary"
                  type="button"
                  onClick={handleOpenPublicPage}
                  disabled={!taskId}
                >
                  Abrir PDF
                </button>
            </>
          )}
          <button className="btn ghost" type="button" onClick={() => navigate("/tarefas")}>
            Voltar
          </button>
        </div>
      </div>

      {error && <p className="muted">{error}</p>}

      <div className="task-config">
        <aside className="task-config-nav">
          {tabs.map((tab) => {
            const disabled = !taskId && tab.id !== "detalhes";
            return (
              <button
                key={tab.id}
                type="button"
                className={`tab-link ${activeTab === tab.id ? "active" : ""}`}
                onClick={() => setActiveTab(tab.id)}
                disabled={disabled}
              >
                {tab.label}
              </button>
            );
          })}
        </aside>

        <div className="task-config-body">
          {activeTab === "detalhes" && (
            <form className="card" onSubmit={handleSubmit}>
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
                    options={statusOptions}
                    onChange={(value) => setForm((prev) => ({ ...prev, status: value }))}
                  />
                  <FormField
                    label="Prioridade"
                    type="select"
                    value={form.priority}
                    options={priorityOptions}
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
                    label="In�cio"\n                    type="date-br"
                    value={form.start_date}
                    onChange={(value) => setForm((prev) => ({ ...prev, start_date: value }))}
                  />
                  <FormField
                    label="Fim"\n                    type="date-br"
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
          )}

          {activeTab === "relatorio" && (
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
                      <button
                        className="btn primary"
                        type="button"
                        onClick={handleCreateReport}
                        disabled={!canManage}
                      >
                        Adicionar relatório
                      </button>
                    </div>
                  </div>
                  <small>Nenhum relatório cadastrado.</small>
                  {!form.client_id && (
                    <small>Selecione um cliente para criar o relatório.</small>
                  )}
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
                      <button
                        className="btn secondary"
                        type="button"
                        onClick={handleCreateReport}
                        disabled={!canManage}
                      >
                        Adicionar relatório
                      </button>
                      <button
                        className="btn ghost"
                        type="button"
                        onClick={handleDeleteReport}
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
                      onChange={handleReportSelect}
                    />
                    <FormField
                      label="Status do relatório"
                      type="select"
                      value={reportStatus}
                      options={reportStatusOptions}
                      onChange={setReportStatus}
                      disabled={!canManage}
                    />
                  </div>

                  {activeReport?.equipment_id && (
                    <small className="muted">
                      Relatórios de equipamentos são gerenciados na aba Equipamentos.
                    </small>
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
                        onChange={(event) => handleAddPhotos(event.target.files)}
                        disabled={!canManage}
                        hidden
                      />
                    </label>
                  </div>

                  {reportPhotos.length === 0 && (
                    <small>Sem fotos anexadas.</small>
                  )}
                  {reportPhotos.length > 0 && (
                    <div className="photo-grid">
                      {reportPhotos.map((photo) => (
                        <div key={photo.id} className="photo-card">
                          <img src={photo.dataUrl} alt={photo.name} />
                          <button
                            className="btn ghost"
                            type="button"
                            onClick={() => handleRemovePhoto(photo.id)}
                            disabled={!canManage}
                          >
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

                  {reportSections.length === 0 && (
                    <small>Este modelo ainda não possui campos.</small>
                  )}

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
                    <button
                      className="btn primary"
                      type="button"
                      onClick={handleSaveReport}
                      disabled={!canManage}
                    >
                      Salvar relatório
                    </button>
                  </div>
                </div>
              )}
            </div>
          )}

          {activeTab === "orcamentos" && (
            <div className="list">
              {!taskId && (
                <div className="card">
                  <small>Salve a tarefa para liberar os orçamentos.</small>
                </div>
              )}

              {taskId && (
                <>
                  <div className="card">
                    <div className="section-header">
                      <h3 className="section-title">Orçamentos vinculados</h3>
                    </div>
                    {budgets.length === 0 && <small>Nenhum orçamento cadastrado.</small>}
                    {budgets.map((budget) => (
                      <div key={budget.id} className="card">
                        <div className="inline" style={{ justifyContent: "space-between" }}>
                          <strong>Orçamento #{budget.id}</strong>
                          <span className="badge">{budget.status || "rascunho"}</span>
                        </div>
                          <small>Total: {formatter.format(budget.total || 0)}</small>
                          <div className="list" style={{ marginTop: "8px" }}>
                            {(budget.items || []).map((item) => (
                              <div key={item.id} className="card">
                              <div className="inline" style={{ justifyContent: "space-between" }}>
                                <span>{item.description}</span>
                                <span>{formatter.format(item.total || 0)}</span>
                              </div>
                              <small>
                                {item.qty} x {formatter.format(item.unit_price || 0)}
                                </small>
                              </div>
                            ))}
                          </div>
                          <div className="inline" style={{ marginTop: "12px" }}>
                            <button
                              className="btn ghost"
                              type="button"
                              onClick={() => handleShareBudgetLink(budget.id)}
                              disabled={!taskId}
                            >
                              Compartilhar link
                            </button>
                            <button
                              className="btn secondary"
                              type="button"
                              onClick={() => handleOpenBudgetPage(budget.id)}
                              disabled={!taskId}
                            >
                              Abrir PDF
                            </button>
                          </div>
                        </div>
                      ))}
                    </div>

                  <BudgetForm
                    clientId={form.client_id}
                    reportId={generalReport?.id}
                    taskId={taskId}
                    products={products}
                    clients={clients}
                    canManage={canManageBudgets}
                    onSaved={() => loadBudgets()}
                  />
                </>
              )}
            </div>
          )}

          {activeTab === "equipamentos" && (
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
                          <button
                            className="btn secondary"
                            type="button"
                            onClick={() => handleOpenEquipmentReport(equipment.id)}
                          >
                            Abrir relatório
                          </button>
                          <button
                            className="btn ghost"
                            type="button"
                            onClick={() => handleDetachEquipment(equipment.id)}
                            disabled={!canManage}
                          >
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
                      <button
                        className="btn secondary"
                        type="button"
                        onClick={handleAttachEquipment}
                        disabled={!canManage}
                      >
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
                        onChange={(value) =>
                          setNewEquipment((prev) => ({ ...prev, name: value }))
                        }
                        disabled={!canManage}
                      />
                      <FormField
                        label="Modelo"
                        value={newEquipment.model}
                        onChange={(value) =>
                          setNewEquipment((prev) => ({ ...prev, model: value }))
                        }
                        disabled={!canManage}
                      />
                      <FormField
                        label="Serie"
                        value={newEquipment.serial}
                        onChange={(value) =>
                          setNewEquipment((prev) => ({ ...prev, serial: value }))
                        }
                        disabled={!canManage}
                      />
                      <FormField
                        label="Descrição"
                        type="textarea"
                        value={newEquipment.description}
                        onChange={(value) =>
                          setNewEquipment((prev) => ({ ...prev, description: value }))
                        }
                        className="full"
                        disabled={!canManage}
                      />
                    </div>
                    <div className="inline" style={{ marginTop: "12px" }}>
                      <button
                        className="btn primary"
                        type="button"
                        onClick={handleCreateEquipment}
                        disabled={!canManage}
                      >
                        Cadastrar e vincular
                      </button>
                    </div>
                  </div>
                </>
              )}
            </div>
          )}

          {activeTab === "assinaturas" && (
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
                          <SignaturePad
                            value={signatureClient}
                            onChange={setSignatureClient}
                            disabled={!canManage}
                          />
                        </div>
                      )}

                      {(signatureMode === "tech" || signatureMode === "both") && (
                        <div className="card">
                          <h3>Assinatura do técnico</h3>
                          <SignaturePad
                            value={signatureTech}
                            onChange={setSignatureTech}
                            disabled={!canManage}
                          />
                        </div>
                      )}
                    </>
                  )}

                  {signatureScope === "all_pages" && signatureMode !== "none" && (
                    <div className="list" style={{ marginTop: "16px" }}>
                      {signaturePageItems.length === 0 && (
                        <small>Sem páginas para assinar.</small>
                      )}
                      {signaturePageItems.map((page) => (
                        <div key={page.key} className="card">
                          <h3>{page.label}</h3>
                          {(signatureMode === "client" || signatureMode === "both") && (
                            <div className="card">
                              <h3>Assinatura do cliente</h3>
                              <SignaturePad
                                value={signaturePages?.[page.key]?.client || ""}
                                onChange={(value) => updateSignaturePage(page.key, "client", value)}
                                disabled={!canManage}
                              />
                            </div>
                          )}
                          {(signatureMode === "tech" || signatureMode === "both") && (
                            <div className="card">
                              <h3>Assinatura do técnico</h3>
                              <SignaturePad
                                value={signaturePages?.[page.key]?.tech || ""}
                                onChange={(value) => updateSignaturePage(page.key, "tech", value)}
                                disabled={!canManage}
                              />
                            </div>
                          )}
                        </div>
                      ))}
                    </div>
                  )}

                  <div className="inline" style={{ marginTop: "16px" }}>
                    <button
                      className="btn primary"
                      type="button"
                      onClick={saveTask}
                      disabled={!canManage}
                    >
                      Salvar assinaturas
                    </button>
                  </div>
                </div>
              )}
            </div>
          )}
        </div>
      </div>
    </section>
  );
}

