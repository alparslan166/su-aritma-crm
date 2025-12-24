import { Request, Response, NextFunction } from "express";
import { z } from "zod/v4";
import { installmentService } from "./installment.service";
import { getAdminId } from "../../lib/tenant";

// Taksit ödeme şeması
const payInstallmentSchema = z.object({
  installmentId: z.string(),
});

/**
 * Müşterinin taksitlerini listele
 */
export const getCustomerInstallmentsHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const { customerId } = req.params;
    const installments = await installmentService.getInstallments(customerId);
    res.json({ success: true, data: installments });
  } catch (error) {
    next(error as Error);
  }
};

/**
 * Taksit öde ve fatura oluştur
 */
export const payInstallmentHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const { installmentId } = req.params;
    
    const result = await installmentService.payInstallment(installmentId, adminId);
    res.json({ success: true, data: result });
  } catch (error) {
    next(error as Error);
  }
};
