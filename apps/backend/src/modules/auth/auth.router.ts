import { Router } from "express";

import { getProfileHandler, loginHandler, registerHandler, updateProfileHandler } from "./auth.controller";

const router = Router();

router.post("/register", registerHandler);
router.post("/login", loginHandler);

// Profile routes (require authentication - getAdminId is called inside handlers)
router.get("/profile", getProfileHandler);
router.put("/profile", updateProfileHandler);

export const authRouter = router;
