function send(res, data, { statusCode = 200, meta } = {}) {
  const payload = { data };
  if (meta) {
    payload.meta = meta;
  }
  return res.status(statusCode).json(payload);
}

function sendCreated(res, data, meta) {
  return send(res, data, { statusCode: 201, meta });
}

function sendNoContent(res) {
  return res.status(204).end();
}

module.exports = {
  send,
  sendCreated,
  sendNoContent
};
