const test = require("node:test");
const assert = require("node:assert/strict");

const {
  updateTaskSignatures
} = require("../src/modules/tasks/task-signature.service");

test("updateTaskSignatures persists only signature fields", async () => {
  const calls = [];
  const db = {
    async run(sql, params) {
      calls.push({ sql, params });
      return { changes: 1 };
    },
    async get(sql, params) {
      calls.push({ sql, params });
      return {
        id: 28,
        title: "Tarefa existente",
        signature_mode: "both",
        signature_scope: "all_pages",
        signature_client: "data:image/png;base64,client",
        signature_tech: null,
        signature_pages: '{"report:10":{"client":"abc"}}'
      };
    }
  };

  const result = await updateTaskSignatures(db, 28, {
    signature_mode: "both",
    signature_scope: "all_pages",
    signature_client: "data:image/png;base64,client",
    signature_tech: null,
    signature_pages: {
      "report:10": { client: "abc" }
    }
  });

  assert.equal(calls[0].sql.includes("title = ?"), false);
  assert.match(calls[0].sql, /UPDATE tasks/);
  assert.deepEqual(calls[0].params, [
    "both",
    "all_pages",
    "data:image/png;base64,client",
    null,
    '{"report:10":{"client":"abc"}}',
    28
  ]);
  assert.equal(result.id, 28);
  assert.deepEqual(result.signature_pages, {
    "report:10": { client: "abc" }
  });
});
