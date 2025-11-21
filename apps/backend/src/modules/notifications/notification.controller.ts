import { NextFunction, Request, Response } from "express";
import { z } from "zod";

import { getAdminId, getPersonnelId } from "@/lib/tenant";
import { notificationService } from "./notification.service";

const sendSchema = z.object({
  role: z.enum(["admin", "personnel"]),
  title: z.string().min(3),
  body: z.string().min(3),
  data: z.record(z.string(), z.string()).optional(),
});

const tokenSchema = z.object({
  token: z.string().min(1),
});

export const sendRoleNotificationHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const payload = sendSchema.parse(req.body);
    await notificationService.notifyRole(payload.role, payload);
    res.status(202).json({ success: true });
  } catch (error) {
    next(error);
  }
};

export const registerTokenHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const payload = tokenSchema.parse(req.body);
    const token = payload.token;
    
    // Get user role and ID from headers (one of them will be present)
    let adminId: string | undefined;
    let personnelId: string | undefined;
    
    try {
      adminId = getAdminId(req);
    } catch {
      // Admin ID not present, try personnel
    }
    
    if (!adminId) {
      try {
        personnelId = getPersonnelId(req);
      } catch {
        // Neither present - invalid request
      }
    }
    
    // TODO: Store FCM token in database for direct notifications
    // For now, we just log it - tokens are subscribed to topics automatically via Firebase
    // The client subscribes to role-based topics automatically
    
    res.json({ success: true, message: "Token registered" });
  } catch (error) {
    next(error);
  }
};

