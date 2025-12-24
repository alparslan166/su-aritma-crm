import { NextFunction, Request, Response, Router } from "express";

import { logger } from "../lib/logger";

import { adminRouter } from "../modules/admins/admin.router";
import { authRouter } from "../modules/auth/auth.router";
import { customerRouter } from "../modules/customers/customer.router";
import { healthRouter } from "../modules/health/health.router";
import { installmentRouter } from "../modules/installments/installment.router";
import { inventoryRouter } from "../modules/inventory/inventory.router";
import { invoiceRouter } from "../modules/invoices/invoice.router";
import { jobRouter } from "../modules/jobs/job.router";
import { maintenanceRouter } from "../modules/maintenance/maintenance.router";
import { mediaRouter } from "../modules/media/media.router";
import { notificationRouter } from "../modules/notifications/notification.router";
import { personnelRouter } from "../modules/personnel/personnel.router";
import { personnelJobsRouter } from "../modules/personnel-jobs/personnel-jobs.router";
import { subscriptionRouter } from "../modules/subscriptions/subscription.router";

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
      admins: "/api/admins",
      customers: "/api/customers",
      installments: "/api/installments",
      inventory: "/api/inventory",
      invoices: "/api/invoices",
      jobs: "/api/jobs",
      media: "/api/media",
      notifications: "/api/notifications",
      maintenance: "/api/maintenance",
      personnel: "/api/personnel",
      "personnel-jobs": "/api/personnel/jobs",
      subscriptions: "/api/subscriptions",
    },
  });
});

router.use("/health", healthRouter);
router.use("/auth", authRouter);
router.use("/admins", adminRouter);

// API Router - /customers route logging middleware
// Production'da da görünmesi için console.log kullanıyoruz
router.use(
  "/customers",
  (req: Request, res: Response, next: NextFunction) => {
    if (req.method === "PUT") {
      console.log(
        "═══════════════════════════════════════════════════════════════════════════════════════════",
      );
      console.log("🔵🔵🔵 API Router - /customers Route Match Edildi 🔵🔵🔵");
      console.log("   Method:", req.method);
      console.log("   URL:", req.originalUrl);
      console.log("   Path:", req.path);
      console.log("   Params:", JSON.stringify(req.params, null, 2));
      console.log("   Headers:", JSON.stringify(req.headers, null, 2));
      console.log("   Body:", JSON.stringify(req.body, null, 2));
      console.log(
        "═══════════════════════════════════════════════════════════════════════════════════════════",
      );
    }
    next();
  },
  customerRouter,
);
router.use("/installments", installmentRouter);
router.use("/inventory", inventoryRouter);
router.use("/invoices", invoiceRouter);
router.use("/jobs", jobRouter);
router.use("/media", mediaRouter);
router.use("/notifications", notificationRouter);
router.use("/maintenance", maintenanceRouter);
router.use("/personnel/jobs", personnelJobsRouter);
router.use("/personnel", personnelRouter);
router.use("/subscriptions", subscriptionRouter);

export const apiRouter = router;
