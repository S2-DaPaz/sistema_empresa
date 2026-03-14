const test = require("node:test");
const assert = require("node:assert/strict");

const { createPublicService } = require("../src/modules/public/public.service");

function createService() {
  return createPublicService({
    env: {
      publicBaseUrl: "https://public.example.com",
      publicLinkDefaultDays: 7,
      pdfCacheEnabled: false,
      pdfWarmDebounceMs: 50,
      puppeteerArgs: [],
      puppeteerExecutablePath: ""
    },
    logger: {
      warn() {}
    }
  });
}

function createRequest() {
  return {
    headers: {},
    protocol: "https",
    get(name) {
      if (name === "host") return "public.example.com";
      return "";
    }
  };
}

test("public task page toolbar exposes share and download pdf actions", async () => {
  const service = createService();
  const db = {
    async get(sql) {
      if (sql.includes("FROM task_public_links")) {
        return { id: 1, task_id: 28, token: "token-123" };
      }
      if (sql.includes("SELECT * FROM tasks WHERE id = ?")) {
        return {
          id: 28,
          title: "Visita tecnica",
          status: "concluida",
          client_id: 5,
          signature_mode: "none",
          signature_scope: "last_page",
          signature_pages: null
        };
      }
      if (sql.includes("SELECT * FROM clients WHERE id = ?")) {
        return {
          id: 5,
          name: "Clinica Exemplo",
          contact: "contato@clinica.com",
          address: "Rua A, 123"
        };
      }
      return null;
    },
    async all(sql) {
      if (sql.includes("FROM reports")) return [];
      if (sql.includes("FROM budgets")) return [];
      if (sql.includes("FROM budget_items")) return [];
      return [];
    },
    async run() {
      return { ok: true };
    }
  };

  const html = await service.renderPublicTaskPage(db, createRequest(), 28, "token-123");

  assert.match(html, /Compartilhar PDF/);
  assert.match(html, /Baixar PDF/);
  assert.doesNotMatch(html, />Abrir PDF</);
  assert.match(html, /data-public-pdf-filename="relatorio_tarefa_28\.pdf"/);
  assert.match(
    html,
    /data-public-pdf-download-url="https:\/\/public\.example\.com\/public\/tasks\/28\/pdf\?token=token-123&amp;download=1"/
  );
});

test("public budget page toolbar exposes share and download pdf actions", async () => {
  const service = createService();
  const db = {
    async get(sql) {
      if (sql.includes("FROM budget_public_links")) {
        return { id: 2, budget_id: 12, token: "token-456" };
      }
      if (sql.includes("FROM budgets") && sql.includes("WHERE budgets.id = ?")) {
        return {
          id: 12,
          client_id: 7,
          total: 900,
          status: "enviado",
          created_at: "2026-03-14T12:00:00.000Z",
          signature_mode: "none",
          signature_scope: "last_page",
          signature_pages: null
        };
      }
      if (sql.includes("SELECT * FROM clients WHERE id = ?")) {
        return {
          id: 7,
          name: "Hospital Exemplo",
          contact: "financeiro@hospital.com",
          address: "Avenida B, 456"
        };
      }
      return null;
    },
    async all(sql) {
      if (sql.includes("FROM budget_items")) return [];
      return [];
    },
    async run() {
      return { ok: true };
    }
  };

  const html = await service.renderPublicBudgetPage(db, createRequest(), 12, "token-456");

  assert.match(html, /Compartilhar PDF/);
  assert.match(html, /Baixar PDF/);
  assert.doesNotMatch(html, />Abrir PDF</);
  assert.match(html, /data-public-pdf-filename="orcamento_12\.pdf"/);
  assert.match(
    html,
    /data-public-pdf-download-url="https:\/\/public\.example\.com\/public\/budgets\/12\/pdf\?token=token-456&amp;download=1"/
  );
});
