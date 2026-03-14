function send(res, data, { statusCode = 200, meta } = {}) {
  const payload = { data };
  if (meta) {
    payload.meta = meta;
  }
  res.locals.responseData = data;
  res.locals.responseMeta = meta || null;
  return res.status(statusCode).json(payload);
}

function sendCreated(res, data, meta) {
  return send(res, data, { statusCode: 201, meta });
}

function sendNoContent(res) {
  res.locals.responseData = null;
  res.locals.responseMeta = null;
  return res.status(204).end();
}

module.exports = {
  send,
  sendCreated,
  sendNoContent
};
