import { Router } from "express";

import {
  createCustomerHandler,
  deleteCustomerHandler,
  getCustomerHandler,
  listCustomersHandler,
  payDebtHandler,
  updateCustomerHandler,
} from "./customer.controller";

const router = Router();

router.get("/", listCustomersHandler);
router.get("/:id", getCustomerHandler);
router.post("/", createCustomerHandler);
router.put("/:id", updateCustomerHandler);
router.post("/:id/pay-debt", payDebtHandler);
router.delete("/:id", deleteCustomerHandler);

export const customerRouter = router;

