import { InventoryTransactionType } from "@prisma/client";
import { NextFunction, Request, Response } from "express";
import { z } from "zod";

import { getAdminId, getPersonnelId } from "@/lib/tenant";
import { prisma } from "@/lib/prisma";

import { inventoryService } from "./inventory.service";

const itemSchema = z.object({
  category: z.string().min(2),
  name: z.string().min(2),
  sku: z.string().optional(),
  unit: z.string().optional(),
  photoUrl: z.string().url().optional(),
  unitPrice: z.number().nonnegative(),
  stockQty: z.number().int().nonnegative(),
  criticalThreshold: z.number().int().nonnegative(),
  reorderPoint: z.number().int().optional(),
  reorderQuantity: z.number().int().optional(),
  isActive: z.boolean().optional(),
});

const adjustSchema = z.object({
  type: z.nativeEnum(InventoryTransactionType),
  quantity: z.number().int().positive(),
  note: z.string().optional(),
  jobId: z.string().optional(),
});

export const listInventoryHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    // Check if request is from personnel
    const personnelIdHeader = req.header("x-personnel-id");
    const adminIdHeader = req.header("x-admin-id");

    let adminId: string;

    if (personnelIdHeader && !adminIdHeader) {
      // Request from personnel - get their adminId
      const personnelId = getPersonnelId(req);
      const personnel = await prisma.personnel.findUnique({
        where: { id: personnelId },
        select: { adminId: true },
      });
      if (!personnel) {
        return res.status(404).json({ success: false, message: "Personnel not found" });
      }
      adminId = personnel.adminId;
    } else {
      // Request from admin
      adminId = getAdminId(req);
    }

    const data = await inventoryService.list(adminId);
    res.json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

export const createInventoryHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const payload = itemSchema.parse(req.body);
    const data = await inventoryService.create(adminId, payload);
    res.status(201).json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

export const updateInventoryHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const payload = itemSchema.partial().parse(req.body);
    const data = await inventoryService.update(adminId, req.params.id, payload);
    res.json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

export const deleteInventoryHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    await inventoryService.delete(adminId, req.params.id);
    res.status(204).send();
  } catch (error) {
    next(error as Error);
  }
};

export const adjustInventoryHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const payload = adjustSchema.parse(req.body);
    const data = await inventoryService.adjust(adminId, req.params.id, payload);
    res.json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};
