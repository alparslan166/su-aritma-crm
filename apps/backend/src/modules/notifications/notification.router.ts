import { Router } from "express";

import {
  registerTokenHandler,
  unregisterTokenHandler,
  sendRoleNotificationHandler,
  listNotificationsHandler,
  markNotificationReadHandler,
} from "./notification.controller";

const router = Router();

router.post("/send", sendRoleNotificationHandler);
router.post("/register-token", registerTokenHandler);
router.post("/unregister-token", unregisterTokenHandler);
router.get("/", listNotificationsHandler);
router.post("/:id/read", markNotificationReadHandler);

export const notificationRouter = router;
