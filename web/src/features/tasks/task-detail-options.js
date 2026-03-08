import {
  REPORT_STATUS_OPTIONS,
  SIGNATURE_MODE_OPTIONS,
  SIGNATURE_SCOPE_OPTIONS,
  TASK_PRIORITY_OPTIONS,
  TASK_STATUS_OPTIONS
} from "../../shared/contracts/domain-options";

export const taskStatusOptions = TASK_STATUS_OPTIONS.map((option) => ({
  value: option.value,
  label: option.label
}));

export const taskPriorityOptions = TASK_PRIORITY_OPTIONS.map((option) => ({
  value: option.value,
  label: option.label
}));

export const reportStatusOptions = REPORT_STATUS_OPTIONS.map((option) => ({
  value: option.value,
  label: option.label
}));

export const signatureModeOptions = SIGNATURE_MODE_OPTIONS.map((option) => ({
  value: option.value,
  label: option.label
}));

export const signatureScopeOptions = SIGNATURE_SCOPE_OPTIONS.map((option) => ({
  value: option.value,
  label: option.label
}));

export const taskDetailTabs = [
  { id: "detalhes", label: "Detalhes da tarefa" },
  { id: "relatorio", label: "Relatório" },
  { id: "orcamentos", label: "Orçamentos" },
  { id: "equipamentos", label: "Equipamentos" },
  { id: "assinaturas", label: "Assinaturas" }
];
