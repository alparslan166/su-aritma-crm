import { fcmService } from "./fcm.service";
import { fcmAdminService } from "./fcm-admin.service";
import { realtimeGateway } from "@/modules/realtime/realtime.gateway";
import { logger } from "@/lib/logger";

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
   * Send notification when job is assigned to personnel
   */
  async sendJobAssignedToEmployee(personnelId: string, jobId: string, jobTitle: string) {
    const payload: NotificationPayload = {
      title: "Yeni İş Atandı",
      body: `${jobTitle} işi size atandı`,
      data: {
        type: "job_assigned",
        jobId,
        personnelId,
        title: jobTitle,
      },
    };

    const service = this.getFCMService();
    await service.sendToUser(personnelId, "personnel", payload);
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
      body: `${personnelName} "${jobTitle}" işine başladı`,
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
      body: `${personnelName} "${jobTitle}" işini tamamladı`,
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
      body: `${personnelName} "${customerName}" adlı yeni bir müşteri ekledi`,
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
  }
}

export const notificationService = new NotificationService();
