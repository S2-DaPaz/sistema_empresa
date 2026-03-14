class AppError extends Error {
  constructor(message, { code = "app_error", statusCode = 500, details } = {}) {
    super(message);
    this.name = this.constructor.name;
    this.code = code;
    this.statusCode = statusCode;
    this.details = details;
  }
}

class ValidationError extends AppError {
  constructor(message, details) {
    super(message, { code: "validation_error", statusCode: 400, details });
  }
}

class UnauthorizedError extends AppError {
  constructor(message = "Não autorizado") {
    super(message, { code: "unauthorized", statusCode: 401 });
  }
}

class ForbiddenError extends AppError {
  constructor(message = "Sem permissão") {
    super(message, { code: "forbidden", statusCode: 403 });
  }
}

class NotFoundError extends AppError {
  constructor(message = "Registro não encontrado") {
    super(message, { code: "not_found", statusCode: 404 });
  }
}

class ConflictError extends AppError {
  constructor(message = "Conflito de dados") {
    super(message, { code: "conflict", statusCode: 409 });
  }
}

module.exports = {
  AppError,
  ValidationError,
  UnauthorizedError,
  ForbiddenError,
  NotFoundError,
  ConflictError
};
