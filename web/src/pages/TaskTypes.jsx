import { useEffect, useMemo, useState } from "react";
import { apiGet } from "../api";
import EntityManager from "../components/EntityManager";
import { PERMISSIONS, useAuth } from "../contexts/AuthContext";

export default function TaskTypes() {
  const { hasPermission } = useAuth();
  const canView = hasPermission(PERMISSIONS.VIEW_TASK_TYPES);
  const canManage = hasPermission(PERMISSIONS.MANAGE_TASK_TYPES);
  const [templates, setTemplates] = useState([]);

  useEffect(() => {
    if (!canView) return;
    async function loadTemplates() {
      const data = await apiGet("/report-templates");
      setTemplates(data || []);
    }
    loadTemplates();
  }, [canView]);

  const fields = useMemo(
    () => [
      { name: "name", label: "Nome", type: "text", placeholder: "Tipo de tarefa" },
      {
        name: "description",
        label: "Descrição",
        type: "textarea",
        placeholder: "Detalhes do tipo",
        className: "full"
      },
      {
        name: "report_template_id",
        label: "Modelo de relatório",
        type: "select",
        options: templates.map((template) => ({
          value: template.id,
          label: template.name
        }))
      }
    ],
    [templates]
  );

  return (
    <EntityManager
      title="Tipos de tarefa"
      endpoint="/task-types"
      fields={fields}
      hint="Defina os tipos e amarre um modelo de relatório"
      primaryField="name"
      canView={canView}
      canManage={canManage}
    />
  );
}
