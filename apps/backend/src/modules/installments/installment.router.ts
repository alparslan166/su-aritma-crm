import { Router } from "express";
import {
  getCustomerInstallmentsHandler,
  payInstallmentHandler,
} from "./installment.controller";

const router = Router();

// GET /installments/customer/:customerId - Müşterinin taksitlerini listele
router.get("/customer/:customerId", getCustomerInstallmentsHandler);

// POST /installments/:installmentId/pay - Taksit öde ve fatura oluştur
router.post("/:installmentId/pay", payInstallmentHandler);

export const installmentRouter = router;
