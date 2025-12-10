import { Router } from "express";

import { logger } from "@/lib/logger";

import {
  createCustomerHandler,
  deleteCustomerHandler,
  getCustomerHandler,
  listCustomersHandler,
  markInstallmentOverdueHandler,
  payDebtHandler,
  updateCustomerHandler,
} from "./customer.controller";

const router = Router();

// Debug middleware: Tüm PUT request'leri logla
router.put("/:id", (req, res, next) => {
  logger.debug(
    "═══════════════════════════════════════════════════════════════════════════════════════════",
  );
  logger.debug("🔵🔵🔵 Customer Router - PUT /:id middleware 🔵🔵🔵");
  logger.debug("   URL:", req.url);
  logger.debug("   Method:", req.method);
  logger.debug("   Params:", req.params);
  logger.debug("   Body:", JSON.stringify(req.body, null, 2));
  logger.debug(
    "═══════════════════════════════════════════════════════════════════════════════════════════",
  );
  next();
});

router.get("/", listCustomersHandler);
router.get("/:id", getCustomerHandler);
router.post("/", createCustomerHandler);
router.put("/:id", updateCustomerHandler);
router.post("/:id/pay-debt", payDebtHandler);
router.post("/:id/mark-installment-overdue", markInstallmentOverdueHandler);
router.delete("/:id", deleteCustomerHandler);

export const customerRouter = router;

