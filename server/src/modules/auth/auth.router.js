const express = require("express");

const { asyncHandler } = require("../../core/http/async-handler");
const { send, sendCreated } = require("../../core/http/response");
const { ensureRequiredFields } = require("../../core/utils/validation");
const authService = require("./auth.service");

function createAuthRouter({ db, env, emailService }) {
  const router = express.Router();

  router.post(
    "/register",
    asyncHandler(async (req, res) => {
      ensureRequiredFields(req.body, ["name", "email", "password"]);
      const result = await authService.register(db, env, emailService, req.body, req);
      return sendCreated(res, result);
    })
  );

  router.post(
    "/login",
    asyncHandler(async (req, res) => {
      ensureRequiredFields(req.body, ["email", "password"]);
      const result = await authService.login(db, env, req.body, req);
      return send(res, result);
    })
  );

  router.post(
    "/refresh",
    asyncHandler(async (req, res) => {
      ensureRequiredFields(req.body, ["refreshToken"]);
      const result = await authService.refresh(db, env, req.body, req);
      return send(res, result);
    })
  );

  router.post(
    "/email/verify",
    asyncHandler(async (req, res) => {
      ensureRequiredFields(req.body, ["email", "code"]);
      const result = await authService.verifyEmail(db, env, emailService, req.body, req);
      return send(res, result);
    })
  );

  router.post(
    "/email/resend-code",
    asyncHandler(async (req, res) => {
      ensureRequiredFields(req.body, ["email"]);
      const result = await authService.resendVerificationCode(
        db,
        env,
        emailService,
        req.body,
        req
      );
      return send(res, result, { statusCode: 202 });
    })
  );

  router.post(
    "/password/forgot",
    asyncHandler(async (req, res) => {
      ensureRequiredFields(req.body, ["email"]);
      const result = await authService.forgotPassword(db, env, emailService, req.body, req);
      return send(res, result, { statusCode: 202 });
    })
  );

  router.post(
    "/password/verify-code",
    asyncHandler(async (req, res) => {
      ensureRequiredFields(req.body, ["email", "code"]);
      const result = await authService.verifyPasswordResetCode(db, env, req.body);
      return send(res, result);
    })
  );

  router.post(
    "/password/reset",
    asyncHandler(async (req, res) => {
      ensureRequiredFields(req.body, ["email", "code", "password"]);
      const result = await authService.resetPassword(db, env, req.body);
      return send(res, result);
    })
  );

  router.get(
    "/me",
    asyncHandler(async (req, res) => {
      const result = await authService.me(db, req.user.id, req.auth?.sessionId);
      return send(res, result);
    })
  );

  router.post(
    "/logout",
    asyncHandler(async (req, res) => {
      const result = await authService.logout(db, req);
      return send(res, result);
    })
  );

  router.post(
    "/logout-all",
    asyncHandler(async (req, res) => {
      const result = await authService.logoutAll(db, req);
      return send(res, result);
    })
  );

  return router;
}

module.exports = { createAuthRouter };
