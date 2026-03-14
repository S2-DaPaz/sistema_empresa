const { AppError } = require("../errors/app-error");

function errorHandler({ logger, monitoringService, db }) {
  return async (error, req, res, next) => {
    if (res.headersSent) {
      return next(error);
    }

    try {
      await monitoringService.recordError(db, req, error, {
        severity: error instanceof AppError ? "warning" : "error",
        payloadSummary: req.body,
        context: {
          responseLocals: {
            meta: res.locals?.responseMeta || null
          }
        }
      });
    } catch (logError) {
      logger.error("error_capture_failed", {
        requestId: req.requestId,
        method: req.method,
        path: req.originalUrl,
        message: logError.message
      });
    }

    if (!(error instanceof AppError)) {
      logger.error("unexpected_error", {
        requestId: req.requestId,
        method: req.method,
        path: req.originalUrl,
        message: error.message,
        stack: error.stack
      });
    }

    const response = monitoringService.buildErrorResponse(req, error);
    return res.status(response.statusCode).json(response.payload);
  };
}

module.exports = { errorHandler };
