const test = require("node:test");
const assert = require("node:assert/strict");

const bcrypt = require("bcryptjs");
const { open } = require("sqlite");
const sqlite3 = require("sqlite3");

const authService = require("../src/modules/auth/auth.service");

const TEST_ENV = {
  jwtSecret: "test-secret",
  jwtTtl: "15m",
  accessTokenTtl: "15m",
  refreshTokenTtlDays: 30,
  authCodeSecret: "auth-secret",
  auth: {
    codeDigits: 6,
    verificationCodeTtlMinutes: 15,
    passwordResetCodeTtlMinutes: 15,
    resendCooldownSeconds: 60,
    maxCodeAttempts: 5,
    loginRateLimit: {
      maxAttempts: 5,
      windowMinutes: 15,
      blockMinutes: 15
    },
    emailRateLimit: {
      maxAttempts: 5,
      windowMinutes: 60,
      blockMinutes: 60
    },
    passwordPolicy: {
      minLength: 8
    }
  }
};

const TEST_REQUEST = {
  headers: {
    "x-client-platform": "web",
    "user-agent": "test-runner"
  },
  ip: "127.0.0.1"
};

async function createDb() {
  const db = await open({
    filename: ":memory:",
    driver: sqlite3.Database
  });

  await db.exec(`
    CREATE TABLE roles (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      key TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      permissions TEXT,
      is_admin INTEGER DEFAULT 0
    );

    CREATE TABLE users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      email TEXT,
      role TEXT,
      password_hash TEXT,
      permissions TEXT,
      email_verified INTEGER DEFAULT 0,
      email_verified_at TEXT,
      status TEXT DEFAULT 'pending_verification',
      last_login_at TEXT,
      password_changed_at TEXT
    );

    CREATE TABLE auth_codes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      purpose TEXT NOT NULL,
      code_hash TEXT NOT NULL,
      expires_at TEXT NOT NULL,
      consumed_at TEXT,
      created_at TEXT NOT NULL,
      last_sent_at TEXT NOT NULL,
      resend_count INTEGER DEFAULT 0,
      attempt_count INTEGER DEFAULT 0
    );

    CREATE TABLE auth_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      token_hash TEXT NOT NULL,
      created_at TEXT NOT NULL,
      expires_at TEXT NOT NULL,
      revoked_at TEXT,
      last_used_at TEXT,
      device_info TEXT,
      ip_address TEXT,
      platform TEXT
    );

    CREATE TABLE auth_rate_limits (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      action_key TEXT NOT NULL,
      scope_key TEXT NOT NULL,
      attempts INTEGER DEFAULT 0,
      window_started_at TEXT NOT NULL,
      blocked_until TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  `);

  await db.run(
    "INSERT INTO roles (key, name, permissions, is_admin) VALUES (?, ?, ?, ?)",
    ["visitante", "Visitante", JSON.stringify([]), 0]
  );

  return db;
}

function createEmailService() {
  const sent = [];
  return {
    sent,
    async sendVerificationCode(payload) {
      sent.push({ kind: "verification", ...payload });
    },
    async sendPasswordResetCode(payload) {
      sent.push({ kind: "password_reset", ...payload });
    }
  };
}

async function createVerifiedUser(db, password = "Senha123", email = "teste@empresa.com") {
  const passwordHash = await bcrypt.hash(password, 10);
  const result = await db.run(
    `INSERT INTO users (
      name,
      email,
      role,
      password_hash,
      permissions,
      status,
      email_verified,
      email_verified_at,
      password_changed_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      "Usuário de Teste",
      email,
      "visitante",
      passwordHash,
      JSON.stringify([]),
      "active",
      1,
      new Date().toISOString(),
      new Date().toISOString()
    ]
  );

  return result.lastID;
}

test("login accepts local development addresses such as admin@local", async () => {
  const db = await createDb();
  await createVerifiedUser(db, "Senha123", "admin@local");

  const loginResult = await authService.login(
    db,
    TEST_ENV,
    { email: "admin@local", password: "Senha123" },
    TEST_REQUEST
  );

  assert.ok(loginResult.token);
  assert.ok(loginResult.refreshToken);
  assert.equal(loginResult.user.email, "admin@local");
});

test("register creates a pending account and verifyEmail activates the user session", async () => {
  const db = await createDb();
  const emailService = createEmailService();

  const registerResult = await authService.register(
    db,
    TEST_ENV,
    emailService,
    {
      name: "Maria de Souza",
      email: "maria@empresa.com",
      password: "Senha123"
    },
    TEST_REQUEST
  );

  assert.equal(registerResult.nextStep, "verify_email");
  assert.equal(registerResult.account.email_verified, false);
  assert.equal(emailService.sent.length, 1);
  assert.equal(emailService.sent[0].kind, "verification");

  await assert.rejects(
    () =>
      authService.login(
        db,
        TEST_ENV,
        { email: "maria@empresa.com", password: "Senha123" },
        TEST_REQUEST
      ),
    (error) => error.code === "email_verification_required"
  );

  const verifyResult = await authService.verifyEmail(
    db,
    TEST_ENV,
    emailService,
    {
      email: "maria@empresa.com",
      code: emailService.sent[0].code
    },
    TEST_REQUEST
  );

  assert.ok(verifyResult.token);
  assert.ok(verifyResult.refreshToken);
  assert.equal(verifyResult.user.email_verified, true);
  assert.equal(verifyResult.user.status, "active");
});

test("password reset revokes previous sessions and accepts the new password", async () => {
  const db = await createDb();
  const emailService = createEmailService();
  await createVerifiedUser(db, "Senha123");

  const loginResult = await authService.login(
    db,
    TEST_ENV,
    { email: "teste@empresa.com", password: "Senha123" },
    TEST_REQUEST
  );

  assert.ok(loginResult.refreshToken);

  const forgotResult = await authService.forgotPassword(
    db,
    TEST_ENV,
    emailService,
    { email: "teste@empresa.com" },
    TEST_REQUEST
  );

  assert.equal(forgotResult.ok, true);
  assert.equal(emailService.sent.at(-1).kind, "password_reset");

  const verifyCodeResult = await authService.verifyPasswordResetCode(db, TEST_ENV, {
    email: "teste@empresa.com",
    code: emailService.sent.at(-1).code
  });

  assert.equal(verifyCodeResult.ok, true);

  const resetResult = await authService.resetPassword(db, TEST_ENV, {
    email: "teste@empresa.com",
    code: emailService.sent.at(-1).code,
    password: "NovaSenha123"
  });

  assert.equal(resetResult.ok, true);

  const revokedSession = await db.get(
    "SELECT revoked_at FROM auth_sessions WHERE user_id = 1 ORDER BY id DESC LIMIT 1"
  );
  assert.ok(revokedSession.revoked_at);

  await assert.rejects(
    () =>
      authService.login(
        db,
        TEST_ENV,
        { email: "teste@empresa.com", password: "Senha123" },
        TEST_REQUEST
      ),
    (error) => error.code === "invalid_credentials"
  );

  const nextLogin = await authService.login(
    db,
    TEST_ENV,
    { email: "teste@empresa.com", password: "NovaSenha123" },
    TEST_REQUEST
  );

  assert.ok(nextLogin.token);
  assert.ok(nextLogin.refreshToken);
});

test("refresh rotates the refresh token and invalidates the previous session token hash", async () => {
  const db = await createDb();
  await createVerifiedUser(db, "Senha123");

  const loginResult = await authService.login(
    db,
    TEST_ENV,
    { email: "teste@empresa.com", password: "Senha123" },
    TEST_REQUEST
  );

  const refreshResult = await authService.refresh(
    db,
    TEST_ENV,
    { refreshToken: loginResult.refreshToken },
    TEST_REQUEST
  );

  assert.ok(refreshResult.token);
  assert.ok(refreshResult.refreshToken);
  assert.notEqual(refreshResult.refreshToken, loginResult.refreshToken);

  await assert.rejects(
    () =>
      authService.refresh(
        db,
        TEST_ENV,
        { refreshToken: loginResult.refreshToken },
        TEST_REQUEST
      ),
    (error) => error.statusCode === 401
  );
});

test("login rate limit blocks repeated invalid attempts", async () => {
  const db = await createDb();
  await createVerifiedUser(db, "Senha123");
  const env = {
    ...TEST_ENV,
    auth: {
      ...TEST_ENV.auth,
      loginRateLimit: {
        maxAttempts: 2,
        windowMinutes: 15,
        blockMinutes: 15
      }
    }
  };

  await assert.rejects(
    () =>
      authService.login(
        db,
        env,
        { email: "teste@empresa.com", password: "SenhaErrada1" },
        TEST_REQUEST
      ),
    (error) => error.code === "invalid_credentials"
  );

  await assert.rejects(
    () =>
      authService.login(
        db,
        env,
        { email: "teste@empresa.com", password: "SenhaErrada1" },
        TEST_REQUEST
      ),
    (error) => error.code === "rate_limited"
  );
});
