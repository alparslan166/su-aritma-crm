import { NextFunction, Request, Response } from "express";
import { z } from "zod";

import { getAdminId } from "@/lib/tenant";

import { customerService } from "./customer.service";

const listQuerySchema = z.object({
  search: z.string().optional(),
  phoneSearch: z.string().optional(),
  createdAtFrom: z.string().datetime().optional().transform((val) => val ? new Date(val) : undefined),
  createdAtTo: z.string().datetime().optional().transform((val) => val ? new Date(val) : undefined),
  hasOverduePayment: z.string().transform((val) => val === "true").optional(),
  hasUpcomingMaintenance: z.string().transform((val) => val === "true").optional(),
  hasOverdueInstallment: z.string().transform((val) => val === "true").optional(),
});

const createSchema = z.object({
  name: z.string().min(2),
  phone: z.string().min(6),
  email: z.string().email().optional().or(z.literal("")),
  address: z.string().min(3),
  location: z.record(z.string(), z.any()).optional(),
  createdAt: z.string().datetime().optional(),
  hasDebt: z.boolean().optional(),
  debtAmount: z.number().positive().optional(),
  hasInstallment: z.boolean().optional(),
  installmentCount: z.number().int().positive().optional(),
  nextDebtDate: z.string().datetime().optional(),
  installmentStartDate: z.string().datetime().optional(),
  installmentIntervalDays: z.number().int().positive().optional(),
}).refine((data) => {
  // If hasDebt is true, debtAmount must be provided
  if (data.hasDebt === true && !data.debtAmount) {
    return false;
  }
  // If hasInstallment is true, installmentCount must be provided
  if (data.hasInstallment === true && !data.installmentCount) {
    return false;
  }
  // If hasDebt is false, other debt fields should not be set
  if (data.hasDebt === false && (data.debtAmount || data.hasInstallment || data.installmentCount)) {
    return false;
  }
  return true;
}, {
  message: "Invalid debt configuration",
});

const updateSchema = createSchema.partial().extend({
  remainingDebtAmount: z.number().nonnegative().optional(),
});

export const listCustomersHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const filters = listQuerySchema.parse(req.query);
    const data = await customerService.list(adminId, filters);
    res.json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

export const getCustomerHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const { id } = req.params;
    const data = await customerService.getById(adminId, id);
    res.json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

export const createCustomerHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const payload = createSchema.parse(req.body);
    const data = await customerService.create(adminId, {
      ...payload,
      email: payload.email === "" ? undefined : payload.email,
    });
    res.status(201).json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

export const updateCustomerHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const { id } = req.params;
    const payload = updateSchema.parse(req.body);
    const data = await customerService.update(adminId, id, {
      ...payload,
      email: payload.email === "" ? undefined : payload.email,
    });
    res.json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

export const payDebtHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const { id } = req.params;
    const { amount, installmentCount } = z.object({ 
      amount: z.number().positive(),
      installmentCount: z.number().int().positive().optional(),
    }).parse(req.body);
    const data = await customerService.payDebt(adminId, id, amount, installmentCount);
    res.json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

export const markInstallmentOverdueHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const { id } = req.params;
    const data = await customerService.markInstallmentOverdue(adminId, id);
    res.json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

export const deleteCustomerHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const { id } = req.params;
    await customerService.delete(adminId, id);
    res.json({ success: true });
  } catch (error) {
    next(error as Error);
  }
};

