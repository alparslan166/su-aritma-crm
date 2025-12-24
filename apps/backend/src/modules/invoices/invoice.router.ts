import { Router } from "express";

import {
  createInvoiceHandler,
  createCustomerInvoiceHandler,
  deleteInvoiceHandler,
  generateInvoicePdfHandler,
  generateInvoicePdfByIdHandler,
  getInvoiceHandler,
  listInvoicesHandler,
  updateInvoiceHandler,
} from "./invoice.controller";

const router = Router();

router.get("/", listInvoicesHandler);
router.post("/", createInvoiceHandler);
router.post("/customer", createCustomerInvoiceHandler);
router.get("/:id", getInvoiceHandler);
router.get("/:invoiceId/pdf", generateInvoicePdfByIdHandler);
router.get("/job/:jobId/pdf", generateInvoicePdfHandler);
router.put("/:id", updateInvoiceHandler);
router.delete("/:id", deleteInvoiceHandler);

export const invoiceRouter = router;

