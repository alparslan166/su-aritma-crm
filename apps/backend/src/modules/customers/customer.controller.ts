import { NextFunction, Request, Response } from "express";
import { z } from "zod";

import { customerService } from "./customer.service";
import { logger } from "../../lib/logger";
import { prisma } from "../../lib/prisma";
import { getAdminId, getPersonnelId } from "../../lib/tenant";
import { notificationService } from "../notifications/notification.service";
import { AppError } from "../../middleware/error-handler";

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
    receivedAmount: z.number().nonnegative().optional(),
    paymentDate: z.string().datetime().optional(),
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

// Update schema: createSchema'dan nextMaintenanceDate'i çıkar, sonra extend ile ekle
const updateSchemaBase = createSchema.omit({ nextMaintenanceDate: true }).partial();
const updateSchema = updateSchemaBase.extend({
  remainingDebtAmount: z.number().nonnegative().optional(),
  // nextMaintenanceDate: string datetime, null, veya undefined olabilir
  // Zod'un nullable() ve optional() kombinasyonu doğru çalışmıyor, manuel kontrol yapıyoruz
  nextMaintenanceDate: z
    .union([z.string().datetime(), z.null(), z.literal(""), z.undefined()])
    .optional()
    .transform((val) => {
      // undefined ise undefined döndür (field gönderilmemiş demektir)
      if (val === undefined) return undefined;
      // null veya "" ise null döndür (field temizlenecek demektir)
      if (val === null || val === "") return null;
      // String datetime değerini olduğu gibi döndür
      return val;
    }),
  // Kullanılan ürünler listesi
  usedProducts: z.array(z.object({
    inventoryItemId: z.string(),
    name: z.string(),
    quantity: z.number().int().positive(),
    unit: z.string().optional(),
  })).optional(),
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

    // Debug: Dönen customer'da debtPaymentHistory ve nextMaintenanceDate var mı kontrol et
    console.log("🟢 Backend getById - Dönen customer:");
    console.log(`   - debtPaymentHistory: ${data.debtPaymentHistory?.length ?? 0} adet`);
    console.log(`   - nextMaintenanceDate: ${data.nextMaintenanceDate}`);
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
    // Production'da da görünmesi için console.log kullanıyoruz
    console.log(
      "═══════════════════════════════════════════════════════════════════════════════════════════",
    );
    console.log("🔵🔵🔵 Backend Controller - updateCustomer BAŞLADI 🔵🔵🔵");
    console.log("   Customer ID:", id);
    console.log("   Request body (raw):", JSON.stringify(req.body, null, 2));

    let payload;
    try {
      payload = updateSchema.parse(req.body);
    } catch (parseError) {
      console.log("   ❌ Zod parse hatası:", parseError);
      throw parseError;
    }

    console.log("   Parsed payload:", JSON.stringify(payload, null, 2));
    console.log("   payload.nextMaintenanceDate:", payload.nextMaintenanceDate);
    console.log("   payload.nextMaintenanceDate type:", typeof payload.nextMaintenanceDate);
    console.log(
      "   payload.nextMaintenanceDate !== undefined:",
      payload.nextMaintenanceDate !== undefined,
    );

    const data = await customerService.update(adminId, id, {
      ...payload,
      email: payload.email === "" ? undefined : payload.email,
    });

    if (!data) {
      throw new AppError("Customer not found after update", 404);
    }

    console.log("   Response data.nextMaintenanceDate:", data.nextMaintenanceDate);
    console.log("🔵🔵🔵 Backend Controller - updateCustomer TAMAMLANDI 🔵🔵🔵");
    console.log(
      "═══════════════════════════════════════════════════════════════════════════════════════════",
    );
    res.json({ success: true, data });
  } catch (error) {
    // Controller'da error'u detaylı logla
    logger.error(
      "═══════════════════════════════════════════════════════════════════════════════════════════",
    );
    logger.error("❌❌❌ Backend Controller - updateCustomer ERROR ❌❌❌");
    logger.error("   Customer ID:", req.params.id);
    logger.error("   Error type:", error?.constructor?.name);
    logger.error("   Error message:", error instanceof Error ? error.message : String(error));
    logger.error("   Request body:", JSON.stringify(req.body, null, 2));
    if (error instanceof z.ZodError) {
      logger.error("   Zod Error Issues:", JSON.stringify(error.issues, null, 2));
      error.issues.forEach((issue, index) => {
        logger.error(`   Issue ${index + 1}:`);
        logger.error(`     Path: ${issue.path.join(".")}`);
        logger.error(`     Message: ${issue.message}`);
        logger.error(`     Code: ${issue.code}`);
        if (issue.path.includes("nextMaintenanceDate")) {
          logger.error(`     ⚠️ nextMaintenanceDate validation hatası!`);
          logger.error(`     Received value: ${JSON.stringify(req.body?.nextMaintenanceDate)}`);
        }
      });
    }
    if (error instanceof Error && error.stack) {
      logger.error("   Stack:", error.stack);
    }
    logger.error(
      "═══════════════════════════════════════════════════════════════════════════════════════════",
    );
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
