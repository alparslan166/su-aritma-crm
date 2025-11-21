import { config } from "@/config/env";
import { realtimeGateway } from "@/modules/realtime/realtime.gateway";

type NotificationPayload = {
  title: string;
  body: string;
  data?: Record<string, string>;
};

export class NotificationService {
  async notifyRole(role: "admin" | "personnel", payload: NotificationPayload) {
    await this.sendPush({
      topic: `role-${role}`,
      ...payload,
    });

    realtimeGateway.emitToRole(role, "notification", payload);
  }

  private async sendPush({
    topic,
    title,
    body,
    data,
  }: NotificationPayload & { topic: string }) {
    const response = await fetch("https://fcm.googleapis.com/fcm/send", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `key=${config.fcm.serverKey}`,
      },
      body: JSON.stringify({
        to: `/topics/${topic}`,
        notification: { title, body },
        data,
      }),
    });

    if (!response.ok) {
      const text = await response.text();
      throw new Error(`FCM request failed: ${text}`);
    }
  }
}

export const notificationService = new NotificationService();

