const nodemailer = require("nodemailer");

const {
  buildPasswordResetEmail,
  buildVerificationEmail
} = require("./email.templates");

function createConsoleTransport(logger) {
  logger.warn("email_console_provider_enabled", {
    provider: "console"
  });

  return {
    async sendMail(message) {
      logger.info("email_preview_generated", {
        to: message.to,
        subject: message.subject,
        text: message.text
      });
      return { accepted: [message.to], rejected: [] };
    }
  };
}

function createMisconfiguredTransport(logger, provider, missingField) {
  return {
    async sendMail() {
      logger.error("email_provider_misconfigured", {
        provider,
        missingField
      });
      throw new Error(
        `E-mail provider misconfigured: ${provider} requires ${missingField}.`
      );
    }
  };
}

function normalizeRecipient(to) {
  if (Array.isArray(to)) {
    return to.map((entry) =>
      typeof entry === "string" ? { email: entry } : { email: entry.email, name: entry.name }
    );
  }

  if (typeof to === "string") {
    return [{ email: to }];
  }

  return [{ email: to.email, name: to.name }];
}

function createSmtpTransport(env) {
  if (!env.email.smtp.host) {
    return null;
  }

  return nodemailer.createTransport({
    host: env.email.smtp.host,
    port: env.email.smtp.port,
    secure: env.email.smtp.secure,
    auth: env.email.smtp.user
      ? {
          user: env.email.smtp.user,
          pass: env.email.smtp.password
        }
      : undefined
  });
}

function createBrevoTransport(env, logger, fetchImpl) {
  if (!env.email.brevo.apiKey) {
    return createMisconfiguredTransport(logger, "brevo", "BREVO_API_KEY");
  }

  if (typeof fetchImpl !== "function") {
    return createMisconfiguredTransport(logger, "brevo", "global fetch");
  }

  const endpoint = `${env.email.brevo.apiBaseUrl.replace(/\/$/, "")}/smtp/email`;

  return {
    async sendMail(message) {
      const payload = {
        sender: {
          name: env.email.fromName,
          email: env.email.fromAddress
        },
        to: normalizeRecipient(message.to),
        subject: message.subject,
        htmlContent: message.html,
        textContent: message.text
      };

      if (env.email.replyTo) {
        payload.replyTo = {
          name: env.email.fromName,
          email: env.email.replyTo
        };
      }

      const response = await fetchImpl(endpoint, {
        method: "POST",
        headers: {
          accept: "application/json",
          "api-key": env.email.brevo.apiKey,
          "content-type": "application/json"
        },
        body: JSON.stringify(payload)
      });

      const rawBody = await response.text();
      let parsedBody = null;
      try {
        parsedBody = rawBody ? JSON.parse(rawBody) : null;
      } catch (_error) {
        parsedBody = null;
      }

      if (!response.ok) {
        logger.error("email_provider_delivery_failed", {
          provider: "brevo",
          statusCode: response.status,
          responseBody: parsedBody || rawBody
        });
        throw new Error(
          `Brevo API request failed with status ${response.status}.`
        );
      }

      logger.info("email_provider_delivery_accepted", {
        provider: "brevo",
        to: message.to,
        messageId: parsedBody?.messageId || null
      });

      return {
        accepted: Array.isArray(message.to) ? message.to : [message.to],
        rejected: [],
        providerResponse: parsedBody
      };
    }
  };
}

function createTransport(env, logger, fetchImpl) {
  if (env.email.provider === "console") {
    return createConsoleTransport(logger);
  }

  if (env.email.provider === "smtp") {
    return createSmtpTransport(env) || createMisconfiguredTransport(logger, "smtp", "SMTP_HOST");
  }

  if (env.email.provider === "brevo" || env.email.provider === "brevo_api") {
    return createBrevoTransport(env, logger, fetchImpl);
  }

  logger.warn("email_unknown_provider_fallback", {
    provider: env.email.provider
  });
  return createConsoleTransport(logger);
}

function createEmailService({ env, logger, fetchImpl = global.fetch }) {
  const transport = createTransport(env, logger, fetchImpl);

  async function send({ to, subject, html, text }) {
    return transport.sendMail({
      to,
      subject,
      html,
      text
    });
  }

  async function sendVerificationCode({ to, name, code, expiresInMinutes }) {
    const template = buildVerificationEmail({
      appName: env.email.fromName || "RV Sistema Empresa",
      name,
      code,
      expiresInMinutes
    });
    return send({ to, ...template });
  }

  async function sendPasswordResetCode({ to, name, code, expiresInMinutes }) {
    const template = buildPasswordResetEmail({
      appName: env.email.fromName || "RV Sistema Empresa",
      name,
      code,
      expiresInMinutes
    });
    return send({ to, ...template });
  }

  return {
    sendVerificationCode,
    sendPasswordResetCode
  };
}

module.exports = { createEmailService };
