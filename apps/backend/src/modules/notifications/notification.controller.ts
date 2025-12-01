import { NextFunction, Request, Response } from "express";
import { z } from "zod";

import { getAdminId, getPersonnelId } from "@/lib/tenant";
import { notificationService } from "./notification.service";
import { fcmService } from "./fcm.service";

const sendSchema = z.object({
  role: z.enum(["admin", "personnel"]),
  title: z.string().min(3),
  body: z.string().min(3),
  data: z.record(z.string(), z.string()).optional(),
});

const tokenSchema = z.object({
  token: z.string().min(1),
  platform: z.enum(["android", "ios", "web"]),
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
    const { token, platform } = payload;
    
    // Get user role and ID from headers (one of them will be present)
    let adminId: string | undefined;
    let personnelId: string | undefined;
    let userType: "admin" | "personnel" | undefined;
    let userId: string | undefined;
    
    try {
      adminId = getAdminId(req);
      userType = "admin";
      userId = adminId;
    } catch {
      // Admin ID not present, try personnel
      try {
        personnelId = getPersonnelId(req);
        userType = "personnel";
        userId = personnelId;
      } catch {
        // Neither present - invalid request
        return res.status(401).json({ 
          success: false, 
          error: "Authentication required" 
        });
      }
    }
    
    if (!userId || !userType) {
      return res.status(401).json({ 
        success: false, 
        error: "User identification required" 
      });
    }
    
    // Register token in database
    await fcmService.registerToken(token, userId, userType, platform);
    
    res.json({ success: true, message: "Token registered successfully" });
  } catch (error) {
    next(error);
  }
};

export const unregisterTokenHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const payload = tokenSchema.parse(req.body);
    const { token } = payload;
    
    await fcmService.unregisterToken(token);
    
    res.json({ success: true, message: "Token unregistered successfully" });
  } catch (error) {
    next(error);
  }
};

