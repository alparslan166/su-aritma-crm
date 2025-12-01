import * as admin from "firebase-admin";
import { prisma } from "@/lib/prisma";
import { logger } from "@/lib/logger";
import { realtimeGateway } from "@/modules/realtime/realtime.gateway";
import { config } from "@/config/env";

type NotificationPayload = {
  title: string;
  body: string;
  data?: Record<string, string>;
};

// Initialize Firebase Admin SDK
let firebaseApp: admin.app.App | null = null;

function initializeFirebase() {
  if (firebaseApp) {
    return firebaseApp;
  }

  try {
    // Try to initialize from service account JSON (Railway environment variable)
    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
      const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
      firebaseApp = admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      logger.info("Firebase Admin SDK initialized from environment variable");
      return firebaseApp;
    }

    // Try to initialize from service account file (local development)
    try {
      const serviceAccount = require("../../firebase-service-account.json");
      firebaseApp = admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      logger.info("Firebase Admin SDK initialized from service account file");
      return firebaseApp;
    } catch (fileError) {
      // File doesn't exist, try environment variables
      if (
        process.env.FIREBASE_PROJECT_ID &&
        process.env.FIREBASE_PRIVATE_KEY &&
        process.env.FIREBASE_CLIENT_EMAIL
      ) {
        firebaseApp = admin.initializeApp({
          credential: admin.credential.cert({
            projectId: process.env.FIREBASE_PROJECT_ID,
            privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n"),
            clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
          }),
        });
        logger.info("Firebase Admin SDK initialized from environment variables");
        return firebaseApp;
      }
    }

    logger.warn("Firebase Admin SDK not initialized - FCM notifications will be disabled");
    return null;
  } catch (error) {
    logger.error("Failed to initialize Firebase Admin SDK:", error);
    return null;
  }
}

export class FCMAdminService {
  private messaging: admin.messaging.Messaging | null = null;
  private isInitialized = false;

  constructor() {
    const app = initializeFirebase();
    if (app) {
      this.messaging = admin.messaging(app);
      this.isInitialized = true;
    }
  }

  get initialized(): boolean {
    return this.isInitialized && this.messaging !== null;
  }

  /**
   * Send notification to specific device tokens
   */
  async sendToTokens(tokens: string[], payload: NotificationPayload): Promise<void> {
    if (tokens.length === 0) {
      logger.warn("No tokens provided for notification");
      return;
    }

    if (!this.messaging) {
      logger.warn("Firebase Admin SDK not initialized, skipping push notification");
      return;
    }

    const message: admin.messaging.MulticastMessage = {
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: payload.data || {},
      tokens,
      android: {
        priority: "high",
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
      },
    };

    try {
      const response = await this.messaging.sendEachForMulticast(message);
      logger.info(`Successfully sent ${response.successCount} notifications`);

      // Remove invalid tokens
      if (response.failureCount > 0) {
        response.responses.forEach((resp, idx) => {
          if (!resp.success && resp.error) {
            const token = tokens[idx];
            logger.error(
              `Failed to send to token ${token.substring(0, 20)}...: ${resp.error.message}`,
            );
            if (
              resp.error.code === "messaging/invalid-registration-token" ||
              resp.error.code === "messaging/registration-token-not-registered"
            ) {
              this.removeInvalidToken(token);
            }
          }
        });
      }
    } catch (error) {
      logger.error("Failed to send multicast notification:", error);
    }
  }

  /**
   * Send notification to a single device token
   */
  async sendToToken(token: string, payload: NotificationPayload): Promise<void> {
    if (!this.messaging) {
      logger.warn("Firebase Admin SDK not initialized, skipping push notification");
      return;
    }

    const message: admin.messaging.Message = {
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: payload.data || {},
      token,
      android: {
        priority: "high",
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
      },
    };

    try {
      await this.messaging.send(message);
    } catch (error: any) {
      if (
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered"
      ) {
        await this.removeInvalidToken(token);
      }
      throw error;
    }
  }

  /**
   * Send notification to a topic
   */
  async sendToTopic(topic: string, payload: NotificationPayload): Promise<void> {
    if (!this.messaging) {
      logger.warn("Firebase Admin SDK not initialized, skipping push notification");
      return;
    }

    const message: admin.messaging.Message = {
      notification: {
        title: payload.title,
        body: payload.body,
      },
      data: payload.data || {},
      topic,
      android: {
        priority: "high",
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
      },
    };

    try {
      await this.messaging.send(message);
    } catch (error) {
      logger.error(`Failed to send to topic ${topic}:`, error);
      throw error;
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

    const tokenList = tokens.map((t) => t.token);
    if (tokenList.length > 0) {
      await this.sendToTokens(tokenList, payload);
    }

    // Also send via topic as fallback
    try {
      await this.sendToTopic(`role-${role}`, payload);
    } catch (error) {
      logger.error(`Failed to send to topic role-${role}`, error);
    }

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
        tokens.map((t) => t.token),
        payload,
      );
    }

    // Also emit via WebSocket
    if (userType === "admin") {
      realtimeGateway.emitToAdmin(userId, "notification", payload);
    } else {
      realtimeGateway.emitToPersonnel(userId, "notification", payload);
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

export const fcmAdminService = new FCMAdminService();
