import { Request, Response } from "express";

import { prisma } from "../../lib/prisma";
import { getAdminId } from "../../lib/tenant";

const MS_IN_DAY = 1000 * 60 * 60 * 24;

export const listMaintenanceRemindersHandler = async (req: Request, res: Response) => {
  const adminId = getAdminId(req);
  /* 
   * FETCH REMINDERS (JOB-BASED)
   */
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
  
  // Transform existing reminders
  const reminderData = reminders.map((reminder) => ({
    id: reminder.id,
    jobId: reminder.jobId,
    jobTitle: reminder.job?.title ?? reminder.jobId,
    dueAt: reminder.dueAt,
    status: reminder.status,
    sentAt: reminder.sentAt,
    lastWindowNotified: reminder.lastWindowNotified,
    lastNotifiedAt: reminder.lastNotifiedAt,
    daysUntilDue: Math.ceil((reminder.dueAt.getTime() - now) / MS_IN_DAY),
    type: "JOB_REMINDER",
  }));

  /* 
   * FETCH ORPHAN CUSTOMERS (NEXT MAINTENANCE DATE BUT NO REMINDER)
   */
  // Find customers who have a nextMaintenanceDate set
  const customersWithMaintenance = await prisma.customer.findMany({
    where: {
      adminId,
      nextMaintenanceDate: { not: null },
      status: "ACTIVE", // Only active customers
    },
    select: {
      id: true,
      name: true,
      nextMaintenanceDate: true,
      jobs: {
        select: { id: true },
      },
    },
  });

  // Get Set of Job IDs that already have reminders
  const existingJobIds = new Set(reminders.map((r) => r.jobId));

  // Filter customers:
  // We want to show a customer-based reminder IF:
  // 1. They have a date (checked in query)
  // 2. They don't have an active maintenance reminder (via their jobs)
  // Logic: Check if ANY of the customer's jobs are in the existingJobIds set.
  // If so, we assume the system is tracking it via that job.
  // If not, we add a generic customer reminder.
  
  const orphanCustomers = customersWithMaintenance.filter((customer) => {
    const hasActiveReminder = customer.jobs.some((job) => existingJobIds.has(job.id));
    return !hasActiveReminder;
  });

  const customerData = orphanCustomers.map((customer) => {
    const dueAt = customer.nextMaintenanceDate!; // checked not null in query
    return {
      id: `customer_${customer.id}`, // Synthetic ID
      jobId: customer.id, // Use customer ID as placeholder for jobId
      jobTitle: `${customer.name} - Periyodik Bakım`,
      dueAt: dueAt,
      status: "PENDING",
      sentAt: null,
      lastWindowNotified: null,
      lastNotifiedAt: null,
      daysUntilDue: Math.ceil((dueAt.getTime() - now) / MS_IN_DAY),
      type: "CUSTOMER_MAINTENANCE",
    };
  });

  // Combine and Sort
  const combinedData = [...reminderData, ...customerData].sort((a, b) => {
    return new Date(a.dueAt).getTime() - new Date(b.dueAt).getTime();
  });

  res.json({ success: true, data: combinedData });
};

