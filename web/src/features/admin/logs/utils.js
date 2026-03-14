export function buildQueryString(filters, page, pageSize = 20) {
  const params = new URLSearchParams();

  Object.entries({ ...filters, page, pageSize }).forEach(([key, value]) => {
    if (value === undefined || value === null) return;
    if (String(value).trim() === "") return;
    params.set(key, String(value).trim());
  });

  return params.toString();
}

export function formatDateTime(value) {
  if (!value) return "-";

  return new Intl.DateTimeFormat("pt-BR", {
    dateStyle: "short",
    timeStyle: "short"
  }).format(new Date(value));
}

export function formatUser(item) {
  if (!item) return "Sistema";
  return item.user_name || item.user_email || (item.user_id ? `Usuário #${item.user_id}` : "Sistema");
}

export function safeJson(value) {
  if (value === undefined || value === null || value === "") {
    return "Sem dados.";
  }
  return JSON.stringify(value, null, 2);
}

export async function copyToClipboard(text) {
  if (!navigator.clipboard?.writeText) {
    return false;
  }

  await navigator.clipboard.writeText(text);
  return true;
}
