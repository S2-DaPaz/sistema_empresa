import { useEffect, useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { apiDelete, apiGet, apiPost, apiPut } from "../api";
import { PERMISSIONS, useAuth } from "../contexts/AuthContext";
import FormField from "../components/FormField";
import { getFriendlyErrorMessage } from "../shared/errors/error-normalizer";
import { TaskBudgetsTab } from "../features/tasks/detail/TaskBudgetsTab";
import { TaskDetailsTab } from "../features/tasks/detail/TaskDetailsTab";
import { TaskEquipmentsTab } from "../features/tasks/detail/TaskEquipmentsTab";
import { TaskReportsTab } from "../features/tasks/detail/TaskReportsTab";
import { TaskSignaturesTab } from "../features/tasks/detail/TaskSignaturesTab";
import {
  reportStatusOptions as reportStatusOptionsConfig,
  signatureModeOptions as signatureModeOptionsConfig,
  signatureScopeOptions as signatureScopeOptionsConfig,
  taskDetailTabs as taskDetailTabsConfig,
  taskPriorityOptions as taskPriorityOptionsConfig,
  taskStatusOptions as taskStatusOptionsConfig
} from "../features/tasks/task-detail-options";
import { buildTaskReportText, createDraftId } from "../features/tasks/task-report-text";
import { buildTaskPdfHtml, openPrintWindow } from "../utils/pdf";
import logo from "../assets/Logo.png";


export default function TaskDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { hasPermission } = useAuth();
  const isNew = id === "nova";
  const [taskId, setTaskId] = useState(isNew ? null : Number(id));
  const [activeTab, setActiveTab] = useState("detalhes");
  const canView = hasPermission(PERMISSIONS.VIEW_TASKS);
  const canManage = hasPermission(PERMISSIONS.MANAGE_TASKS);
  const canManageBudgets = hasPermission(PERMISSIONS.MANAGE_BUDGETS);
  const canViewUsers = hasPermission(PERMISSIONS.VIEW_USERS);

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
          canViewUsers ? apiGet("/users") : Promise.resolve([]),
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
  }, [taskId, canManage, canView, canViewUsers]);

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

  // Preservamos o relatório ativo sempre que recarregamos a lista. Sem isso a
  // tela tende a "voltar" para o relatório geral após um save, o que confunde
  // o usuário e dá a impressão de que um novo relatório vazio foi criado.
  async function loadReports(
    taskTypeId,
    typesData = types,
    templatesData = templates,
    preferredReportId = activeReportId
  ) {
    if (!taskId) return [];
    const data = await apiGet(`/reports?taskId=${taskId}`);
    const list = data || [];
    setReports(list);
    const preservedReport =
      list.find((item) => item.id === Number(preferredReportId)) || null;
    const defaultReport =
      preservedReport || list.find((item) => !item.equipment_id) || list[0] || null;
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

  // Salvar a tarefa pode disparar sincronização do relatório geral no backend.
  // Guardamos o relatório ativo antes do save para restaurar o contexto depois.
  async function saveTask() {
    setError("");
    if (!canManage) {
      setError("Sem permissão para editar esta tarefa.");
      return;
    }
    const previousActiveReportId = activeReportId;

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
        await loadReports(savedTask.task_type_id, types, templates, previousActiveReportId);
        await loadBudgets();
      }
    } catch (err) {
      setError(getFriendlyErrorMessage(err, "Não foi possível salvar a tarefa."));
    }
  }

  async function handleSubmit(event) {
    event.preventDefault();
    await saveTask();
  }

  // O save do relatório recarrega a coleção para refletir mudanças persistidas,
  // mas sem perder o relatório que o usuário estava editando.
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
      await loadReports(form.task_type_id, types, templates, activeReport.id);
    } catch (err) {
      setReportMessage(getFriendlyErrorMessage(err, "Não foi possível salvar o relatório."));
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
    const body = buildTaskReportText({
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
      alert(getFriendlyErrorMessage(err, "Não foi possível gerar o link público."));
    }
  }

  async function handleOpenPublicPage() {
    try {
      const url = await ensureTaskPublicLink();
      if (!url) return;
      window.open(url, "_blank", "noopener");
    } catch (err) {
      alert(getFriendlyErrorMessage(err, "Não foi possível abrir o link público."));
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
      alert(getFriendlyErrorMessage(err, "Não foi possível gerar o link público."));
    }
  }

  async function handleOpenBudgetPage(budgetId) {
    try {
      const url = await ensureBudgetPublicLink(budgetId);
      if (!url) return;
      window.open(url, "_blank", "noopener");
    } catch (err) {
      alert(getFriendlyErrorMessage(err, "Não foi possível abrir o link público."));
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
      setReportMessage(getFriendlyErrorMessage(err, "Não foi possível criar o relatório."));
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
      setReportMessage(getFriendlyErrorMessage(err, "Não foi possível excluir o relatório."));
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
                id: createDraftId(),
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
      setError(getFriendlyErrorMessage(err, "Não foi possível vincular o equipamento."));
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
      setError(getFriendlyErrorMessage(err, "Não foi possível cadastrar o equipamento."));
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
      setError(getFriendlyErrorMessage(err, "Não foi possível remover o equipamento."));
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
          {taskDetailTabsConfig.map((tab) => {
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
            <TaskDetailsTab
              taskId={taskId}
              canManage={canManage}
              form={form}
              setForm={setForm}
              clients={clients}
              users={users}
              types={types}
              taskStatusOptions={taskStatusOptionsConfig}
              taskPriorityOptions={taskPriorityOptionsConfig}
              onSubmit={handleSubmit}
            />
          )}

          {activeTab === "relatorio" && (
            <TaskReportsTab
              taskId={taskId}
              canManage={canManage}
              selectedTemplate={selectedTemplate}
              reportOptions={reportOptions}
              activeReportId={activeReportId}
              onReportSelect={handleReportSelect}
              reportStatus={reportStatus}
              reportStatusOptions={reportStatusOptionsConfig}
              onReportStatusChange={setReportStatus}
              activeReport={activeReport}
              reportPhotos={reportPhotos}
              onAddPhotos={handleAddPhotos}
              onRemovePhoto={handleRemovePhoto}
              reportSections={reportSections}
              reportLayoutStyle={reportLayoutStyle}
              renderReportField={renderReportField}
              reportMessage={reportMessage}
              onCreateReport={handleCreateReport}
              onDeleteReport={handleDeleteReport}
              onSaveReport={handleSaveReport}
              formClientId={form.client_id}
              logo={logo}
            />
          )}

          {activeTab === "orcamentos" && (
            <TaskBudgetsTab
              taskId={taskId}
              budgets={budgets}
              formatter={formatter}
              onShareBudgetLink={handleShareBudgetLink}
              onOpenBudgetPage={handleOpenBudgetPage}
              generalReportId={generalReport?.id}
              formClientId={form.client_id}
              products={products}
              clients={clients}
              canManageBudgets={canManageBudgets}
              onBudgetsSaved={() => loadBudgets()}
            />
          )}

          {activeTab === "equipamentos" && (
            <TaskEquipmentsTab
              taskId={taskId}
              taskEquipments={taskEquipments}
              canManage={canManage}
              onOpenEquipmentReport={handleOpenEquipmentReport}
              onDetachEquipment={handleDetachEquipment}
              selectedEquipmentId={selectedEquipmentId}
              setSelectedEquipmentId={setSelectedEquipmentId}
              equipments={equipments}
              onAttachEquipment={handleAttachEquipment}
              newEquipment={newEquipment}
              setNewEquipment={setNewEquipment}
              onCreateEquipment={handleCreateEquipment}
            />
          )}

          {activeTab === "assinaturas" && (
            <TaskSignaturesTab
              taskId={taskId}
              canManage={canManage}
              signatureMode={signatureMode}
              setSignatureMode={setSignatureMode}
              signatureScope={signatureScope}
              setSignatureScope={setSignatureScope}
              signatureModeOptions={signatureModeOptionsConfig}
              signatureScopeOptions={signatureScopeOptionsConfig}
              signatureClient={signatureClient}
              setSignatureClient={setSignatureClient}
              signatureTech={signatureTech}
              setSignatureTech={setSignatureTech}
              signaturePageItems={signaturePageItems}
              signaturePages={signaturePages}
              updateSignaturePage={updateSignaturePage}
              onSaveTask={saveTask}
            />
          )}
        </div>
      </div>
    </section>
  );
}

