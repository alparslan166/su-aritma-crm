import { fcmService } from "./fcm.service";
import { fcmAdminService } from "./fcm-admin.service";
import { realtimeGateway } from "@/modules/realtime/realtime.gateway";
import { logger } from "@/lib/logger";
import { prisma } from "@/lib/prisma";

type NotificationPayload = {
  title: string;
  body: string;
  data?: Record<string, string>;
};

export class NotificationService {
  /**
   * Get the active FCM service (Admin SDK if available, otherwise legacy)
   */
  private getFCMService() {
    // Try Admin SDK first (preferred)
    if (fcmAdminService.initialized) {
      return fcmAdminService;
    }
    // Fallback to legacy FCM service
    return fcmService;
  }

  /**
   * Send notification to all users of a specific role (backward compatibility)
   */
  async notifyRole(role: "admin" | "personnel", payload: NotificationPayload) {
    const service = this.getFCMService();
    await service.sendToRole(role, payload);
  }

  /**
   * Helper method to save notification to database and emit via Socket.IO
   */
  private async saveAndEmitNotification(
    adminId: string,
    targetRole: "admin" | "personnel",
    targetUserId: string,
    type: string,
    payload: NotificationPayload,
    jobId?: string,
  ) {
    try {
      // Save to database
      const notification = await prisma.notification.create({
        data: {
          adminId,
          jobId: jobId || null,
          targetRole,
          type,
          payload: {
            title: payload.title,
            body: payload.body,
            ...payload.data,
          },
        },
      });

      logger.info(`✅ Notification saved to DB: ${notification.id}`);

      // Emit via Socket.IO
      const socketPayload = {
        id: notification.id,
        title: payload.title,
        body: payload.body,
        type,
        receivedAt: notification.createdAt.toISOString(),
        meta: payload.data || {},
      };

      if (targetRole === "admin") {
        realtimeGateway.emitToAdmin(adminId, "notification", socketPayload);
      } else {
        realtimeGateway.emitToPersonnel(targetUserId, "notification", socketPayload);
      }

      logger.info(`✅ Notification emitted via Socket.IO to ${targetRole}:${targetUserId}`);
    } catch (error) {
      logger.error("❌ Failed to save/emit notification:", error);
      // Don't throw - notification should still be sent via FCM even if DB/Socket fails
    }
  }

  /**
   * Send notification when job is assigned to personnel
   */
  async sendJobAssignedToEmployee(personnelId: string, jobId: string, jobTitle: string) {
    const payload: NotificationPayload = {
      title: "Yeni İş Atandı",
      body: `"${jobTitle}" başlıklı yeni bir iş size atandı.`,
      data: {
        type: "job_assigned",
        jobId,
        personnelId,
        title: jobTitle,
      },
    };

    // Get adminId from personnel
    const personnel = await prisma.personnel.findUnique({
      where: { id: personnelId },
      select: { adminId: true },
    });

    if (!personnel) {
      logger.error(`❌ Personnel not found: ${personnelId}`);
      return;
    }

    const service = this.getFCMService();
    await service.sendToUser(personnelId, "personnel", payload);

    // Save to DB and emit via Socket.IO
    await this.saveAndEmitNotification(
      personnel.adminId,
      "personnel",
      personnelId,
      "job_assigned",
      payload,
      jobId,
    );
  }

  /**
   * Send notification when personnel starts a job
   */
  async sendJobStartedToAdmin(
    adminId: string,
    personnelId: string,
    jobId: string,
    jobTitle: string,
    personnelName: string,
  ) {
    const payload: NotificationPayload = {
      title: "İş Başlatıldı",
      body: `${personnelName}, "${jobTitle}" işine başladı.`,
      data: {
        type: "job_started",
        jobId,
        personnelId,
        adminId,
        title: jobTitle,
        personnelName,
      },
    };

    const service = this.getFCMService();
    await service.sendToUser(adminId, "admin", payload);

    // Save to DB and emit via Socket.IO
    await this.saveAndEmitNotification(
      adminId,
      "admin",
      adminId,
      "job_started",
      payload,
      jobId,
    );
  }

  /**
   * Send notification when personnel completes a job
   */
  async sendJobCompletedToAdmin(
    adminId: string,
    personnelId: string,
    jobId: string,
    jobTitle: string,
    personnelName: string,
  ) {
    const payload: NotificationPayload = {
      title: "İş Tamamlandı",
      body: `${personnelName}, "${jobTitle}" işini başarıyla tamamladı.`,
      data: {
        type: "job_completed",
        jobId,
        personnelId,
        adminId,
        title: jobTitle,
        personnelName,
      },
    };

    const service = this.getFCMService();
    await service.sendToUser(adminId, "admin", payload);

    // Save to DB and emit via Socket.IO
    await this.saveAndEmitNotification(
      adminId,
      "admin",
      adminId,
      "job_completed",
      payload,
      jobId,
    );
  }

  /**
   * Send notification when personnel creates a new customer
   */
  async sendCustomerCreatedToAdmin(
    adminId: string,
    personnelId: string,
    customerId: string,
    customerName: string,
    personnelName: string,
  ) {
    const payload: NotificationPayload = {
      title: "Yeni Müşteri Eklendi",
      body: `${personnelName}, "${customerName}" adlı yeni bir müşteri kaydı oluşturdu.`,
      data: {
        type: "customer_created",
        customerId,
        personnelId,
        adminId,
        customerName,
        personnelName,
      },
    };

    const service = this.getFCMService();
    await service.sendToUser(adminId, "admin", payload);

    // Save to DB and emit via Socket.IO
    await this.saveAndEmitNotification(
      adminId,
      "admin",
      adminId,
      "customer_created",
      payload,
    );
  }
}

export const notificationService = new NotificationService();
