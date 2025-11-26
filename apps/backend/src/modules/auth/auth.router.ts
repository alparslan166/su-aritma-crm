import { Router } from "express";

import { getProfileHandler, loginHandler, updateProfileHandler } from "./auth.controller";

const router = Router();

router.post("/login", loginHandler);

// Profile routes (require authentication - getAdminId is called inside handlers)
router.get("/profile", getProfileHandler);
router.put("/profile", updateProfileHandler);

export const authRouter = router;
