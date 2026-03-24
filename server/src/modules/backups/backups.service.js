const { createBackupRun, updateBackupRun } = require("./backups.repository");

function createBackupsService({ logger }) {
  async function recordManualTrigger(db, user) {
    const id = await createBackupRun(db, {
      status: "pending",
      trigger_source: "manual_api",
      triggered_by_user_id: user?.id || null,
      metadata_json: JSON.stringify({
        triggered_by: user?.name || "unknown",
        note: "Disparo manual via API. O backup real é executado pelo GitHub Actions."
      })
    });

    logger.info("backup_manual_trigger", { backup_run_id: id, user_id: user?.id });
    return id;
  }

  async function recordGithubActionStart(db, metadata) {
    const id = await createBackupRun(db, {
      status: "running",
      trigger_source: metadata.trigger_source || "github_actions",
      storage_provider: "google_drive",
      metadata_json: JSON.stringify(metadata)
    });

    logger.info("backup_started", { backup_run_id: id });
    return id;
  }

  async function recordGithubActionComplete(db, id, data) {
    await updateBackupRun(db, id, {
      status: data.success ? "success" : "failed",
      file_name: data.file_name || null,
      encrypted_file_name: data.encrypted_file_name || null,
      sha256: data.sha256 || null,
      file_size_bytes: data.file_size_bytes || null,
      finished_at: new Date().toISOString(),
      error_message: data.error_message || null,
      storage_provider: data.storage_provider || "google_drive",
      metadata_json: data.metadata_json || null
    });

    const level = data.success ? "info" : "error";
    logger[level]("backup_finished", { backup_run_id: id, success: data.success });
  }

  return {
    recordManualTrigger,
    recordGithubActionStart,
    recordGithubActionComplete
  };
}

module.exports = { createBackupsService };
