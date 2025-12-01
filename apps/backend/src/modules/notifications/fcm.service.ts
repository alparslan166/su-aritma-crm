import { config } from "@/config/env";
import { logger } from "@/lib/logger";
import { prisma } from "@/lib/prisma";
import { realtimeGateway } from "@/modules/realtime/realtime.gateway";

type NotificationPayload = {
  title: string;
  body: string;
  data?: Record<string, string>;
};

export class FCMService {
  /**
   * Send notification to specific device tokens
   */
  async sendToTokens(tokens: string[], payload: NotificationPayload): Promise<void> {
    if (tokens.length === 0) {
      logger.warn("No tokens provided for notification");
      return;
    }

    if (config.fcm.serverKey === "local" || !config.fcm.serverKey) {
      logger.warn("FCM server key not configured, skipping push notification");
      return;
    }

    // Use legacy FCM API for now (can be upgraded to v1 with service account)
    const promises = tokens.map((token) =>
      this.sendToToken(token, payload).catch((error) => {
        logger.error(`Failed to send notification to token ${token.substring(0, 20)}...`, error);
        // Remove invalid tokens
        if (
          error.message?.includes("InvalidRegistration") ||
          error.message?.includes("NotRegistered")
        ) {
          this.removeInvalidToken(token);
        }
      }),
    );

    await Promise.allSettled(promises);
  }

  /**
   * Send notification to a single device token
   */
  private async sendToToken(token: string, payload: NotificationPayload): Promise<void> {
    const response = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `key=${config.fcm.serverKey}`,
      },
      body: JSON.stringify({
        to: token,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: {
          ...payload.data,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        priority: "high",
      }),
    });

    if (!response.ok) {
      const text = await response.text();
      throw new Error(`FCM request failed: ${text}`);
    }

    const result = (await response.json()) as {
      failure?: number;
      results?: Array<{ error?: string }>;
    };
    if (result.failure === 1) {
      throw new Error(result.results?.[0]?.error || "FCM send failed");
    }
  }

  /**
   * Send notification to a topic
   */
  async sendToTopic(topic: string, payload: NotificationPayload): Promise<void> {
    if (config.fcm.serverKey === "local" || !config.fcm.serverKey) {
      logger.warn("FCM server key not configured, skipping push notification");
      return;
    }

    const response = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `key=${config.fcm.serverKey}`,
      },
      body: JSON.stringify({
        to: `/topics/${topic}`,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: {
          ...payload.data,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        priority: "high",
      }),
    });

    if (!response.ok) {
      const text = await response.text();
      throw new Error(`FCM request failed: ${text}`);
    }
  }

  /**
   * Send notification to all users of a specific role
   */
  async sendToRole(role: "admin" | "personnel", payload: NotificationPayload): Promise<void> {
    // Get all active device tokens for the role
    const tokens = await prisma.deviceToken.findMany({
      where: {
        userType: role,
        isActive: true,
      },
      select: {
        token: true,
      },
    });

    const tokenList = tokens.map((t: { token: string }) => t.token);
    if (tokenList.length > 0) {
      await this.sendToTokens(tokenList, payload);
    }

    // Also send via topic as fallback
    await this.sendToTopic(`role-${role}`, payload).catch((error) => {
      logger.error(`Failed to send to topic role-${role}`, error);
    });

    // Emit via WebSocket for real-time updates
    realtimeGateway.emitToRole(role, "notification", payload);
  }

  /**
   * Send notification to specific user (admin or personnel)
   */
  async sendToUser(
    userId: string,
    userType: "admin" | "personnel",
    payload: NotificationPayload,
  ): Promise<void> {
    const tokens = await prisma.deviceToken.findMany({
      where: {
        userId,
        userType,
        isActive: true,
      },
      select: {
        token: true,
      },
    });

    if (tokens.length > 0) {
      await this.sendToTokens(
        tokens.map((t: { token: string }) => t.token),
        payload,
      );
    }

    // Also emit via WebSocket
    logger.info(`📡 Emitting WebSocket notification to ${userType} ${userId}`);
    if (userType === "admin") {
      realtimeGateway.emitToAdmin(userId, "notification", payload);
      logger.info(`✅ WebSocket notification sent to admin ${userId}`);
    } else {
      realtimeGateway.emitToPersonnel(userId, "notification", payload);
      logger.info(`✅ WebSocket notification sent to personnel ${userId}`);
    }
  }

  /**
   * Register device token
   */
  async registerToken(
    token: string,
    userId: string,
    userType: "admin" | "personnel",
    platform: "android" | "ios" | "web",
  ): Promise<void> {
    await prisma.deviceToken.upsert({
      where: { token },
      create: {
        token,
        userId,
        userType,
        platform,
        isActive: true,
        lastUsedAt: new Date(),
        ...(userType === "admin" ? { adminId: userId } : { personnelId: userId }),
      },
      update: {
        userId,
        userType,
        platform,
        isActive: true,
        lastUsedAt: new Date(),
        ...(userType === "admin" ? { adminId: userId } : { personnelId: userId }),
      },
    });

    logger.info(`Device token registered: ${platform} for ${userType} ${userId}`);
  }

  /**
   * Remove invalid token
   */
  private async removeInvalidToken(token: string): Promise<void> {
    await prisma.deviceToken.updateMany({
      where: { token },
      data: { isActive: false },
    });
    logger.info(`Invalid token deactivated: ${token.substring(0, 20)}...`);
  }

  /**
   * Unregister device token (on logout)
   */
  async unregisterToken(token: string): Promise<void> {
    await prisma.deviceToken.updateMany({
      where: { token },
      data: { isActive: false },
    });
    logger.info(`Device token unregistered: ${token.substring(0, 20)}...`);
  }
}

export const fcmService = new FCMService();
