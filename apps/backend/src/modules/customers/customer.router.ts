import { Router } from "express";

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
router.put("/:id", updateCustomerHandler);
router.post("/:id/pay-debt", payDebtHandler);
router.post("/:id/mark-installment-overdue", markInstallmentOverdueHandler);
router.delete("/:id", deleteCustomerHandler);

export const customerRouter = router;

