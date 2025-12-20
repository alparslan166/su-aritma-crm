import { NextFunction, Request, Response } from "express";
import { z } from "zod";

import { getAdminId, getPersonnelId } from "@/lib/tenant";
import { prisma } from "@/lib/prisma";
import { notificationService } from "./notification.service";
import { fcmService } from "./fcm.service";
import { fcmAdminService } from "./fcm-admin.service";

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

export const registerTokenHandler = async (req: Request, res: Response, next: NextFunction) => {
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
          error: "Authentication required",
        });
      }
    }

    if (!userId || !userType) {
      return res.status(401).json({
        success: false,
        error: "User identification required",
      });
    }

    // Register token in database (use Admin SDK if available, otherwise legacy)
    try {
      await fcmAdminService.registerToken(token, userId, userType, platform);
    } catch {
      // Fallback to legacy service
      await fcmService.registerToken(token, userId, userType, platform);
    }

    res.json({ success: true, message: "Token registered successfully" });
  } catch (error) {
    next(error);
  }
};

export const unregisterTokenHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const payload = tokenSchema.parse(req.body);
    const { token } = payload;

    // Unregister token (use Admin SDK if available, otherwise legacy)
    try {
      await fcmAdminService.unregisterToken(token);
    } catch {
      // Fallback to legacy service
      await fcmService.unregisterToken(token);
    }

    res.json({ success: true, message: "Token unregistered successfully" });
  } catch (error) {
    next(error);
  }
};

export const listNotificationsHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    // Get user role and ID
    let adminId: string | undefined;
    let personnelId: string | undefined;
    let targetRole: "admin" | "personnel" | undefined;
    let userId: string | undefined;

    try {
      adminId = getAdminId(req);
      targetRole = "admin";
      userId = adminId;
    } catch {
      try {
        personnelId = getPersonnelId(req);
        targetRole = "personnel";
        userId = personnelId;
        
        // Get adminId from personnel
        const personnel = await prisma.personnel.findUnique({
          where: { id: personnelId },
          select: { adminId: true },
        });
        if (personnel) {
          adminId = personnel.adminId;
        }
      } catch {
        return res.status(401).json({
          success: false,
          error: "Authentication required",
        });
      }
    }

    if (!adminId || !targetRole) {
      return res.status(401).json({
        success: false,
        error: "User identification required",
      });
    }

    // Fetch notifications for this admin/role
    const notifications = await prisma.notification.findMany({
      where: {
        adminId,
        targetRole,
      },
      orderBy: {
        createdAt: "desc",
      },
      take: 100, // Limit to last 100 notifications
    });

    // Transform notifications to match mobile app format
    const formattedNotifications = notifications.map((n) => {
      const payload = n.payload as Record<string, unknown>;
      return {
        id: n.id,
        title: payload.title as string,
        body: payload.body as string,
        type: n.type,
        receivedAt: n.createdAt.toISOString(),
        readAt: n.readAt?.toISOString() || null,
        meta: {
          ...payload,
          // Remove title/body from meta as they're already top-level
          title: undefined,
          body: undefined,
        },
      };
    });

    res.json({ success: true, data: formattedNotifications });
  } catch (error) {
    next(error);
  }
};

export const markNotificationReadHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const notificationId = req.params.id;

    // Verify user has access to this notification
    let adminId: string | undefined;
    let personnelId: string | undefined;

    try {
      adminId = getAdminId(req);
    } catch {
      try {
        personnelId = getPersonnelId(req);
        const personnel = await prisma.personnel.findUnique({
          where: { id: personnelId },
          select: { adminId: true },
        });
        if (personnel) {
          adminId = personnel.adminId;
        }
      } catch {
        return res.status(401).json({
          success: false,
          error: "Authentication required",
        });
      }
    }

    if (!adminId) {
      return res.status(401).json({
        success: false,
        error: "User identification required",
      });
    }

    // Mark as read
    await prisma.notification.updateMany({
      where: {
        id: notificationId,
        adminId, // Ensure user owns this notification
      },
      data: {
        readAt: new Date(),
      },
    });

    res.json({ success: true });
  } catch (error) {
    next(error);
  }
};
