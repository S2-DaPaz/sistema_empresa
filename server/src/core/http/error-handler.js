const { AppError } = require("../errors/app-error");

function errorHandler(logger) {
  return (error, req, res, next) => {
    if (res.headersSent) {
      return next(error);
    }

    if (error instanceof AppError) {
      return res.status(error.statusCode).json({
        error: {
          code: error.code,
          message: error.message,
          details: error.details
        }
      });
    }

    logger.error("unexpected_error", {
      method: req.method,
      path: req.originalUrl,
      message: error.message,
      stack: error.stack
    });

    return res.status(500).json({
      error: {
        code: "internal_error",
        message: "Falha interna ao processar a requisicao."
      }
    });
  };
}

module.exports = { errorHandler };
