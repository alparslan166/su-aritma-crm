import { NextFunction, Request, Response } from "express";
import { z } from "zod";

import { logger } from "@/lib/logger";
import { prisma } from "@/lib/prisma";
import { getAdminId, getPersonnelId } from "@/lib/tenant";
import { notificationService } from "@/modules/notifications/notification.service";

import { customerService } from "./customer.service";

const listQuerySchema = z.object({
  search: z.string().optional(),
  phoneSearch: z.string().optional(),
  createdAtFrom: z
    .string()
    .datetime()
    .optional()
    .transform((val) => (val ? new Date(val) : undefined)),
  createdAtTo: z
    .string()
    .datetime()
    .optional()
    .transform((val) => (val ? new Date(val) : undefined)),
  hasOverduePayment: z
    .string()
    .transform((val) => val === "true")
    .optional(),
  hasUpcomingMaintenance: z
    .string()
    .transform((val) => val === "true")
    .optional(),
  hasOverdueInstallment: z
    .string()
    .transform((val) => val === "true")
    .optional(),
});

const createSchema = z
  .object({
    name: z.string().min(2),
    phone: z.string().min(6),
    email: z.string().email().optional().or(z.literal("")),
    address: z.string().min(3),
    location: z.record(z.string(), z.any()).optional(),
    status: z.enum(["ACTIVE", "INACTIVE"]).optional(),
    createdAt: z.string().datetime().optional(),
    hasDebt: z.boolean().optional(),
    debtAmount: z.number().positive().optional(),
    hasInstallment: z.boolean().optional(),
    installmentCount: z.number().int().positive().optional(),
    nextDebtDate: z.string().datetime().optional(),
    installmentStartDate: z.string().datetime().optional(),
    installmentIntervalDays: z.number().int().positive().optional(),
    nextMaintenanceDate: z.string().datetime().optional(),
  })
  .refine(
    (data) => {
      // If hasDebt is true, debtAmount must be provided
      if (data.hasDebt === true && !data.debtAmount) {
        return false;
      }
      // If hasInstallment is true, installmentCount must be provided
      if (data.hasInstallment === true && !data.installmentCount) {
        return false;
      }
      // If hasDebt is false, other debt fields should not be set
      if (
        data.hasDebt === false &&
        (data.debtAmount || data.hasInstallment || data.installmentCount)
      ) {
        return false;
      }
      return true;
    },
    {
      message: "Invalid debt configuration",
    },
  );

const updateSchema = createSchema.partial().extend({
  remainingDebtAmount: z.number().nonnegative().optional(),
  nextMaintenanceDate: z.string().datetime().nullable().optional(),
});

export const listCustomersHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const filters = listQuerySchema.parse(req.query);
    const data = await customerService.list(adminId, filters);
    res.json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

export const getCustomerHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const { id } = req.params;
    const data = await customerService.getById(adminId, id);

    // Debug: Dönen customer'da debtPaymentHistory var mı kontrol et
    console.log("🟢 Backend getById - Dönen customer:");
    console.log(`   - debtPaymentHistory: ${data.debtPaymentHistory?.length ?? 0} adet`);
    if (data.debtPaymentHistory && data.debtPaymentHistory.length > 0) {
      for (const payment of data.debtPaymentHistory) {
        console.log(`   - ${payment.amount} TL - ${payment.paidAt}`);
      }
    }

    res.json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

export const createCustomerHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    // Check if request is from personnel
    const personnelIdHeader = req.header("x-personnel-id");
    const adminIdHeader = req.header("x-admin-id");

    let adminId: string;
    let personnelId: string | null = null;

    if (personnelIdHeader && !adminIdHeader) {
      // Request from personnel - get their adminId
      personnelId = getPersonnelId(req);
      const personnel = await prisma.personnel.findUnique({
        where: { id: personnelId },
        select: { adminId: true, name: true },
      });
      if (!personnel) {
        return res.status(404).json({ success: false, message: "Personnel not found" });
      }
      adminId = personnel.adminId;
    } else {
      // Request from admin
      adminId = getAdminId(req);
    }

    const payload = createSchema.parse(req.body);
    const data = await customerService.create(adminId, {
      ...payload,
      email: payload.email === "" ? undefined : payload.email,
    });

    // If customer was created by personnel, send notification to admin
    if (personnelId && adminId) {
      const personnel = await prisma.personnel.findUnique({
        where: { id: personnelId },
        select: { name: true },
      });
      await notificationService.sendCustomerCreatedToAdmin(
        adminId,
        personnelId,
        data.id,
        data.name,
        personnel?.name ?? "Personel",
      );
    }

    res.status(201).json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

export const updateCustomerHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const { id } = req.params;
    logger.debug(
      "🔵 Backend Controller - updateCustomer request body:",
      JSON.stringify(req.body, null, 2),
    );
    const payload = updateSchema.parse(req.body);
    logger.debug(
      "🔵 Backend Controller - updateCustomer parsed payload:",
      JSON.stringify(payload, null, 2),
    );
    logger.debug(
      "🔵 Backend Controller - payload.nextMaintenanceDate:",
      payload.nextMaintenanceDate,
    );
    const data = await customerService.update(adminId, id, {
      ...payload,
      email: payload.email === "" ? undefined : payload.email,
    });
    logger.debug(
      "🔵 Backend Controller - updateCustomer response data.nextMaintenanceDate:",
      data.nextMaintenanceDate,
    );
    res.json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

export const payDebtHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const { id } = req.params;
    const { amount, installmentCount } = z
      .object({
        amount: z.number().positive(),
        installmentCount: z.number().int().positive().optional(),
      })
      .parse(req.body);
    const data = await customerService.payDebt(adminId, id, amount, installmentCount);

    // Debug: Dönen customer'da debtPaymentHistory var mı kontrol et
    console.log("🔵 Backend payDebt - Dönen customer:");
    console.log(`   - debtPaymentHistory: ${data.debtPaymentHistory?.length ?? 0} adet`);
    if (data.debtPaymentHistory && data.debtPaymentHistory.length > 0) {
      for (const payment of data.debtPaymentHistory) {
        console.log(`   - ${payment.amount} TL - ${payment.paidAt}`);
      }
    }

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

export const deleteCustomerHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const { id } = req.params;
    await customerService.delete(adminId, id);
    res.json({ success: true });
  } catch (error) {
    next(error as Error);
  }
};
