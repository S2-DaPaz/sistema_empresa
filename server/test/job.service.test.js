const test = require("node:test");
const assert = require("node:assert/strict");

const { open } = require("sqlite");
const sqlite3 = require("sqlite3");

const { DB_TYPES } = require("../src/infrastructure/database/db-types");
const { migrations } = require("../src/infrastructure/database/migrations");
const { runMigrations } = require("../src/infrastructure/database/migrator");
const { createJobService } = require("../src/infrastructure/jobs/job.service");

async function createDb() {
  const db = await open({
    filename: ":memory:",
    driver: sqlite3.Database
  });
  await runMigrations(db, DB_TYPES.SQLITE, migrations);
  return db;
}

test("job service processes queued jobs and marks them as completed", async () => {
  const db = await createDb();
  const handled = [];

  const jobService = createJobService({
    db,
    env: {
      jobs: {
        enabled: true,
        pollMs: 50,
        batchSize: 5,
        maxAttempts: 3,
        retryDelaySeconds: 1,
        encryptionSecret: "test-jobs-secret"
      }
    },
    logger: {
      error() {},
      info() {},
      warn() {}
    },
    monitoringService: null,
    handlers: {
      "demo.echo": async ({ payload }) => {
        handled.push(payload.message);
      }
    }
  });

  await jobService.enqueue({
    type: "demo.echo",
    payload: { message: "ok" },
    dedupeKey: "echo:ok"
  });

  await jobService.processDueJobs();

  const stored = await db.get("SELECT status FROM background_jobs WHERE dedupe_key = ?", ["echo:ok"]);

  assert.deepEqual(handled, ["ok"]);
  assert.equal(stored.status, "completed");
});

test("job service reuses pending job when dedupe key is repeated", async () => {
  const db = await createDb();
  const jobService = createJobService({
    db,
    env: {
      jobs: {
        enabled: true,
        pollMs: 50,
        batchSize: 5,
        maxAttempts: 3,
        retryDelaySeconds: 1,
        encryptionSecret: "test-jobs-secret"
      }
    },
    logger: {
      error() {},
      info() {},
      warn() {}
    },
    monitoringService: null,
    handlers: {}
  });

  const first = await jobService.enqueue({
    type: "demo.echo",
    payload: { message: "ok" },
    dedupeKey: "echo:ok"
  });
  const second = await jobService.enqueue({
    type: "demo.echo",
    payload: { message: "ok" },
    dedupeKey: "echo:ok"
  });

  const countRow = await db.get("SELECT COUNT(*) AS total FROM background_jobs WHERE dedupe_key = ?", [
    "echo:ok"
  ]);

  assert.equal(first.id, second.id);
  assert.equal(Number(countRow.total), 1);
});
