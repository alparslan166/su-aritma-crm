import { Router } from "express";

import { logger } from "../../lib/logger";

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

router.get("/", listCustomersHandler);
router.get("/:id", getCustomerHandler);
router.post("/", createCustomerHandler);

// Debug middleware: PUT request'leri logla (route'tan önce tanımlanmalı)
// Production'da da görünmesi için console.log kullanıyoruz
router.put(
  "/:id",
  (req, res, next) => {
    console.log(
      "═══════════════════════════════════════════════════════════════════════════════════════════",
    );
    console.log("🔵🔵🔵 Customer Router - PUT /:id middleware 🔵🔵🔵");
    console.log("   URL:", req.url);
    console.log("   Method:", req.method);
    console.log("   Params:", JSON.stringify(req.params, null, 2));
    console.log("   Body:", JSON.stringify(req.body, null, 2));
    console.log(
      "═══════════════════════════════════════════════════════════════════════════════════════════",
    );
    next();
  },
  updateCustomerHandler,
);
router.post("/:id/pay-debt", payDebtHandler);
router.post("/:id/mark-installment-overdue", markInstallmentOverdueHandler);
router.delete("/:id", deleteCustomerHandler);

export const customerRouter = router;
