import { JobStatus } from "@prisma/client";
import { NextFunction, Request, Response } from "express";
import { z } from "zod";

import { getAdminId } from "@/lib/tenant";
import { logger } from "@/lib/logger";

import { jobService } from "./job.service";

const listQuerySchema = z.object({
  status: z.nativeEnum(JobStatus).optional(),
  search: z.string().optional(),
  personnelId: z.string().optional(),
});

const customerSchema = z.object({
  id: z.string().optional(),
  name: z.string().min(2),
  phone: z.string().min(6),
  email: z
    .union([z.string().email(), z.literal("")])
    .optional()
    .transform((val) => (val === "" ? undefined : val)),
  address: z.string().min(3),
});

const jobBaseSchema = z.object({
  title: z.string().min(2),
  customer: customerSchema,
  customerId: z.string().optional(),
  scheduledAt: z.string().datetime().optional(),
  location: z.record(z.string(), z.any()).refine((val) => Object.keys(val).length > 0, {
    message: "Location must have at least one field",
  }),
  price: z.number().positive().optional(),
  hasInstallment: z.boolean().optional(),
  notes: z.string().optional(),
  maintenanceDueAt: z.string().datetime().optional(),
  priority: z.number().int().optional(),
  personnelIds: z.array(z.string()).optional(),
  materialIds: z.array(z.object({
    inventoryItemId: z.string(),
    quantity: z.number().int().positive(),
  })).optional(),
});

const jobUpdateSchema = jobBaseSchema.partial().extend({
  status: z.nativeEnum(JobStatus).optional(),
});

const assignmentSchema = z.object({
  personnelIds: z.array(z.string()).min(1),
});

const statusSchema = z.object({
  status: z.nativeEnum(JobStatus),
  note: z.string().optional(),
  performerType: z.enum(["admin", "personnel"]),
  performerId: z.string().min(1),
});

const noteSchema = z.object({
  content: z.string().min(3),
  adminId: z.string().min(1),
});

export const listJobsHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const filters = listQuerySchema.parse(req.query);
    const data = await jobService.list(adminId, {
      status: filters.status,
      search: filters.search,
      personnelId: filters.personnelId,
    });
    res.json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

export const getJobHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const data = await jobService.getById(adminId, req.params.id);
    if (!data) {
      return res.status(404).json({ success: false, message: "Job not found" });
    }
    res.json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

export const createJobHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    logger.debug("🔄 JOB CREATE REQUEST START");
    logger.debug("📥 Request body:", JSON.stringify(req.body, null, 2));
    logger.debug("📥 Request headers:", JSON.stringify(req.headers, null, 2));

    const adminId = getAdminId(req);
    logger.debug("👤 Admin ID:", adminId);

    logger.debug("✅ Validating payload...");
    const payload = jobBaseSchema.parse(req.body);
    logger.debug("✅ Payload validated:", JSON.stringify(payload, null, 2));

    logger.debug("🔄 Calling jobService.create...");
    const job = await jobService.create(adminId, {
      ...payload,
      scheduledAt: payload.scheduledAt ? new Date(payload.scheduledAt) : undefined,
      maintenanceDueAt: payload.maintenanceDueAt ? new Date(payload.maintenanceDueAt) : undefined,
    });
    logger.debug("✅ Job created successfully:", job.id);
    res.status(201).json({ success: true, data: job });
  } catch (error) {
    logger.error("🛑 JOB CREATE ERROR in controller:");
    logger.error("Error type:", error?.constructor?.name);
    logger.error("Error message:", (error as Error)?.message);
    logger.error("Error stack:", (error as Error)?.stack);
    if (error instanceof z.ZodError) {
      logger.error("🛑 ZOD VALIDATION ERRORS:");
      const issues = error.issues || [];
      if (issues.length > 0) {
        issues.forEach((err: z.ZodIssue, index: number) => {
          logger.error(`  Error ${index + 1}:`);
          logger.error(`    Path: ${err.path?.join(".") || "unknown"}`);
          logger.error(`    Message: ${err.message}`);
          logger.error(`    Code: ${err.code}`);
        });
        logger.error("Full validation errors:", JSON.stringify(issues, null, 2));
      } else {
        logger.error("ZodError but issues array is missing:", error);
      }
      logger.error("Received data:", JSON.stringify(req.body, null, 2));
    }
    if ((error as any)?.code) {
      logger.error("Error code:", (error as any).code);
    }
    if ((error as any)?.meta) {
      logger.error("Error meta:", JSON.stringify((error as any).meta, null, 2));
    }
    next(error as Error);
  }
};

export const updateJobHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const payload = jobUpdateSchema.parse(req.body);
    const updated = await jobService.update(adminId, req.params.id, {
      ...payload,
      scheduledAt: payload.scheduledAt ? new Date(payload.scheduledAt) : undefined,
      maintenanceDueAt: payload.maintenanceDueAt ? new Date(payload.maintenanceDueAt) : undefined,
    });
    res.json({ success: true, data: updated });
  } catch (error) {
    next(error as Error);
  }
};

export const assignJobHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const payload = assignmentSchema.parse(req.body);
    const job = await jobService.assignPersonnel(adminId, req.params.id, payload.personnelIds);
    res.json({ success: true, data: job });
  } catch (error) {
    next(error as Error);
  }
};

export const updateJobStatusHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const payload = statusSchema.parse(req.body);
    const job = await jobService.updateStatus(adminId, req.params.id, {
      ...payload,
    });
    res.json({ success: true, data: job });
  } catch (error) {
    next(error as Error);
  }
};

export const listJobHistoryHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const data = await jobService.listHistory(adminId, req.params.id);
    res.json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

export const listJobNotesHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const data = await jobService.listNotes(adminId, req.params.id);
    res.json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

export const addJobNoteHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const payload = noteSchema.parse(req.body);
    const data = await jobService.addNote(adminId, req.params.id, payload.content, payload.adminId);
    res.status(201).json({ success: true, data });
  } catch (error) {
    next(error as Error);
  }
};

