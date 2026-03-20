const SQLITE_INITIAL_SCHEMA = `
  PRAGMA foreign_keys = ON;

  CREATE TABLE IF NOT EXISTS users (
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

  CREATE TABLE IF NOT EXISTS roles (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    key TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    permissions TEXT,
    is_admin INTEGER DEFAULT 0
  );

  CREATE TABLE IF NOT EXISTS clients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    cnpj TEXT,
    address TEXT,
    contact TEXT
  );

  CREATE TABLE IF NOT EXISTS products (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    sku TEXT,
    price REAL DEFAULT 0,
    unit TEXT
  );

  CREATE TABLE IF NOT EXISTS report_templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    structure TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS task_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT,
    report_template_id INTEGER,
    FOREIGN KEY (report_template_id) REFERENCES report_templates (id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS equipments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    client_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    model TEXT,
    serial TEXT,
    description TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT,
    client_id INTEGER,
    user_id INTEGER,
    task_type_id INTEGER,
    status TEXT,
    priority TEXT,
    start_date TEXT,
    due_date TEXT,
    signature_mode TEXT,
    signature_scope TEXT,
    signature_client TEXT,
    signature_client_name TEXT,
    signature_client_document TEXT,
    signature_tech TEXT,
    signature_pages TEXT,
    FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
    FOREIGN KEY (task_type_id) REFERENCES task_types (id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT,
    task_id INTEGER,
    client_id INTEGER,
    template_id INTEGER,
    equipment_id INTEGER,
    content TEXT,
    status TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE SET NULL,
    FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL,
    FOREIGN KEY (template_id) REFERENCES report_templates (id) ON DELETE SET NULL,
    FOREIGN KEY (equipment_id) REFERENCES equipments (id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS task_equipments (
    task_id INTEGER NOT NULL,
    equipment_id INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    PRIMARY KEY (task_id, equipment_id),
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    FOREIGN KEY (equipment_id) REFERENCES equipments (id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS budgets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    client_id INTEGER,
    task_id INTEGER,
    report_id INTEGER,
    notes TEXT,
    internal_note TEXT,
    proposal_validity TEXT,
    payment_terms TEXT,
    service_deadline TEXT,
    product_validity TEXT,
    status TEXT,
    signature_mode TEXT,
    signature_scope TEXT,
    signature_client TEXT,
    signature_client_name TEXT,
    signature_client_document TEXT,
    signature_tech TEXT,
    signature_pages TEXT,
    subtotal REAL DEFAULT 0,
    discount REAL DEFAULT 0,
    tax REAL DEFAULT 0,
    total REAL DEFAULT 0,
    created_at TEXT NOT NULL,
    FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL,
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE SET NULL,
    FOREIGN KEY (report_id) REFERENCES reports (id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS budget_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    budget_id INTEGER NOT NULL,
    product_id INTEGER,
    description TEXT NOT NULL,
    qty REAL DEFAULT 1,
    unit_price REAL DEFAULT 0,
    total REAL DEFAULT 0,
    FOREIGN KEY (budget_id) REFERENCES budgets (id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS task_public_links (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER NOT NULL,
    token TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL,
    created_by_user_id INTEGER,
    expires_at TEXT,
    revoked_at TEXT,
    last_used_at TEXT,
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL
  );

  CREATE INDEX IF NOT EXISTS idx_task_public_links_task_id
    ON task_public_links (task_id);

  CREATE TABLE IF NOT EXISTS budget_public_links (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    budget_id INTEGER NOT NULL,
    token TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL,
    created_by_user_id INTEGER,
    expires_at TEXT,
    revoked_at TEXT,
    last_used_at TEXT,
    FOREIGN KEY (budget_id) REFERENCES budgets (id) ON DELETE CASCADE,
    FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL
  );

  CREATE INDEX IF NOT EXISTS idx_budget_public_links_budget_id
    ON budget_public_links (budget_id);

  CREATE TABLE IF NOT EXISTS auth_codes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    purpose TEXT NOT NULL,
    code_hash TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    consumed_at TEXT,
    created_at TEXT NOT NULL,
    last_sent_at TEXT NOT NULL,
    resend_count INTEGER DEFAULT 0,
    attempt_count INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_auth_codes_user_purpose
    ON auth_codes (user_id, purpose, created_at DESC);

  CREATE TABLE IF NOT EXISTS auth_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    token_hash TEXT NOT NULL,
    created_at TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    revoked_at TEXT,
    last_used_at TEXT,
    device_info TEXT,
    ip_address TEXT,
    platform TEXT,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
  );

  CREATE UNIQUE INDEX IF NOT EXISTS idx_auth_sessions_token_hash
    ON auth_sessions (token_hash);
  CREATE INDEX IF NOT EXISTS idx_auth_sessions_user_id
    ON auth_sessions (user_id, created_at DESC);

  CREATE TABLE IF NOT EXISTS auth_rate_limits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    action_key TEXT NOT NULL,
    scope_key TEXT NOT NULL,
    attempts INTEGER DEFAULT 0,
    window_started_at TEXT NOT NULL,
    blocked_until TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  );

  CREATE UNIQUE INDEX IF NOT EXISTS idx_auth_rate_limits_scope
    ON auth_rate_limits (action_key, scope_key);

  CREATE TABLE IF NOT EXISTS error_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL,
    severity TEXT NOT NULL,
    category TEXT,
    error_code TEXT,
    friendly_message TEXT NOT NULL,
    technical_message TEXT,
    stack_trace TEXT,
    http_status INTEGER,
    http_method TEXT,
    endpoint TEXT,
    module TEXT,
    platform TEXT,
    screen_route TEXT,
    operation TEXT,
    request_id TEXT,
    environment TEXT,
    user_id INTEGER,
    user_name TEXT,
    user_email TEXT,
    context_json TEXT,
    payload_json TEXT,
    resolved_at TEXT,
    resolved_by_user_id INTEGER,
    resolution_note TEXT,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
    FOREIGN KEY (resolved_by_user_id) REFERENCES users (id) ON DELETE SET NULL
  );

  CREATE INDEX IF NOT EXISTS idx_error_logs_created_at
    ON error_logs (created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_error_logs_severity
    ON error_logs (severity);
  CREATE INDEX IF NOT EXISTS idx_error_logs_module
    ON error_logs (module);
  CREATE INDEX IF NOT EXISTS idx_error_logs_platform
    ON error_logs (platform);

  CREATE TABLE IF NOT EXISTS event_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL,
    action TEXT NOT NULL,
    description TEXT NOT NULL,
    module TEXT,
    entity_type TEXT,
    entity_id TEXT,
    outcome TEXT NOT NULL,
    platform TEXT,
    ip_address TEXT,
    route_path TEXT,
    http_method TEXT,
    request_id TEXT,
    user_id INTEGER,
    user_name TEXT,
    user_email TEXT,
    user_role TEXT,
    metadata_json TEXT,
    before_json TEXT,
    after_json TEXT,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
  );

  CREATE INDEX IF NOT EXISTS idx_event_logs_created_at
    ON event_logs (created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_event_logs_action
    ON event_logs (action);
  CREATE INDEX IF NOT EXISTS idx_event_logs_module
    ON event_logs (module);
  CREATE INDEX IF NOT EXISTS idx_event_logs_platform
    ON event_logs (platform);
`;

const POSTGRES_INITIAL_SCHEMA = `
  CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT,
    role TEXT,
    password_hash TEXT,
    permissions TEXT,
    email_verified BOOLEAN DEFAULT FALSE,
    email_verified_at TEXT,
    status TEXT DEFAULT 'pending_verification',
    last_login_at TEXT,
    password_changed_at TEXT
  );

  CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    key TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    permissions TEXT,
    is_admin BOOLEAN DEFAULT FALSE
  );

  CREATE TABLE IF NOT EXISTS clients (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    cnpj TEXT,
    address TEXT,
    contact TEXT
  );

  CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    sku TEXT,
    price DOUBLE PRECISION DEFAULT 0,
    unit TEXT
  );

  CREATE TABLE IF NOT EXISTS report_templates (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    structure TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS task_types (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    report_template_id INTEGER,
    FOREIGN KEY (report_template_id) REFERENCES report_templates (id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS equipments (
    id SERIAL PRIMARY KEY,
    client_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    model TEXT,
    serial TEXT,
    description TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    client_id INTEGER,
    user_id INTEGER,
    task_type_id INTEGER,
    status TEXT,
    priority TEXT,
    start_date TEXT,
    due_date TEXT,
    signature_mode TEXT,
    signature_scope TEXT,
    signature_client TEXT,
    signature_tech TEXT,
    signature_pages TEXT,
    FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
    FOREIGN KEY (task_type_id) REFERENCES task_types (id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS reports (
    id SERIAL PRIMARY KEY,
    title TEXT,
    task_id INTEGER,
    client_id INTEGER,
    template_id INTEGER,
    equipment_id INTEGER,
    content TEXT,
    status TEXT,
    created_at TEXT NOT NULL,
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE SET NULL,
    FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL,
    FOREIGN KEY (template_id) REFERENCES report_templates (id) ON DELETE SET NULL,
    FOREIGN KEY (equipment_id) REFERENCES equipments (id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS task_equipments (
    task_id INTEGER NOT NULL,
    equipment_id INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    PRIMARY KEY (task_id, equipment_id),
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    FOREIGN KEY (equipment_id) REFERENCES equipments (id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS budgets (
    id SERIAL PRIMARY KEY,
    client_id INTEGER,
    task_id INTEGER,
    report_id INTEGER,
    notes TEXT,
    internal_note TEXT,
    proposal_validity TEXT,
    payment_terms TEXT,
    service_deadline TEXT,
    product_validity TEXT,
    status TEXT,
    signature_mode TEXT,
    signature_scope TEXT,
    signature_client TEXT,
    signature_tech TEXT,
    signature_pages TEXT,
    subtotal DOUBLE PRECISION DEFAULT 0,
    discount DOUBLE PRECISION DEFAULT 0,
    tax DOUBLE PRECISION DEFAULT 0,
    total DOUBLE PRECISION DEFAULT 0,
    created_at TEXT NOT NULL,
    FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL,
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE SET NULL,
    FOREIGN KEY (report_id) REFERENCES reports (id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS budget_items (
    id SERIAL PRIMARY KEY,
    budget_id INTEGER NOT NULL,
    product_id INTEGER,
    description TEXT NOT NULL,
    qty DOUBLE PRECISION DEFAULT 1,
    unit_price DOUBLE PRECISION DEFAULT 0,
    total DOUBLE PRECISION DEFAULT 0,
    FOREIGN KEY (budget_id) REFERENCES budgets (id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE SET NULL
  );

  CREATE TABLE IF NOT EXISTS task_public_links (
    id SERIAL PRIMARY KEY,
    task_id INTEGER NOT NULL,
    token TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL,
    created_by_user_id INTEGER,
    expires_at TEXT,
    revoked_at TEXT,
    last_used_at TEXT,
    FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL
  );

  CREATE INDEX IF NOT EXISTS idx_task_public_links_task_id
    ON task_public_links (task_id);

  CREATE TABLE IF NOT EXISTS budget_public_links (
    id SERIAL PRIMARY KEY,
    budget_id INTEGER NOT NULL,
    token TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL,
    created_by_user_id INTEGER,
    expires_at TEXT,
    revoked_at TEXT,
    last_used_at TEXT,
    FOREIGN KEY (budget_id) REFERENCES budgets (id) ON DELETE CASCADE,
    FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL
  );

  CREATE INDEX IF NOT EXISTS idx_budget_public_links_budget_id
    ON budget_public_links (budget_id);

  CREATE TABLE IF NOT EXISTS auth_codes (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    purpose TEXT NOT NULL,
    code_hash TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    consumed_at TEXT,
    created_at TEXT NOT NULL,
    last_sent_at TEXT NOT NULL,
    resend_count INTEGER DEFAULT 0,
    attempt_count INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_auth_codes_user_purpose
    ON auth_codes (user_id, purpose, created_at DESC);

  CREATE TABLE IF NOT EXISTS auth_sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    token_hash TEXT NOT NULL,
    created_at TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    revoked_at TEXT,
    last_used_at TEXT,
    device_info TEXT,
    ip_address TEXT,
    platform TEXT,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
  );

  CREATE UNIQUE INDEX IF NOT EXISTS idx_auth_sessions_token_hash
    ON auth_sessions (token_hash);
  CREATE INDEX IF NOT EXISTS idx_auth_sessions_user_id
    ON auth_sessions (user_id, created_at DESC);

  CREATE TABLE IF NOT EXISTS auth_rate_limits (
    id SERIAL PRIMARY KEY,
    action_key TEXT NOT NULL,
    scope_key TEXT NOT NULL,
    attempts INTEGER DEFAULT 0,
    window_started_at TEXT NOT NULL,
    blocked_until TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  );

  CREATE UNIQUE INDEX IF NOT EXISTS idx_auth_rate_limits_scope
    ON auth_rate_limits (action_key, scope_key);

  CREATE TABLE IF NOT EXISTS error_logs (
    id SERIAL PRIMARY KEY,
    created_at TEXT NOT NULL,
    severity TEXT NOT NULL,
    category TEXT,
    error_code TEXT,
    friendly_message TEXT NOT NULL,
    technical_message TEXT,
    stack_trace TEXT,
    http_status INTEGER,
    http_method TEXT,
    endpoint TEXT,
    module TEXT,
    platform TEXT,
    screen_route TEXT,
    operation TEXT,
    request_id TEXT,
    environment TEXT,
    user_id INTEGER,
    user_name TEXT,
    user_email TEXT,
    context_json TEXT,
    payload_json TEXT,
    resolved_at TEXT,
    resolved_by_user_id INTEGER,
    resolution_note TEXT,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
    FOREIGN KEY (resolved_by_user_id) REFERENCES users (id) ON DELETE SET NULL
  );

  CREATE INDEX IF NOT EXISTS idx_error_logs_created_at
    ON error_logs (created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_error_logs_severity
    ON error_logs (severity);
  CREATE INDEX IF NOT EXISTS idx_error_logs_module
    ON error_logs (module);
  CREATE INDEX IF NOT EXISTS idx_error_logs_platform
    ON error_logs (platform);

  CREATE TABLE IF NOT EXISTS event_logs (
    id SERIAL PRIMARY KEY,
    created_at TEXT NOT NULL,
    action TEXT NOT NULL,
    description TEXT NOT NULL,
    module TEXT,
    entity_type TEXT,
    entity_id TEXT,
    outcome TEXT NOT NULL,
    platform TEXT,
    ip_address TEXT,
    route_path TEXT,
    http_method TEXT,
    request_id TEXT,
    user_id INTEGER,
    user_name TEXT,
    user_email TEXT,
    user_role TEXT,
    metadata_json TEXT,
    before_json TEXT,
    after_json TEXT,
    FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
  );

  CREATE INDEX IF NOT EXISTS idx_event_logs_created_at
    ON event_logs (created_at DESC);
  CREATE INDEX IF NOT EXISTS idx_event_logs_action
    ON event_logs (action);
  CREATE INDEX IF NOT EXISTS idx_event_logs_module
    ON event_logs (module);
  CREATE INDEX IF NOT EXISTS idx_event_logs_platform
    ON event_logs (platform);
`;

module.exports = {
  SQLITE_INITIAL_SCHEMA,
  POSTGRES_INITIAL_SCHEMA
};
