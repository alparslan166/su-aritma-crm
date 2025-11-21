import { Request, Response } from "express";

import { prisma } from "@/lib/prisma";
import { getAdminId } from "@/lib/tenant";

const MS_IN_DAY = 1000 * 60 * 60 * 24;

export const listMaintenanceRemindersHandler = async (req: Request, res: Response) => {
  const adminId = getAdminId(req);
  const reminders = await prisma.maintenanceReminder.findMany({
    where: {
      job: {
        adminId,
      },
    },
    include: {
      job: {
        select: {
          id: true,
          title: true,
          maintenanceDueAt: true,
          status: true,
        },
      },
    },
    orderBy: {
      dueAt: "asc",
    },
  });

  const now = Date.now();
  const data = reminders.map((reminder) => ({
    id: reminder.id,
    jobId: reminder.jobId,
    jobTitle: reminder.job?.title ?? reminder.jobId,
    dueAt: reminder.dueAt,
    status: reminder.status,
    sentAt: reminder.sentAt,
    lastWindowNotified: reminder.lastWindowNotified,
    lastNotifiedAt: reminder.lastNotifiedAt,
    daysUntilDue: Math.ceil((reminder.dueAt.getTime() - now) / MS_IN_DAY),
  }));

  res.json({ success: true, data });
};

