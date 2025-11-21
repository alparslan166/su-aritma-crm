import { Router } from "express";

import { authRouter } from "@/modules/auth/auth.router";
import { customerRouter } from "@/modules/customers/customer.router";
import { healthRouter } from "@/modules/health/health.router";
import { inventoryRouter } from "@/modules/inventory/inventory.router";
import { jobRouter } from "@/modules/jobs/job.router";
import { maintenanceRouter } from "@/modules/maintenance/maintenance.router";
import { mediaRouter } from "@/modules/media/media.router";
import { notificationRouter } from "@/modules/notifications/notification.router";
import { operationRouter } from "@/modules/operations/operation.router";
import { personnelRouter } from "@/modules/personnel/personnel.router";
import { personnelJobsRouter } from "@/modules/personnel-jobs/personnel-jobs.router";

const router = Router();

// Root API endpoint - API bilgileri
router.get("/", (req, res) => {
  res.json({
    success: true,
    message: "Su Arıtma API",
    version: "1.0.0",
    endpoints: {
      health: "/api/health",
      auth: "/api/auth",
      customers: "/api/customers",
      inventory: "/api/inventory",
      jobs: "/api/jobs",
      media: "/api/media",
      notifications: "/api/notifications",
      maintenance: "/api/maintenance",
      operations: "/api/operations",
      personnel: "/api/personnel",
      "personnel-jobs": "/api/personnel/jobs",
    },
  });
});

router.use("/health", healthRouter);
router.use("/auth", authRouter);
router.use("/customers", customerRouter);
router.use("/inventory", inventoryRouter);
router.use("/jobs", jobRouter);
router.use("/media", mediaRouter);
router.use("/notifications", notificationRouter);
router.use("/maintenance", maintenanceRouter);
router.use("/operations", operationRouter);
router.use("/personnel/jobs", personnelJobsRouter);
router.use("/personnel", personnelRouter);

export const apiRouter = router;

