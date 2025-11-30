import { Router } from "express";

import {
  getProfileHandler,
  loginHandler,
  registerHandler,
  updateProfileHandler,
  sendVerificationCodeHandler,
  verifyEmailHandler,
  forgotPasswordHandler,
  resetPasswordHandler,
} from "./auth.controller";

const router = Router();

// Auth routes (public)
router.post("/register", registerHandler);
router.post("/login", loginHandler);

// Email verification routes (public)
router.post("/send-verification-code", sendVerificationCodeHandler);
router.post("/verify-email", verifyEmailHandler);

// Password reset routes (public)
router.post("/forgot-password", forgotPasswordHandler);
router.post("/reset-password", resetPasswordHandler);

// Profile routes (require authentication - getAdminId is called inside handlers)
router.get("/profile", getProfileHandler);
router.put("/profile", updateProfileHandler);

export const authRouter = router;
