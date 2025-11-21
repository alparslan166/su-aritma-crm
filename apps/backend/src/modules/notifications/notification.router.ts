import { Router } from "express";

import { registerTokenHandler, sendRoleNotificationHandler } from "./notification.controller";

const router = Router();

router.post("/send", sendRoleNotificationHandler);
router.post("/register-token", registerTokenHandler);

export const notificationRouter = router;

