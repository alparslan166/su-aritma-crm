import { Router } from "express";

import {
  registerTokenHandler,
  unregisterTokenHandler,
  sendRoleNotificationHandler,
} from "./notification.controller";

const router = Router();

router.post("/send", sendRoleNotificationHandler);
router.post("/register-token", registerTokenHandler);
router.post("/unregister-token", unregisterTokenHandler);

export const notificationRouter = router;
