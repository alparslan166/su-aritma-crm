import { Router } from "express";

import {
  createInvoiceHandler,
  deleteInvoiceHandler,
  generateInvoicePdfHandler,
  getInvoiceHandler,
  listInvoicesHandler,
  updateInvoiceHandler,
} from "./invoice.controller";

const router = Router();

router.get("/", listInvoicesHandler);
router.post("/", createInvoiceHandler);
router.get("/:id", getInvoiceHandler);
router.get("/job/:jobId/pdf", generateInvoicePdfHandler);
router.put("/:id", updateInvoiceHandler);
router.delete("/:id", deleteInvoiceHandler);

export const invoiceRouter = router;

