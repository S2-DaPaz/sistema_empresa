const express = require("express");

const { asyncHandler } = require("../../core/http/async-handler");
const { send, sendCreated } = require("../../core/http/response");
const { ensureRequiredFields } = require("../../core/utils/validation");
const { register, login } = require("./auth.service");

function createAuthRouter({ db, env }) {
  const router = express.Router();

  router.post(
    "/register",
    asyncHandler(async (req, res) => {
      ensureRequiredFields(req.body, ["name", "email", "password"]);
      const result = await register(db, env, req.body);
      return sendCreated(res, result);
    })
  );

  router.post(
    "/login",
    asyncHandler(async (req, res) => {
      ensureRequiredFields(req.body, ["email", "password"]);
      const result = await login(db, env, req.body);
      return send(res, result);
    })
  );

  return router;
}

module.exports = { createAuthRouter };
