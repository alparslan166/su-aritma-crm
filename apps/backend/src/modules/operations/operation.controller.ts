import { NextFunction, Request, Response } from "express";
import { z } from "zod";

import { getAdminId } from "@/lib/tenant";

import { operationService } from "./operation.service";

const listQuerySchema = z.object({
  activeOnly: z.string().transform((val) => val === "true").optional(),
});

const createSchema = z.object({
  name: z.string().min(2),
  description: z.string().optional(),
  isActive: z.boolean().optional(),
});

const updateSchema = createSchema.partial();

export const listOperationsHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const filters = listQuerySchema.parse(req.query);
    const data = await operationService.list(adminId, filters.activeOnly ?? false);
    res.json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

export const getOperationHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const { id } = req.params;
    const data = await operationService.getById(adminId, id);
    res.json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

export const createOperationHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const payload = createSchema.parse(req.body);
    const data = await operationService.create(adminId, payload);
    res.status(201).json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

export const updateOperationHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const { id } = req.params;
    const payload = updateSchema.parse(req.body);
    const data = await operationService.update(adminId, id, payload);
    res.json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

export const deleteOperationHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const { id } = req.params;
    await operationService.delete(adminId, id);
    res.json({ success: true });
  } catch (error) {
    next(error as Error);
  }
};

