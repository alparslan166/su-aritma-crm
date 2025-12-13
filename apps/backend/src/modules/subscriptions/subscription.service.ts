import { prisma } from "@/lib/prisma";
import { AppError } from "@/middleware/error-handler";

export type SubscriptionStatus = "trial" | "active" | "expired" | "cancelled";
export type PlanType = "monthly" | "yearly";

export class SubscriptionService {
  /**
   * Start a 30-day trial for a new admin
   */
  async startTrial(adminId: string): Promise<void> {
    const now = new Date();
    const trialEnds = new Date(now);
    trialEnds.setDate(trialEnds.getDate() + 30); // 30 days from now

    // Check if subscription already exists
    const existing = await prisma.subscription.findUnique({
      where: { adminId },
    });

    if (existing) {
      throw new AppError("Subscription already exists for this admin", 400);
    }

    await prisma.subscription.create({
      data: {
        adminId,
        planType: "monthly",
        status: "trial",
        startDate: now,
        endDate: trialEnds, // Trial end date
        trialEnds,
      },
    });

    console.log(`✅ Started 30-day trial for admin: ${adminId}`);
  }

  /**
   * Get subscription status for an admin
   */
  async getSubscription(adminId: string) {
    const subscription = await prisma.subscription.findUnique({
      where: { adminId },
      include: {
        admin: {
          select: {
            id: true,
            name: true,
            email: true,
            role: true,
          },
        },
      },
    });

    if (!subscription) {
      return null;
    }

    // Calculate current status based on dates
    const now = new Date();
    let currentStatus: SubscriptionStatus = subscription.status as SubscriptionStatus;

    if (subscription.status === "trial" && subscription.trialEnds) {
      if (now > subscription.trialEnds) {
        // Trial expired, update status
        currentStatus = "expired";
        await prisma.subscription.update({
          where: { id: subscription.id },
          data: { status: "expired" },
        });
      }
    } else if (subscription.status === "active") {
      if (now > subscription.endDate) {
        // Subscription expired
        currentStatus = "expired";
        await prisma.subscription.update({
          where: { id: subscription.id },
          data: { status: "expired" },
        });
      }
    }

    const daysRemaining = this.calculateDaysRemaining(subscription, now);

    const shouldShowTrialStartedNotice =
      currentStatus === "trial" && !subscription.trialStartedNoticeSeenAt;
    const shouldShowExpiryWarning =
      (currentStatus === "trial" || currentStatus === "active") &&
      typeof daysRemaining === "number" &&
      daysRemaining > 0 &&
      daysRemaining <= 3;
    const lockRequired = !(currentStatus === "trial" || currentStatus === "active");

    return {
      ...subscription,
      status: currentStatus,
      daysRemaining,
      isActive: currentStatus === "trial" || currentStatus === "active",
      isExpired: currentStatus === "expired",
      shouldShowTrialStartedNotice,
      shouldShowExpiryWarning,
      lockRequired,
    };
  }

  /**
   * Activate subscription after successful payment
   */
  async activateSubscription(
    adminId: string,
    planType: PlanType = "monthly",
    paymentId?: string,
  ): Promise<void> {
    const now = new Date();
    const endDate = new Date(now);
    
    if (planType === "monthly") {
      endDate.setMonth(endDate.getMonth() + 1);
    } else {
      endDate.setFullYear(endDate.getFullYear() + 1);
    }

    await prisma.subscription.upsert({
      where: { adminId },
      create: {
        adminId,
        planType,
        status: "active",
        startDate: now,
        endDate,
        trialEnds: null, // No trial for paid subscriptions
      },
      update: {
        planType,
        status: "active",
        startDate: now,
        endDate,
        trialEnds: null,
      },
    });

    console.log(`✅ Activated subscription for admin: ${adminId}, plan: ${planType}`);
  }

  /**
   * Renew subscription (extend end date)
   */
  async renewSubscription(adminId: string, planType: PlanType = "monthly"): Promise<void> {
    const subscription = await prisma.subscription.findUnique({
      where: { adminId },
    });

    if (!subscription) {
      throw new AppError("Subscription not found", 404);
    }

    const now = new Date();
    const currentEndDate = subscription.endDate > now ? subscription.endDate : now;
    const newEndDate = new Date(currentEndDate);

    if (planType === "monthly") {
      newEndDate.setMonth(newEndDate.getMonth() + 1);
    } else {
      newEndDate.setFullYear(newEndDate.getFullYear() + 1);
    }

    await prisma.subscription.update({
      where: { adminId },
      data: {
        planType,
        status: "active",
        endDate: newEndDate,
        trialEnds: null,
      },
    });

    console.log(`✅ Renewed subscription for admin: ${adminId}`);
  }

  /**
   * Cancel subscription
   */
  async cancelSubscription(adminId: string): Promise<void> {
    await prisma.subscription.update({
      where: { adminId },
      data: {
        status: "cancelled",
      },
    });

    console.log(`✅ Cancelled subscription for admin: ${adminId}`);
  }

  /**
   * Mark trial started notice as seen (one-time)
   */
  async markTrialNoticeSeen(adminId: string): Promise<void> {
    const subscription = await prisma.subscription.findUnique({
      where: { adminId },
    });
    if (!subscription) {
      throw new AppError("Subscription not found", 404);
    }
    if (subscription.trialStartedNoticeSeenAt) {
      return;
    }
    await prisma.subscription.update({
      where: { id: subscription.id },
      data: { trialStartedNoticeSeenAt: new Date() },
    });
  }

  /**
   * Check if admin has active subscription (trial or paid)
   */
  async hasActiveSubscription(adminId: string): Promise<boolean> {
    const subscription = await this.getSubscription(adminId);
    return subscription?.isActive ?? false;
  }

  /**
   * Calculate days remaining in trial or subscription
   */
  private calculateDaysRemaining(subscription: any, now: Date): number | null {
    let targetDate: Date | null = null;

    if (subscription.status === "trial" && subscription.trialEnds) {
      targetDate = subscription.trialEnds;
    } else if (subscription.status === "active") {
      targetDate = subscription.endDate;
    }

    if (!targetDate) {
      return null;
    }

    const diff = targetDate.getTime() - now.getTime();
    const days = Math.ceil(diff / (1000 * 60 * 60 * 24));
    return days > 0 ? days : 0;
  }

  /**
   * Get all subscriptions (for admin panel)
   */
  async getAllSubscriptions() {
    return prisma.subscription.findMany({
      include: {
        admin: {
          select: {
            id: true,
            name: true,
            email: true,
            role: true,
            createdAt: true,
          },
        },
      },
      orderBy: {
        createdAt: "desc",
      },
    });
  }
}

