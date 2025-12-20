import { NextFunction, Request, Response } from "express";
import { z } from "zod";

import { getAdminId } from "../../lib/tenant";
import { AppError } from "../../middleware/error-handler";
import { SubscriptionService } from "./subscription.service";

const subscriptionService = new SubscriptionService();

export const getSubscriptionHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const subscription = await subscriptionService.getSubscription(adminId);

    if (!subscription) {
      return res.json({
        success: true,
        data: null,
        message: "No subscription found",
      });
    }

    res.json({
      success: true,
      data: subscription,
    });
  } catch (error) {
    next(error as Error);
  }
};

export const getAllSubscriptionsHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    // Only ANA admin can access this
    const adminId = getAdminId(req);
    const { prisma } = await import("@/lib/prisma");
    const admin = await prisma.admin.findUnique({
      where: { id: adminId },
    });

    if (!admin || admin.role !== "ANA") {
      throw new AppError("Unauthorized: Only ANA admin can access this", 403);
    }

    const subscriptions = await subscriptionService.getAllSubscriptions();

    res.json({
      success: true,
      data: subscriptions,
    });
  } catch (error) {
    next(error as Error);
  }
};

const activateSchema = z.object({
  planType: z.enum(["monthly", "yearly"]).default("monthly"),
  paymentId: z.string().optional(),
});

export const activateSubscriptionHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    const payload = activateSchema.parse(req.body);

    await subscriptionService.activateSubscription(adminId, payload.planType, payload.paymentId);

    res.json({
      success: true,
      message: "Subscription activated successfully",
    });
  } catch (error) {
    next(error as Error);
  }
};

const renewSchema = z.object({
  planType: z.enum(["monthly", "yearly"]).default("monthly"),
});

export const renewSubscriptionHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const payload = renewSchema.parse(req.body);

    await subscriptionService.renewSubscription(adminId, payload.planType);

    res.json({
      success: true,
      message: "Subscription renewed successfully",
    });
  } catch (error) {
    next(error as Error);
  }
};

export const cancelSubscriptionHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    await subscriptionService.cancelSubscription(adminId);

    res.json({
      success: true,
      message: "Subscription cancelled successfully",
    });
  } catch (error) {
    next(error as Error);
  }
};

// Mark trial started notice as seen (one-time)
export const markTrialNoticeSeenHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const adminId = getAdminId(req);
    await subscriptionService.markTrialNoticeSeen(adminId);
    res.json({ success: true });
  } catch (error) {
    next(error as Error);
  }
};
