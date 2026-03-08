const { ValidationError } = require("../errors/app-error");

function isEmpty(value) {
  return value === undefined || value === null || value === "";
}

function ensureRequiredFields(body, fields) {
  const missing = fields.filter((field) => isEmpty(body[field]));
  if (missing.length) {
    throw new ValidationError("Campos obrigatorios ausentes.", missing);
  }
}

function buildPayload(body, fields, jsonFields = []) {
  const data = {};
  fields.forEach((field) => {
    const value = body[field] !== undefined ? body[field] : null;
    data[field] = jsonFields.includes(field) && value !== null ? JSON.stringify(value) : value;
  });
  return data;
}

function normalizeId(value, label = "id") {
  const id = Number(value);
  if (!Number.isInteger(id) || id <= 0) {
    throw new ValidationError(`Parametro ${label} invalido.`);
  }
  return id;
}

function toNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : 0;
}

module.exports = {
  isEmpty,
  ensureRequiredFields,
  buildPayload,
  normalizeId,
  toNumber
};
