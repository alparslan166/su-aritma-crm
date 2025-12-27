import { Router } from "express";

import { exportAllDataHandler } from "./export.controller";

const router = Router();

// Export all admin data to Excel
router.get("/excel", exportAllDataHandler);

export const exportRouter = router;
