import { Router } from "express";

import { listMaintenanceRemindersHandler } from "./maintenance.controller";

const router = Router();

router.get("/reminders", listMaintenanceRemindersHandler);

export const maintenanceRouter = router;

