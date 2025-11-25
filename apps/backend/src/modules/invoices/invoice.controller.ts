import { NextFunction, Request, Response } from "express";
import { z } from "zod";

import { getAdminId } from "@/lib/tenant";
import { logger } from "@/lib/logger";

import { invoiceService } from "./invoice.service";
import { invoicePdfService } from "./invoice-pdf.service";

const createSchema = z.object({
  jobId: z.string(),
  invoiceNumber: z.string().optional(),
  subtotal: z.number().nonnegative().optional(),
  tax: z.number().nonnegative().optional(),
  total: z.number().nonnegative().optional(),
  notes: z.string().optional(),
});

const updateSchema = z.object({
  customerName: z.string().min(2).optional(),
  customerPhone: z.string().min(6).optional(),
  customerAddress: z.string().min(3).optional(),
  customerEmail: z.string().email().optional().or(z.literal("")),
  jobTitle: z.string().min(2).optional(),
  jobDate: z.string().refine((value) => !Number.isNaN(Date.parse(value)), {
    message: "jobDate must be ISO date string",
  }).optional(),
  subtotal: z.number().nonnegative().optional(),
  tax: z.number().nonnegative().optional(),
  total: z.number().nonnegative().optional(),
  notes: z.string().optional(),
  isDraft: z.boolean().optional(),
});

export const createInvoiceHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const payload = createSchema.parse(req.body);
    const invoice = await invoiceService.createDraft(adminId, {
      jobId: payload.jobId,
      invoiceNumber: payload.invoiceNumber,
      subtotal: payload.subtotal,
      tax: payload.tax,
      total: payload.total,
      notes: payload.notes,
    });
    res.json({ success: true, data: invoice });
  } catch (error) {
    next(error as Error);
  }
};

export const updateInvoiceHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const payload = updateSchema.parse(req.body);
    const invoice = await invoiceService.update(adminId, req.params.id, {
      ...payload,
      jobDate: payload.jobDate ? new Date(payload.jobDate) : undefined,
      customerEmail: payload.customerEmail === "" ? undefined : payload.customerEmail,
    });
    res.json({ success: true, data: invoice });
  } catch (error) {
    next(error as Error);
  }
};

export const getInvoiceHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const invoice = await invoiceService.getById(adminId, req.params.id);
    res.json({ success: true, data: invoice });
  } catch (error) {
    next(error as Error);
  }
};

export const listInvoicesHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const invoices = await invoiceService.list(adminId);
    res.json({ success: true, data: invoices });
  } catch (error) {
    next(error as Error);
  }
};

export const deleteInvoiceHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    await invoiceService.delete(adminId, req.params.id);
    res.json({ success: true, message: "Invoice deleted" });
  } catch (error) {
    next(error as Error);
  }
};

export const generateInvoicePdfHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const { jobId } = req.params;

    logger.debug("🔄 Generating invoice PDF for job:", jobId);

    // Get invoice data for PDF
    const invoiceData = await invoiceService.createAndGeneratePdf(adminId, jobId);

    logger.debug("✅ Invoice data retrieved, generating PDF...");

    // Generate PDF
    const pdfStream = invoicePdfService.generatePdf(invoiceData);

    // Set response headers
    res.setHeader("Content-Type", "application/pdf");
    res.setHeader(
      "Content-Disposition",
      `inline; filename="fatura-${invoiceData.invoiceNumber}.pdf"`
    );

    // Handle PDF stream errors
    pdfStream.on("error", (error) => {
      logger.error("❌ PDF stream error:", error);
      if (!res.headersSent) {
        res.status(500).json({
          success: false,
          message: "PDF oluşturulurken hata oluştu",
          error: error.message,
        });
      }
    });

    // Pipe PDF to response
    pdfStream.pipe(res);

    logger.debug("✅ PDF stream piped to response");
  } catch (error) {
    logger.error("❌ Error generating invoice PDF:", error);
    next(error as Error);
  }
};

