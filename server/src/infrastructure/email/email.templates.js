function wrapHtml(content) {
  return `<!DOCTYPE html>
  <html lang="pt-BR">
    <body style="margin:0;padding:0;background:#f4f7fb;font-family:Arial,sans-serif;color:#132033;">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="padding:24px 0;">
        <tr>
          <td align="center">
            <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border-radius:20px;padding:32px;border:1px solid #dbe5f0;">
              <tr>
                <td>
                  ${content}
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
  </html>`;
}

function buildCodeBlock(code) {
  return `<div style="margin:24px 0;padding:18px 20px;border-radius:16px;background:#edf6ff;border:1px solid #bfe0ff;text-align:center;font-size:32px;letter-spacing:10px;font-weight:700;color:#0b5f92;">${code}</div>`;
}

function buildPrimaryButton(label, url) {
  return `<a href="${url}" style="display:inline-block;padding:14px 22px;border-radius:14px;background:#2563eb;color:#ffffff;text-decoration:none;font-weight:700;">${label}</a>`;
}

function buildDetailsBlock(details) {
  const safeDetails = Array.isArray(details) ? details.filter(Boolean) : [];
  if (!safeDetails.length) return "";

  const items = safeDetails
    .map((detail) => `<li style="margin:0 0 8px;line-height:1.6;color:#233248;">${detail}</li>`)
    .join("");

  return `
    <div style="margin:20px 0;padding:18px 20px;border-radius:16px;background:#f7f9fc;border:1px solid #dbe5f0;">
      <p style="margin:0 0 12px;font-size:13px;font-weight:700;letter-spacing:0.04em;text-transform:uppercase;color:#5b6b80;">Resumo</p>
      <ul style="margin:0;padding-left:18px;">${items}</ul>
    </div>
  `;
}

function buildVerificationEmail({ appName, name, code, expiresInMinutes }) {
  const greeting = name ? `Olá, ${name}.` : "Olá.";
  const subject = `${appName}: confirme o seu e-mail`;
  const html = wrapHtml(`
    <p style="margin:0 0 12px;font-size:16px;">${greeting}</p>
    <h1 style="margin:0 0 16px;font-size:24px;color:#132033;">Confirme o seu e-mail</h1>
    <p style="margin:0 0 16px;line-height:1.6;">Use o código abaixo para concluir a verificação da sua conta no ${appName}.</p>
    ${buildCodeBlock(code)}
    <p style="margin:0 0 8px;line-height:1.6;">Este código é válido por ${expiresInMinutes} minutos.</p>
    <p style="margin:0;line-height:1.6;color:#516173;">Se você não solicitou este cadastro, ignore esta mensagem.</p>
  `);
  const text = [
    greeting,
    "",
    `Use o código abaixo para confirmar o seu e-mail no ${appName}:`,
    "",
    code,
    "",
    `Validade: ${expiresInMinutes} minutos.`,
    "Se você não solicitou este cadastro, ignore esta mensagem."
  ].join("\n");

  return { subject, html, text };
}

function buildPasswordResetEmail({ appName, name, code, expiresInMinutes }) {
  const greeting = name ? `Olá, ${name}.` : "Olá.";
  const subject = `${appName}: redefinição de senha`;
  const html = wrapHtml(`
    <p style="margin:0 0 12px;font-size:16px;">${greeting}</p>
    <h1 style="margin:0 0 16px;font-size:24px;color:#132033;">Redefina a sua senha</h1>
    <p style="margin:0 0 16px;line-height:1.6;">Recebemos uma solicitação para redefinir a senha da sua conta no ${appName}. Use o código abaixo para continuar.</p>
    ${buildCodeBlock(code)}
    <p style="margin:0 0 8px;line-height:1.6;">Este código é válido por ${expiresInMinutes} minutos.</p>
    <p style="margin:0;line-height:1.6;color:#516173;">Se você não solicitou esta redefinição, ignore esta mensagem e mantenha a sua senha atual.</p>
  `);
  const text = [
    greeting,
    "",
    `Use o código abaixo para redefinir a sua senha no ${appName}:`,
    "",
    code,
    "",
    `Validade: ${expiresInMinutes} minutos.`,
    "Se você não solicitou esta redefinição, ignore esta mensagem."
  ].join("\n");

  return { subject, html, text };
}

function buildDocumentLinkEmail({
  appName,
  name,
  subject,
  title,
  intro,
  buttonLabel,
  buttonUrl,
  details
}) {
  const greeting = name ? `Olá, ${name}.` : "Olá.";
  const detailsBlock = buildDetailsBlock(details);
  const html = wrapHtml(`
    <p style="margin:0 0 12px;font-size:16px;">${greeting}</p>
    <h1 style="margin:0 0 16px;font-size:24px;color:#132033;">${title}</h1>
    <p style="margin:0 0 16px;line-height:1.6;">${intro}</p>
    ${detailsBlock}
    <div style="margin:24px 0 18px;">${buildPrimaryButton(buttonLabel, buttonUrl)}</div>
    <p style="margin:0 0 8px;line-height:1.6;">Se preferir, copie e cole este link no navegador:</p>
    <p style="margin:0 0 16px;line-height:1.6;word-break:break-word;"><a href="${buttonUrl}" style="color:#2563eb;text-decoration:none;">${buttonUrl}</a></p>
    <p style="margin:0;line-height:1.6;color:#516173;">Este e-mail foi enviado automaticamente pelo ${appName}. Se precisar de apoio, responda esta mensagem.</p>
  `);

  const textParts = [greeting, "", title, "", intro];
  const safeDetails = Array.isArray(details) ? details.filter(Boolean) : [];
  if (safeDetails.length) {
    textParts.push("", ...safeDetails);
  }
  textParts.push("", `${buttonLabel}: ${buttonUrl}`, "", `Enviado por ${appName}.`);

  return {
    subject,
    html,
    text: textParts.join("\n")
  };
}

module.exports = {
  buildVerificationEmail,
  buildPasswordResetEmail,
  buildDocumentLinkEmail
};
