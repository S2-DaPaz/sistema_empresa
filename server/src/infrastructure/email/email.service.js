const nodemailer = require("nodemailer");

const {
  buildPasswordResetEmail,
  buildVerificationEmail
} = require("./email.templates");

function createConsoleTransport(logger) {
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

function createTransport(env, logger) {
  if (env.email.provider === "smtp" && env.email.smtp.host) {
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

  logger.warn("email_console_provider_enabled", {
    provider: env.email.provider || "console"
  });
  return createConsoleTransport(logger);
}

function createEmailService({ env, logger }) {
  const transport = createTransport(env, logger);
  const from = env.email.fromName
    ? `"${env.email.fromName}" <${env.email.fromAddress}>`
    : env.email.fromAddress;

  async function send({ to, subject, html, text }) {
    return transport.sendMail({
      from,
      to,
      replyTo: env.email.replyTo || undefined,
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
