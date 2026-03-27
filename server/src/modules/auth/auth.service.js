const bcrypt = require("bcryptjs");

const {
  AppError,
  ConflictError,
  ForbiddenError,
  TooManyRequestsError,
  UnauthorizedError,
  ValidationError
} = require("../../core/errors/app-error");
const { normalizeUser, getUserPermissions } = require("../../core/security/permissions");
const { signToken } = require("../../core/security/auth");
const repository = require("./auth.repository");
const {
  ACCOUNT_STATUS,
  AUTH_CODE_PURPOSES,
  addDays,
  addMinutes,
  buildSessionDeviceKey,
  compareHashedValue,
  generateNumericCode,
  generateRefreshToken,
  getClientIp,
  getClientPlatform,
  getDeviceInfo,
  hashValue,
  inferSessionDeviceName,
  isExpired,
  isSessionOnline,
  maskEmail,
  normalizeEmail,
  normalizeName,
  nowIso,
  parseDurationToMs,
  secondsUntil
} = require("./auth.helpers");

function buildUserPayload(user) {
  return {
    ...normalizeUser(user),
    permissions: getUserPermissions(user)
  };
}

function buildAuthPayload(user, env, session, refreshToken) {
  return {
    token: signToken(user, env, session),
    refreshToken,
    user: buildUserPayload(user),
    session: {
      id: session.id,
      expiresAt: session.expires_at
    }
  };
}

function buildVerificationContext(user, env, activeCode = null) {
  return {
    email: user.email,
    maskedEmail: maskEmail(user.email),
    resendCooldownSeconds: activeCode?.last_sent_at
      ? secondsUntil(addMinutes(new Date(activeCode.last_sent_at), env.auth.resendCooldownSeconds / 60))
      : env.auth.resendCooldownSeconds
  };
}

function ensureEmail(value) {
  const normalized = normalizeEmail(value);
  const emailPattern = /^[^\s@]+@([^\s@]+\.[^\s@]+|local|localhost)$/i;
  if (!normalized || !emailPattern.test(normalized)) {
    throw new ValidationError("Informe um endereço de e-mail válido.");
  }
  return normalized;
}

function ensureName(value) {
  const normalized = normalizeName(value);
  if (!normalized || normalized.length < 3) {
    throw new ValidationError("Informe o nome completo.");
  }
  return normalized;
}

function ensurePassword(value, env) {
  const password = String(value || "");
  const minLength = env.auth.passwordPolicy.minLength;
  if (password.length < minLength) {
    throw new ValidationError(`A senha deve ter pelo menos ${minLength} caracteres.`);
  }
  if (!/[A-Za-z]/.test(password) || !/\d/.test(password)) {
    throw new ValidationError("A senha deve conter pelo menos uma letra e um número.");
  }
  return password;
}

async function enforceRateLimit(db, env, actionKey, scopeKey, message) {
  const config = actionKey === "login" ? env.auth.loginRateLimit : env.auth.emailRateLimit;
  const now = new Date();
  const existing = await repository.findRateLimit(db, actionKey, scopeKey);

  if (existing?.blocked_until && !isExpired(existing.blocked_until)) {
    throw new TooManyRequestsError(message);
  }

  if (!existing) {
    return {
      action_key: actionKey,
      scope_key: scopeKey,
      attempts: 0,
      window_started_at: now.toISOString(),
      blocked_until: null,
      created_at: now.toISOString(),
      updated_at: now.toISOString()
    };
  }

  const windowMs = config.windowMinutes * 60 * 1000;
  const windowStartedAt = new Date(existing.window_started_at).getTime();
  if (!windowStartedAt || Date.now() - windowStartedAt >= windowMs) {
    return {
      ...existing,
      attempts: 0,
      window_started_at: now.toISOString(),
      blocked_until: null,
      updated_at: now.toISOString()
    };
  }

  return existing;
}

async function registerRateLimitHit(db, env, state, message) {
  const config = state.action_key === "login" ? env.auth.loginRateLimit : env.auth.emailRateLimit;
  const nextAttempts = Number(state.attempts || 0) + 1;
  const blockedUntil =
    nextAttempts >= config.maxAttempts
      ? addMinutes(new Date(), config.blockMinutes).toISOString()
      : null;

  await repository.saveRateLimit(db, {
    action_key: state.action_key,
    scope_key: state.scope_key,
    attempts: nextAttempts,
    window_started_at: state.window_started_at || nowIso(),
    blocked_until: blockedUntil,
    created_at: state.created_at || nowIso(),
    updated_at: nowIso()
  });

  if (blockedUntil) {
    throw new TooManyRequestsError(message);
  }
}

async function clearRateLimit(db, state) {
  if (!state) return;
  await repository.clearRateLimit(db, state.action_key, state.scope_key);
}

function createAuthError(code, message, statusCode = 400, details) {
  return new AppError(message, {
    code,
    statusCode,
    details,
    exposeDetails: details !== undefined
  });
}

async function issueCode({
  db,
  env,
  emailService,
  user,
  purpose,
  existingCode,
  resend = false
}) {
  const now = new Date();
  const ttlMinutes =
    purpose === AUTH_CODE_PURPOSES.EMAIL_VERIFICATION
      ? env.auth.verificationCodeTtlMinutes
      : env.auth.passwordResetCodeTtlMinutes;
  const code = generateNumericCode(env.auth.codeDigits);
  const codeHash = hashValue(code, env.authCodeSecret);

  await repository.invalidateAuthCodes(db, user.id, purpose, now.toISOString());

  const storedCode = await repository.createAuthCode(db, {
    user_id: user.id,
    purpose,
    code_hash: codeHash,
    expires_at: addMinutes(now, ttlMinutes).toISOString(),
    consumed_at: null,
    created_at: now.toISOString(),
    last_sent_at: now.toISOString(),
    resend_count: resend ? Number(existingCode?.resend_count || 0) + 1 : 0,
    attempt_count: 0
  });

  try {
    if (purpose === AUTH_CODE_PURPOSES.EMAIL_VERIFICATION) {
      await emailService.sendVerificationCode({
        to: user.email,
        name: user.name,
        code,
        expiresInMinutes: ttlMinutes
      });
    } else {
      await emailService.sendPasswordResetCode({
        to: user.email,
        name: user.name,
        code,
        expiresInMinutes: ttlMinutes
      });
    }
  } catch (error) {
    throw new AppError(
      "Não foi possível enviar o código por e-mail no momento. Tente novamente em instantes.",
      { code: "email_delivery_failed", statusCode: 503 }
    );
  }

  return storedCode;
}

async function createSessionForUser(db, env, user, req) {
  const refreshToken = generateRefreshToken();
  const now = new Date();
  const session = await repository.createSession(db, {
    user_id: user.id,
    token_hash: hashValue(refreshToken, env.authCodeSecret),
    created_at: now.toISOString(),
    expires_at: addDays(now, env.refreshTokenTtlDays).toISOString(),
    revoked_at: null,
    last_used_at: now.toISOString(),
    device_info: getDeviceInfo(req),
    ip_address: getClientIp(req),
    platform: getClientPlatform(req)
  });

  return buildAuthPayload(user, env, session, refreshToken);
}

function requirePendingVerification(user) {
  if (!user) {
    throw createAuthError(
      "invalid_verification_code",
      "O código informado é inválido ou já expirou."
    );
  }
  if (user.email_verified || user.status === ACCOUNT_STATUS.ACTIVE) {
    throw createAuthError("email_already_verified", "A conta já foi verificada.", 409);
  }
}

async function validateCode({ db, env, user, purpose, code, invalidCodeMessage, expiredCodeMessage }) {
  const currentCode = await repository.findLatestActiveAuthCode(db, user.id, purpose);
  if (!currentCode) {
    throw createAuthError("auth_code_invalid", invalidCodeMessage);
  }

  if (isExpired(currentCode.expires_at)) {
    await repository.consumeAuthCode(db, currentCode.id, nowIso());
    throw createAuthError("auth_code_expired", expiredCodeMessage);
  }

  if (Number(currentCode.attempt_count || 0) >= env.auth.maxCodeAttempts) {
    await repository.consumeAuthCode(db, currentCode.id, nowIso());
    throw createAuthError(
      "auth_code_attempts_exceeded",
      "O código informado não pôde mais ser validado. Solicite um novo envio."
    );
  }

  const valid = compareHashedValue(code, currentCode.code_hash, env.authCodeSecret);
  if (!valid) {
    await repository.incrementAuthCodeAttempt(
      db,
      currentCode.id,
      Number(currentCode.attempt_count || 0) + 1
    );
    throw createAuthError("auth_code_invalid", invalidCodeMessage);
  }

  return currentCode;
}

async function register(db, env, emailService, payload, req) {
  const name = ensureName(payload.name);
  const email = ensureEmail(payload.email);
  const password = ensurePassword(payload.password, env);
  const rateState = await enforceRateLimit(
    db,
    env,
    "register",
    `register:${email}:${getClientIp(req) || "unknown"}`,
    "Muitas tentativas de cadastro em pouco tempo. Aguarde alguns minutos e tente novamente."
  );
  await registerRateLimitHit(
    db,
    env,
    rateState,
    "Muitas tentativas de cadastro em pouco tempo. Aguarde alguns minutos e tente novamente."
  );

  const exists = await repository.findAuthUserByEmail(db, email);
  if (exists) {
    throw new ConflictError("Já existe uma conta cadastrada com este e-mail.");
  }

  const now = nowIso();
  const password_hash = await bcrypt.hash(password, 12);
  const user = await repository.createPendingUser(db, {
    name,
    email,
    role: "visitante",
    password_hash,
    permissions: [],
    status: ACCOUNT_STATUS.PENDING_VERIFICATION,
    email_verified: false,
    email_verified_at: null,
    last_login_at: null,
    password_changed_at: now
  });

  const code = await issueCode({
    db,
    env,
    emailService,
    user,
    purpose: AUTH_CODE_PURPOSES.EMAIL_VERIFICATION
  });

  return {
    account: buildUserPayload(user),
    nextStep: "verify_email",
    message:
      "Conta criada com sucesso. Enviamos um código de verificação para o seu e-mail.",
    verification: {
      email,
      maskedEmail: maskEmail(email),
      expiresAt: code.expires_at,
      resendCooldownSeconds: env.auth.resendCooldownSeconds
    }
  };
}

async function login(db, env, payload, req) {
  const email = ensureEmail(payload.email);
  const password = String(payload.password || "");
  if (!password) {
    throw new ValidationError("Informe a senha.");
  }

  const rateState = await enforceRateLimit(
    db,
    env,
    "login",
    `login:${email}:${getClientIp(req) || "unknown"}`,
    "Muitas tentativas de login em pouco tempo. Aguarde alguns minutos e tente novamente."
  );

  const rawUser = await repository.findAuthUserByEmail(db, email);
  if (!rawUser || !rawUser.password_hash) {
    await registerRateLimitHit(
      db,
      env,
      rateState,
      "Muitas tentativas de login em pouco tempo. Aguarde alguns minutos e tente novamente."
    );
    throw createAuthError(
      "invalid_credentials",
      "Não foi possível autenticar com os dados informados.",
      401
    );
  }

  const validPassword = await bcrypt.compare(password, rawUser.password_hash);
  if (!validPassword) {
    await registerRateLimitHit(
      db,
      env,
      rateState,
      "Muitas tentativas de login em pouco tempo. Aguarde alguns minutos e tente novamente."
    );
    throw createAuthError(
      "invalid_credentials",
      "Não foi possível autenticar com os dados informados.",
      401
    );
  }

  if (rawUser.status === ACCOUNT_STATUS.BLOCKED) {
    throw new ForbiddenError("A sua conta está temporariamente indisponível.");
  }

  if (!rawUser.email_verified || rawUser.status === ACCOUNT_STATUS.PENDING_VERIFICATION) {
    const activeCode = await repository.findLatestActiveAuthCode(
      db,
      rawUser.id,
      AUTH_CODE_PURPOSES.EMAIL_VERIFICATION
    );
    throw createAuthError(
      "email_verification_required",
      "Sua conta ainda não foi verificada. Informe o código enviado por e-mail.",
      403,
      buildVerificationContext(rawUser, env, activeCode)
    );
  }

  await clearRateLimit(db, rateState);
  await repository.touchUserLogin(db, rawUser.id, nowIso());
  const user = await repository.findAuthUserById(db, rawUser.id);
  return createSessionForUser(db, env, user, req);
}

async function verifyEmail(db, env, emailService, payload, req) {
  const email = ensureEmail(payload.email);
  const code = String(payload.code || "").trim();
  if (!/^\d+$/.test(code)) {
    throw new ValidationError("Informe o código de verificação.");
  }

  const user = await repository.findAuthUserByEmail(db, email);
  requirePendingVerification(user);

  const validatedCode = await validateCode({
    db,
    env,
    user,
    purpose: AUTH_CODE_PURPOSES.EMAIL_VERIFICATION,
    code,
    invalidCodeMessage: "O código de verificação informado é inválido.",
    expiredCodeMessage:
      "O código de verificação expirou. Solicite um novo envio para continuar."
  });

  await repository.consumeAuthCode(db, validatedCode.id, nowIso());
  const verifiedUser = await repository.markUserEmailVerified(db, user.id, {
    email_verified_at: nowIso(),
    status: ACCOUNT_STATUS.ACTIVE
  });
  await repository.touchUserLogin(db, user.id, nowIso());

  const authPayload = await createSessionForUser(db, env, verifiedUser, req);
  return {
    ...authPayload,
    message: "E-mail confirmado com sucesso."
  };
}

async function resendVerificationCode(db, env, emailService, payload, req) {
  const email = ensureEmail(payload.email);
  const rateState = await enforceRateLimit(
    db,
    env,
    "verification_email",
    `verification:${email}:${getClientIp(req) || "unknown"}`,
    "Você solicitou códigos demais em pouco tempo. Aguarde alguns minutos antes de tentar novamente."
  );

  const user = await repository.findAuthUserByEmail(db, email);
  if (!user || user.email_verified || user.status === ACCOUNT_STATUS.ACTIVE) {
    return {
      ok: true,
      message:
        "Se a conta ainda estiver pendente de verificação, enviaremos um novo código por e-mail."
    };
  }

  const existingCode = await repository.findLatestActiveAuthCode(
    db,
    user.id,
    AUTH_CODE_PURPOSES.EMAIL_VERIFICATION
  );

  if (existingCode?.last_sent_at && secondsUntil(addMinutes(new Date(existingCode.last_sent_at), env.auth.resendCooldownSeconds / 60)) > 0) {
    throw new TooManyRequestsError(
      "Aguarde alguns instantes antes de solicitar um novo código."
    );
  }

  await registerRateLimitHit(
    db,
    env,
    rateState,
    "Você solicitou códigos demais em pouco tempo. Aguarde alguns minutos antes de tentar novamente."
  );

  const code = await issueCode({
    db,
    env,
    emailService,
    user,
    purpose: AUTH_CODE_PURPOSES.EMAIL_VERIFICATION,
    existingCode,
    resend: true
  });

  return {
    ok: true,
    message: "Enviamos um novo código de verificação.",
    verification: {
      email,
      maskedEmail: maskEmail(email),
      expiresAt: code.expires_at,
      resendCooldownSeconds: env.auth.resendCooldownSeconds
    }
  };
}

async function forgotPassword(db, env, emailService, payload, req) {
  const email = ensureEmail(payload.email);
  const rateState = await enforceRateLimit(
    db,
    env,
    "password_reset_email",
    `password-reset:${email}:${getClientIp(req) || "unknown"}`,
    "Você solicitou redefinições demais em pouco tempo. Aguarde alguns minutos antes de tentar novamente."
  );

  const user = await repository.findAuthUserByEmail(db, email);

  await registerRateLimitHit(
    db,
    env,
    rateState,
    "Você solicitou redefinições demais em pouco tempo. Aguarde alguns minutos antes de tentar novamente."
  );

  if (user) {
    const existingCode = await repository.findLatestActiveAuthCode(
      db,
      user.id,
      AUTH_CODE_PURPOSES.PASSWORD_RESET
    );
    if (
      existingCode?.last_sent_at &&
      secondsUntil(addMinutes(new Date(existingCode.last_sent_at), env.auth.resendCooldownSeconds / 60)) > 0
    ) {
      return {
        ok: true,
        message:
          "Se o e-mail informado estiver cadastrado, você receberá um código para redefinir sua senha."
      };
    }

    await issueCode({
      db,
      env,
      emailService,
      user,
      purpose: AUTH_CODE_PURPOSES.PASSWORD_RESET,
      existingCode,
      resend: Boolean(existingCode)
    });
  }

  return {
    ok: true,
    message:
      "Se o e-mail informado estiver cadastrado, você receberá um código para redefinir sua senha."
  };
}

async function verifyPasswordResetCode(db, env, payload) {
  const email = ensureEmail(payload.email);
  const code = String(payload.code || "").trim();
  if (!/^\d+$/.test(code)) {
    throw new ValidationError("Informe o código de recuperação.");
  }

  const user = await repository.findAuthUserByEmail(db, email);
  if (!user) {
    throw createAuthError(
      "password_reset_invalid",
      "O código de recuperação informado é inválido ou expirou."
    );
  }

  await validateCode({
    db,
    env,
    user,
    purpose: AUTH_CODE_PURPOSES.PASSWORD_RESET,
    code,
    invalidCodeMessage: "O código de recuperação informado é inválido.",
    expiredCodeMessage:
      "O código de recuperação expirou. Solicite um novo envio para continuar."
  });

  return {
    ok: true,
    message: "Código validado com sucesso. Agora defina a nova senha."
  };
}

async function resetPassword(db, env, payload) {
  const email = ensureEmail(payload.email);
  const code = String(payload.code || "").trim();
  const password = ensurePassword(payload.password, env);
  const user = await repository.findAuthUserByEmail(db, email);
  if (!user) {
    throw createAuthError(
      "password_reset_invalid",
      "Não foi possível concluir a redefinição de senha."
    );
  }

  const validatedCode = await validateCode({
    db,
    env,
    user,
    purpose: AUTH_CODE_PURPOSES.PASSWORD_RESET,
    code,
    invalidCodeMessage: "O código de recuperação informado é inválido.",
    expiredCodeMessage:
      "O código de recuperação expirou. Solicite um novo envio para continuar."
  });

  await repository.consumeAuthCode(db, validatedCode.id, nowIso());
  await repository.invalidateAuthCodes(db, user.id, AUTH_CODE_PURPOSES.PASSWORD_RESET, nowIso());
  await repository.revokeUserSessions(db, user.id, nowIso());
  await repository.updateUserPassword(db, user.id, {
    password_hash: await bcrypt.hash(password, 12),
    password_changed_at: nowIso()
  });

  return {
    ok: true,
    message: "Senha redefinida com sucesso. Faça login novamente para continuar."
  };
}

async function refresh(db, env, payload, req) {
  const refreshToken = String(payload.refreshToken || "").trim();
  if (!refreshToken) {
    throw new UnauthorizedError("Não foi possível renovar a sessão.");
  }

  const session = await repository.findSessionByTokenHash(
    db,
    hashValue(refreshToken, env.authCodeSecret)
  );

  if (!session || session.revoked_at || isExpired(session.expires_at)) {
    throw new UnauthorizedError("Sua sessão expirou. Faça login novamente para continuar.");
  }

  const user = await repository.findAuthUserById(db, session.user_id);
  if (!user || !user.email_verified || user.status !== ACCOUNT_STATUS.ACTIVE) {
    throw new UnauthorizedError("Sua sessão expirou. Faça login novamente para continuar.");
  }

  const nextRefreshToken = generateRefreshToken();
  const rotatedSession = await repository.rotateSessionToken(db, session.id, {
    token_hash: hashValue(nextRefreshToken, env.authCodeSecret),
    expires_at: addDays(new Date(), env.refreshTokenTtlDays).toISOString(),
    last_used_at: nowIso(),
    device_info: getDeviceInfo(req) || session.device_info,
    ip_address: getClientIp(req) || session.ip_address,
    platform: getClientPlatform(req) || session.platform
  });

  return buildAuthPayload(user, env, rotatedSession, nextRefreshToken);
}

async function logout(db, req) {
  if (req.auth?.sessionId) {
    await repository.revokeSession(db, req.auth.sessionId, nowIso());
  }
  return { ok: true };
}

async function logoutAll(db, req) {
  if (req.user?.id) {
    await repository.revokeUserSessions(db, req.user.id, nowIso());
  }
  return { ok: true };
}

function getOnlineSessionWindowMs(env) {
  const accessTokenMs = parseDurationToMs(env.accessTokenTtl || env.jwtTtl, 15 * 60 * 1000);
  // A folga evita esconder uma sessão logo antes da renovação natural do access token.
  return Math.max(accessTokenMs + 5 * 60 * 1000, 10 * 60 * 1000);
}

function buildOnlineSessions(sessions, env, currentSessionId) {
  const onlineWindowMs = getOnlineSessionWindowMs(env);
  const nowMs = Date.now();
  const seenDevices = new Set();
  const result = [];

  for (const session of sessions) {
    if (!isSessionOnline(session, onlineWindowMs, nowMs)) {
      continue;
    }

    const deviceName = inferSessionDeviceName(session);
    const deviceKey = buildSessionDeviceKey(session);
    if (seenDevices.has(deviceKey)) {
      continue;
    }

    seenDevices.add(deviceKey);
    result.push({
      id: session.id,
      createdAt: session.created_at,
      expiresAt: session.expires_at,
      revokedAt: session.revoked_at,
      lastUsedAt: session.last_used_at,
      deviceInfo: session.device_info,
      deviceName,
      ipAddress: session.ip_address,
      platform: session.platform,
      isCurrent: currentSessionId != null && Number(session.id) == Number(currentSessionId),
      isActive: true
    });
  }

  return result;
}

async function me(db, env, userId, currentSessionId = null) {
  const user = await repository.findAuthUserById(db, userId);
  if (!user) {
    throw new UnauthorizedError("Sua sessão expirou. Faça login novamente para continuar.");
  }

  const sessions = await repository.listUserSessions(db, userId);
  const onlineSessions = buildOnlineSessions(sessions, env, currentSessionId);

  return {
    user: buildUserPayload(user),
    account: {
      status: user.status,
      emailVerified: Boolean(user.email_verified),
      emailVerifiedAt: user.email_verified_at,
      lastLoginAt: user.last_login_at,
      passwordChangedAt: user.password_changed_at
    },
    sessions: onlineSessions,
    sessionSummary: {
      total: sessions.length,
      active: onlineSessions.length,
      online: onlineSessions.length
    }
  };
}

module.exports = {
  buildAuthPayload,
  forgotPassword,
  login,
  logout,
  logoutAll,
  me,
  refresh,
  register,
  resendVerificationCode,
  resetPassword,
  verifyEmail,
  verifyPasswordResetCode
};
