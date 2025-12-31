import { MaintenanceStatus, MaintenanceWindow } from "@prisma/client";
import { Job } from "bullmq";

import { prisma } from "../lib/prisma";
import { notificationService } from "../modules/notifications/notification.service";
import { realtimeGateway } from "../modules/realtime/realtime.gateway";

const MS_IN_DAY = 1000 * 60 * 60 * 24;

const determineWindow = (diffInDays: number): MaintenanceWindow | null => {
  if (diffInDays <= 0) {
    return MaintenanceWindow.OVERDUE;
  }
  if (diffInDays <= 1) {
    return MaintenanceWindow.ONE_DAY;
  }
  if (diffInDays <= 3) {
    return MaintenanceWindow.THREE_DAYS;
  }
  if (diffInDays <= 7) {
    return MaintenanceWindow.SEVEN_DAYS;
  }
  return null;
};

export const maintenanceReminderProcessor = async (_job: Job) => {
  const now = new Date();
  const reminders = await prisma.maintenanceReminder.findMany({
    where: {
      status: MaintenanceStatus.PENDING,
    },
    include: {
      job: {
        select: {
          id: true,
          title: true,
          maintenanceDueAt: true,
          adminId: true, // Include adminId for targeted notifications
        },
      },
    },
  });

  for (const reminder of reminders) {
    const diffDays = Math.ceil((reminder.dueAt.getTime() - now.getTime()) / MS_IN_DAY);
    const window = determineWindow(diffDays);
    if (!window) {
      continue;
    }
    if (reminder.lastWindowNotified === window) {
      continue;
    }

    const job = reminder.job;
    
    // Skip if job doesn't have adminId (shouldn't happen, but be safe)
    if (!job?.adminId) {
      continue;
    }

    const payload = {
      id: reminder.id,
      jobId: reminder.jobId,
      jobTitle: job?.title ?? reminder.jobId,
      dueAt: reminder.dueAt,
      status: reminder.status,
      daysUntilDue: diffDays,
      lastWindowNotified: window,
    };

    const jobTitle = job?.title ?? "İş";
    let notificationBody: string;
    let notificationTitle: string;

    if (window === MaintenanceWindow.OVERDUE) {
      notificationTitle = "⚠️ Bakım Süresi Geçti";
      notificationBody = `"${jobTitle}" için bakım süresi doldu. Lütfen yeni bir bakım işi oluşturun.`;
    } else if (diffDays === 1) {
      notificationTitle = "🔔 Bakım Yarın";
      notificationBody = `"${jobTitle}" için bakım zamanı yarın. Hazırlıklarınızı tamamlayın.`;
    } else if (diffDays <= 3) {
      notificationTitle = "📅 Bakım Yaklaşıyor";
      notificationBody = `"${jobTitle}" için bakım zamanına ${diffDays} gün kaldı.`;
    } else {
      notificationTitle = "📋 Bakım Hatırlatması";
      notificationBody = `"${jobTitle}" için planlı bakıma ${diffDays} gün kaldı.`;
    }

    // Use targeted notification to only send to this job's admin
    await notificationService.sendMaintenanceReminderToAdmin(
      job.adminId,
      reminder.jobId,
      jobTitle,
      notificationTitle,
      notificationBody,
      window,
    );

    // Emit via realtime gateway to the specific admin only
    realtimeGateway.emitToAdmin(job.adminId, "maintenance-reminder", payload);

    await prisma.maintenanceReminder.update({
      where: { id: reminder.id },
      data: {
        lastWindowNotified: window,
        lastNotifiedAt: now,
        status: window === MaintenanceWindow.OVERDUE ? MaintenanceStatus.SENT : undefined,
        sentAt: window === MaintenanceWindow.OVERDUE ? now : undefined,
      },
    });
  }
};
