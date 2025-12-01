import { fcmService } from "./fcm.service";
import { realtimeGateway } from "@/modules/realtime/realtime.gateway";

type NotificationPayload = {
  title: string;
  body: string;
  data?: Record<string, string>;
};

export class NotificationService {
  /**
   * Send notification to all users of a specific role (backward compatibility)
   */
  async notifyRole(role: "admin" | "personnel", payload: NotificationPayload) {
    await fcmService.sendToRole(role, payload);
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

    await fcmService.sendToUser(personnelId, "personnel", payload);
  }

  /**
   * Send notification when personnel starts a job
   */
  async sendJobStartedToAdmin(adminId: string, personnelId: string, jobId: string, jobTitle: string, personnelName: string) {
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

    await fcmService.sendToUser(adminId, "admin", payload);
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

    await fcmService.sendToUser(adminId, "admin", payload);
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

    await fcmService.sendToUser(adminId, "admin", payload);
  }
}

export const notificationService = new NotificationService();
