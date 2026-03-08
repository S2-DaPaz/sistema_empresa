function log(level, event, context = {}) {
  const payload = {
    level,
    event,
    timestamp: new Date().toISOString(),
    ...context
  };

  const serialized = JSON.stringify(payload);

  if (level === "error") {
    console.error(serialized);
    return;
  }

  console.log(serialized);
}

const logger = {
  info(event, context) {
    log("info", event, context);
  },
  warn(event, context) {
    log("warn", event, context);
  },
  error(event, context) {
    log("error", event, context);
  }
};

module.exports = { logger };
