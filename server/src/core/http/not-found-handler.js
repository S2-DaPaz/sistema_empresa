function notFoundHandler(req, res) {
  return res.status(404).json({
    error: {
      code: "route_not_found",
      message: "Rota nao encontrada."
    }
  });
}

module.exports = { notFoundHandler };
