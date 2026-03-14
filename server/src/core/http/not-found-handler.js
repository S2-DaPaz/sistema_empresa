const { NotFoundError } = require("../errors/app-error");

function notFoundHandler(req, res, next) {
  return next(new NotFoundError("Rota nao encontrada."));
}

module.exports = { notFoundHandler };
