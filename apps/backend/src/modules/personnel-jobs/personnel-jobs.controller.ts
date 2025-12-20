import { JobStatus } from "@prisma/client";
import { NextFunction, Request, Response } from "express";
import { z } from "zod";

import { getPersonnelId } from "@/lib/tenant";
import { jobService } from "@/modules/jobs/job.service";

const listQuerySchema = z.object({
  status: z.nativeEnum(JobStatus).optional(),
  search: z.string().optional(),
});

const deliverSchema = z.object({
  note: z.string().optional(),
  collectedAmount: z.number().nonnegative().optional(),
  maintenanceIntervalMonths: z.number().int().min(1).max(12).optional(),
  usedMaterials: z
    .array(
      z.object({
        inventoryItemId: z.string(),
        quantity: z.number().int().positive(),
      }),
    )
    .optional(),
  // S3 keys (not full URLs) - e.g. "job-deliveries/uuid"
  photoUrls: z.array(z.string().min(1)).optional(),
});

export const listAssignedJobsHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const personnelId = getPersonnelId(req);
    const filters = listQuerySchema.parse(req.query);
    const items = await jobService.listAssignedJobs(personnelId, filters);
    res.json({ success: true, data: items });
  } catch (error) {
    next(error as Error);
  }
};

export const getAssignedJobHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const personnelId = getPersonnelId(req);
    const result = await jobService.getAssignedJob(personnelId, req.params.id);
    res.json({
      success: true,
      data: {
        ...result.job,
        readOnly: result.readOnly,
        assignment: {
          startedAt: result.assignment.startedAt,
          deliveredAt: result.assignment.deliveredAt,
        },
      },
    });
  } catch (error) {
    next(error as Error);
  }
};

export const startJobHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const personnelId = getPersonnelId(req);
    const job = await jobService.startJobByPersonnel(personnelId, req.params.id);
    res.json({ success: true, data: job });
  } catch (error) {
    next(error as Error);
  }
};

export const deliverJobHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const personnelId = getPersonnelId(req);
    const payload = deliverSchema.parse(req.body);
    const job = await jobService.deliverJobByPersonnel(personnelId, req.params.id, payload);

    // Send notification after job is delivered
    if (job) {
      await jobService.notifyJobCompleted(job.adminId, personnelId, job.id, job.title ?? "İş");
    }

    res.json({ success: true, data: job });
  } catch (error) {
    next(error as Error);
  }
};
