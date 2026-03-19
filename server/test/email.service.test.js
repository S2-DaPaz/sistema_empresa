const test = require("node:test");
const assert = require("node:assert/strict");

const { createEmailService } = require("../src/infrastructure/email/email.service");

function createLogger() {
  return {
    entries: [],
    info(event, context) {
      this.entries.push({ level: "info", event, context });
    },
    warn(event, context) {
      this.entries.push({ level: "warn", event, context });
    },
    error(event, context) {
      this.entries.push({ level: "error", event, context });
    }
  };
}

test("brevo provider sends transactional email through HTTP API", async () => {
  const logger = createLogger();
  const requests = [];
  const emailService = createEmailService({
    env: {
      email: {
        provider: "brevo",
        fromName: "RV Sistema Empresa",
        fromAddress: "suporte@empresa.com",
        replyTo: "contato@empresa.com",
        brevo: {
          apiKey: "brevo-key",
          apiBaseUrl: "https://api.brevo.com/v3"
        },
        smtp: {}
      }
    },
    logger,
    fetchImpl: async (url, options) => {
      requests.push({ url, options });
      return {
        ok: true,
        status: 201,
        async text() {
          return JSON.stringify({ messageId: "<abc@brevo>" });
        }
      };
    }
  });

  await emailService.sendVerificationCode({
    to: "cliente@empresa.com",
    name: "Cliente",
    code: "123456",
    expiresInMinutes: 15
  });

  assert.equal(requests.length, 1);
  assert.equal(requests[0].url, "https://api.brevo.com/v3/smtp/email");
  assert.equal(requests[0].options.method, "POST");
  assert.equal(requests[0].options.headers["api-key"], "brevo-key");

  const body = JSON.parse(requests[0].options.body);
  assert.equal(body.sender.email, "suporte@empresa.com");
  assert.equal(body.replyTo.email, "contato@empresa.com");
  assert.equal(body.to[0].email, "cliente@empresa.com");
  assert.equal(body.subject, "RV Sistema Empresa: confirme o seu e-mail");
  assert.match(body.htmlContent, /123456/);
});

test("brevo provider reports misconfiguration when API key is missing", async () => {
  const logger = createLogger();
  const emailService = createEmailService({
    env: {
      email: {
        provider: "brevo",
        fromName: "RV Sistema Empresa",
        fromAddress: "suporte@empresa.com",
        replyTo: "",
        brevo: {
          apiKey: "",
          apiBaseUrl: "https://api.brevo.com/v3"
        },
        smtp: {}
      }
    },
    logger,
    fetchImpl: async () => {
      throw new Error("fetch should not be called");
    }
  });

  await assert.rejects(
    () =>
      emailService.sendVerificationCode({
        to: "cliente@empresa.com",
        name: "Cliente",
        code: "123456",
        expiresInMinutes: 15
      }),
    /BREVO_API_KEY/
  );
});
