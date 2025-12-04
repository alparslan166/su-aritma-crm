import { PersonnelStatus } from "@prisma/client";
import { NextFunction, Request, Response } from "express";
import { z } from "zod";

import { personnelService } from "./personnel.service";
import { prisma } from "@/lib/prisma";
import { getAdminId, getPersonnelId } from "@/lib/tenant";

const listQuerySchema = z.object({
  search: z.string().optional(),
  status: z.nativeEnum(PersonnelStatus).optional(),
});

const upsertSchema = z.object({
  name: z.string().min(2),
  phone: z.string().min(6),
  email: z.string().email().optional(),
  photoUrl: z.string().optional().or(z.literal("")),
  hireDate: z.string().refine((value) => !Number.isNaN(Date.parse(value)), {
    message: "hireDate must be ISO date string",
  }),
  permissions: z.record(z.string(), z.any()).default({}),
  canShareLocation: z.boolean().optional(),
  status: z.nativeEnum(PersonnelStatus).optional(),
  loginCode: z.string().min(4).max(20).optional().or(z.literal("")),
});

export const listPersonnelHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const filters = listQuerySchema.parse(req.query);
    const records = await personnelService.list(adminId, filters);
    res.json({ success: true, data: records });
  } catch (error) {
    next(error as Error);
  }
};

export const getPersonnelHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    // Check if request is from personnel (has x-personnel-id header)
    const personnelIdHeader = req.header("x-personnel-id");
    const adminIdHeader = req.header("x-admin-id");

    if (personnelIdHeader && !adminIdHeader) {
      // Request from personnel - they can only view their own profile
      const personnelId = getPersonnelId(req);
      if (personnelId !== req.params.id) {
        return res.status(403).json({
          success: false,
          message: "You can only view your own profile",
        });
      }
      // Get personnel's adminId from database
      const personnel = await prisma.personnel.findUnique({
        where: { id: personnelId },
        select: { adminId: true },
      });
      if (!personnel) {
        return res.status(404).json({ success: false, message: "Personnel not found" });
      }
      const record = await personnelService.getById(personnel.adminId, req.params.id);
      if (!record) {
        return res.status(404).json({ success: false, message: "Personnel not found" });
      }
      res.json({ success: true, data: record });
    } else {
      // Request from admin
      const adminId = getAdminId(req);
      const record = await personnelService.getById(adminId, req.params.id);
      if (!record) {
        return res.status(404).json({ success: false, message: "Personnel not found" });
      }
      res.json({ success: true, data: record });
    }
  } catch (error) {
    next(error as Error);
  }
};

export const createPersonnelHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const payload = upsertSchema.parse(req.body);
    const created = await personnelService.create(adminId, {
      ...payload,
      photoUrl: payload.photoUrl === "" ? undefined : payload.photoUrl,
      hireDate: new Date(payload.hireDate),
    });
    res.status(201).json({ success: true, data: created });
  } catch (error) {
    next(error as Error);
  }
};

export const updatePersonnelHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const payload = upsertSchema
      .partial({ name: true, phone: true, hireDate: true })
      .parse(req.body);
    // Handle photoUrl: empty string means remove photo (set to null), undefined means keep existing
    const updatePayload: Parameters<typeof personnelService.update>[2] = {
      ...payload,
      hireDate: payload.hireDate ? new Date(payload.hireDate) : undefined,
      photoUrl:
        payload.photoUrl !== undefined
          ? payload.photoUrl === ""
            ? null
            : payload.photoUrl
          : undefined,
    } as Parameters<typeof personnelService.update>[2];
    const updated = await personnelService.update(adminId, req.params.id, updatePayload);
    res.json({ success: true, data: updated });
  } catch (error) {
    next(error as Error);
  }
};

export const deletePersonnelHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    await personnelService.delete(adminId, req.params.id);
    res.status(204).send();
  } catch (error) {
    next(error as Error);
  }
};

export const resetPersonnelCodeHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const result = await personnelService.resetCode(adminId, req.params.id);
    res.json({ success: true, data: { loginCode: result.loginCode } });
  } catch (error) {
    next(error as Error);
  }
};

const leaveSchema = z.object({
  startDate: z.string().refine((value) => !Number.isNaN(Date.parse(value)), {
    message: "startDate must be ISO date string",
  }),
  endDate: z.string().refine((value) => !Number.isNaN(Date.parse(value)), {
    message: "endDate must be ISO date string",
  }),
  reason: z.string().optional(),
});

export const listPersonnelLeavesHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const leaves = await personnelService.listLeaves(adminId, req.params.id);
    res.json({ success: true, data: leaves });
  } catch (error) {
    next(error as Error);
  }
};

export const createPersonnelLeaveHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const payload = leaveSchema.parse(req.body);
    const leave = await personnelService.createLeave(adminId, req.params.id, {
      startDate: new Date(payload.startDate),
      endDate: new Date(payload.endDate),
      reason: payload.reason,
    });
    res.status(201).json({ success: true, data: leave });
  } catch (error) {
    next(error as Error);
  }
};

export const deletePersonnelLeaveHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    await personnelService.deleteLeave(adminId, req.params.id, req.params.leaveId);
    res.status(204).send();
  } catch (error) {
    next(error as Error);
  }
};

// Personel kendi profilini güncelleyebilir (sadece canShareLocation)
export const updateMyProfileHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const personnelId = getPersonnelId(req);
    const payload = z.object({
      canShareLocation: z.boolean().optional(),
    }).parse(req.body);
    
    const updated = await personnelService.updateMyProfile(personnelId, payload);
    res.json({ success: true, data: updated });
  } catch (error) {
    next(error as Error);
  }
};
