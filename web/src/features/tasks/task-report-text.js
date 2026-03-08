export function createDraftId() {
  if (typeof crypto !== "undefined" && crypto.randomUUID) {
    return crypto.randomUUID();
  }

  return `id_${Date.now()}_${Math.random().toString(16).slice(2)}`;
}

export function buildTaskReportText({
  reportTitle,
  taskTitle,
  clientName,
  equipmentName,
  sections,
  answers
}) {
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
