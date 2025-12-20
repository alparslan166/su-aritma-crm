import {
  InventoryTransactionType,
  JobNoteAuthorType,
  JobStatus,
  MaintenanceStatus,
  PaymentStatus,
  PersonnelStatus,
  Prisma,
  PrismaClient,
} from "@prisma/client";

import { logger } from "@/lib/logger";
import { prisma } from "@/lib/prisma";
import { AppError } from "@/middleware/error-handler";
import { notificationService } from "@/modules/notifications/notification.service";
import { realtimeGateway } from "@/modules/realtime/realtime.gateway";

// Telefon numarasını normalize et (boşlukları ve özel karakterleri temizle)
function normalizePhoneNumber(phone: string): string {
  // Tüm boşlukları, tireleri, parantezleri ve diğer özel karakterleri temizle
  // Sadece rakamları ve başta + işaretini tut
  return phone.replace(/[\s\-()]/g, "");
}

type CustomerInput = {
  id?: string;
  name: string;
  phone: string;
  email?: string;
  address: string;
};

type LocationPayload = Record<string, unknown>;

type CreateJobPayload = {
  title: string;
  customer?: CustomerInput;
  customerId?: string;
  scheduledAt?: Date;
  location: LocationPayload;
  price?: Prisma.Decimal | number;
  hasInstallment?: boolean;
  notes?: string;
  maintenanceDueAt?: Date;
  personnelIds?: string[];
  materialIds?: Array<{ inventoryItemId: string; quantity: number }>;
};

type UpdateJobPayload = Partial<CreateJobPayload> & {
  status?: JobStatus;
};

type StatusUpdatePayload = {
  status: JobStatus;
  note?: string;
  performerType: "admin" | "personnel";
  performerId: string;
};

type DeliveryMaterialPayload = {
  inventoryItemId: string;
  quantity: number;
};

type DeliveryPayload = {
  note?: string;
  collectedAmount?: number;
  maintenanceIntervalMonths?: number;
  usedMaterials?: DeliveryMaterialPayload[];
  photoUrls?: string[];
};

type JobListFilters = {
  status?: JobStatus;
  search?: string;
  personnelId?: string;
};

const statusTimestampMap: Record<JobStatus, keyof Prisma.JobUpdateInput | null> = {
  PENDING: null,
  IN_PROGRESS: "startedAt",
  DELIVERED: "deliveredAt",
  ARCHIVED: "archivedAt",
};

type PrismaClientOrTx = Prisma.TransactionClient | PrismaClient;
type PrismaTransaction = Prisma.TransactionClient;

const READ_ONLY_WINDOW_HOURS = 48;
const MS_IN_DAY = 1000 * 60 * 60 * 24;

const addMonths = (date: Date, months: number) => {
  const result = new Date(date);
  result.setMonth(result.getMonth() + months);
  return result;
};

class JobService {
  private async ensureJob(adminId: string, jobId: string, tx: PrismaClientOrTx = prisma) {
    const job = await tx.job.findFirst({ where: { id: jobId, adminId } });
    if (!job) {
      throw new AppError("Job not found", 404);
    }
    return job;
  }

  private getStatusText(status: string): string {
    const statusMap: Record<string, string> = {
      PENDING: "Beklemede",
      IN_PROGRESS: "Devam Ediyor",
      DELIVERED: "Teslim Edildi",
      ARCHIVED: "Arşivlendi",
    };
    return statusMap[status] || status;
  }

  async list(adminId: string, filters: JobListFilters) {
    return prisma.job.findMany({
      where: {
        adminId,
        status: filters.status,
        ...(filters.search
          ? {
              OR: [
                { title: { contains: filters.search, mode: Prisma.QueryMode.insensitive } },
                {
                  customer: {
                    name: { contains: filters.search, mode: Prisma.QueryMode.insensitive },
                  },
                },
                { notes: { contains: filters.search, mode: Prisma.QueryMode.insensitive } },
              ],
            }
          : {}),
        ...(filters.personnelId
          ? {
              personnel: {
                some: { personnelId: filters.personnelId },
              },
            }
          : {}),
      },
      include: {
        customer: true,
        personnel: { include: { personnel: true } },
      },
      orderBy: { createdAt: "desc" },
    });
  }

  async getById(adminId: string, jobId: string) {
    return prisma.job.findFirst({
      where: { id: jobId, adminId },
      include: {
        customer: true,
        personnel: { include: { personnel: true } },
        materials: { include: { inventoryItem: true } },
      },
    });
  }

  private async resolveCustomer(
    adminId: string,
    input: CustomerInput,
    tx: PrismaClientOrTx = prisma,
  ) {
    try {
      logger.debug("🔄 Resolving customer, input:", JSON.stringify(input, null, 2));
      if (input.id) {
        logger.debug("🔍 Looking up existing customer:", input.id);
        const customer = await tx.customer.findFirst({
          where: { id: input.id, adminId },
        });
        if (!customer) {
          logger.error("🛑 Customer not found:", input.id);
          throw new AppError("Customer not found", 404);
        }
        logger.debug("✅ Customer found:", customer.id);
        return customer;
      }
      logger.debug("🔄 Creating new customer...");
      const newCustomer = await tx.customer.create({
        data: {
          adminId,
          name: input.name,
          phone: normalizePhoneNumber(input.phone),
          email: input.email,
          address: input.address,
        },
      });
      logger.debug("✅ Customer created:", newCustomer.id);
      return newCustomer;
    } catch (error) {
      logger.error("🛑 RESOLVE CUSTOMER ERROR:");
      logger.error("Error type:", error?.constructor?.name);
      logger.error("Error message:", (error as Error)?.message);
      logger.error("Error stack:", (error as Error)?.stack);
      if (error && typeof error === "object" && "code" in error) {
        logger.error("Prisma error code:", (error as { code: unknown }).code);
      }
      if (error && typeof error === "object" && "meta" in error) {
        logger.error(
          "Prisma error meta:",
          JSON.stringify((error as { meta: unknown }).meta, null, 2),
        );
      }
      throw error;
    }
  }

  private async validatePersonnel(adminId: string, ids: string[], tx: PrismaClientOrTx = prisma) {
    if (!ids.length) return [];
    const personnel = await tx.personnel.findMany({
      where: { adminId, id: { in: ids }, status: PersonnelStatus.ACTIVE },
    });
    if (personnel.length !== ids.length) {
      throw new AppError("One or more personnel not found or inactive", 400);
    }
    return personnel;
  }

  async create(adminId: string, payload: CreateJobPayload) {
    try {
      logger.debug("🔄 JOB SERVICE CREATE START");
      logger.debug("📥 Admin ID:", adminId);
      logger.debug("📥 Payload:", JSON.stringify(payload, null, 2));

      return await prisma.$transaction(async (tx) => {
        try {
          logger.debug("🔄 Transaction started");

          // Resolve customer (opsiyonel)
          let customer;
          let customerId: string | null = null;
          if (payload.customerId) {
            customer = await tx.customer.findFirst({
              where: { id: payload.customerId, adminId },
            });
            if (!customer) {
              throw new AppError("Customer not found", 404);
            }
            customerId = customer.id;
            logger.debug("✅ Customer found by ID:", customer.id);
          } else if (payload.customer) {
            customer = await this.resolveCustomer(adminId, payload.customer, tx);
            customerId = customer.id;
            logger.debug("✅ Customer resolved:", customer.id);
          } else {
            // Customer opsiyonel - müşteri seçilmeden de iş oluşturulabilir
            logger.debug("ℹ️ No customer provided - creating job without customer");
          }

          logger.debug("🔄 Creating job...");
          const jobData = {
            adminId,
            customerId: customerId,
            title: payload.title,
            scheduledAt: payload.scheduledAt,
            location: payload.location as Prisma.InputJsonValue,
            price: payload.price ? new Prisma.Decimal(payload.price) : undefined,
            hasInstallment: payload.hasInstallment ?? false,
            notes: payload.notes,
            maintenanceDueAt: payload.maintenanceDueAt,
          };
          logger.debug("📥 Job data:", JSON.stringify(jobData, null, 2));

          const job = await tx.job.create({
            data: jobData,
          });
          logger.debug("✅ Job created:", job.id);

          // Add materials if provided
          // NOTE: Stock is NOT deducted here - it will be deducted when personnel delivers the job
          if (payload.materialIds?.length) {
            logger.debug("🔄 Adding materials (no stock deduction at job creation)...");
            for (const material of payload.materialIds) {
              const item = await tx.inventoryItem.findFirst({
                where: { id: material.inventoryItemId, adminId },
              });
              if (!item) {
                throw new AppError(`Inventory item ${material.inventoryItemId} not found`, 404);
              }
              // No stock check or deduction here - stock will be checked and deducted at delivery time
              await tx.jobMaterial.create({
                data: {
                  jobId: job.id,
                  inventoryItemId: material.inventoryItemId,
                  quantity: material.quantity,
                  unitPrice: item.unitPrice,
                },
              });
            }
            logger.debug("✅ Materials added (stock will be deducted at delivery)");
          }

          if (payload.personnelIds?.length) {
            logger.debug("🔄 Validating personnel:", payload.personnelIds);
            await this.validatePersonnel(adminId, payload.personnelIds, tx);
            logger.debug("✅ Personnel validated");

            logger.debug("🔄 Creating job-personnel assignments...");
            await tx.jobPersonnel.createMany({
              data: payload.personnelIds.map((personnelId) => ({
                jobId: job.id,
                personnelId,
              })),
            });
            logger.debug("✅ Job-personnel assignments created");
          }

          if (payload.notes) {
            logger.debug("🔄 Creating job note...");
            await tx.jobNote.create({
              data: {
                jobId: job.id,
                authorType: JobNoteAuthorType.ALT_ADMIN,
                adminAuthorId: adminId,
                content: payload.notes,
              },
            });
            logger.debug("✅ Job note created");
          }

          logger.debug("✅ Transaction completed successfully");
          return job;
        } catch (txError) {
          logger.error("🛑 TRANSACTION ERROR in job.service.create:");
          logger.error("Error type:", txError?.constructor?.name);
          logger.error("Error message:", (txError as Error)?.message);
          logger.error("Error stack:", (txError as Error)?.stack);
          if (txError && typeof txError === "object" && "code" in txError) {
            logger.error("Prisma error code:", (txError as { code: unknown }).code);
          }
          if (txError && typeof txError === "object" && "meta" in txError) {
            logger.error(
              "Prisma error meta:",
              JSON.stringify((txError as { meta: unknown }).meta, null, 2),
            );
          }
          throw txError;
        }
      });
    } catch (error) {
      logger.error("🛑 JOB SERVICE CREATE ERROR:");
      logger.error("Error type:", error?.constructor?.name);
      logger.error("Error message:", (error as Error)?.message);
      logger.error("Error stack:", (error as Error)?.stack);
      if (error && typeof error === "object" && "code" in error) {
        logger.error("Prisma error code:", (error as { code: unknown }).code);
      }
      if (error && typeof error === "object" && "meta" in error) {
        logger.error(
          "Prisma error meta:",
          JSON.stringify((error as { meta: unknown }).meta, null, 2),
        );
      }
      throw error;
    }
  }

  async update(adminId: string, jobId: string, payload: UpdateJobPayload) {
    await this.ensureJob(adminId, jobId);
    const updateData: Prisma.JobUpdateInput = {
      title: payload.title,
      scheduledAt: payload.scheduledAt,
      location: payload.location as Prisma.InputJsonValue | undefined,
      price: payload.price ? new Prisma.Decimal(payload.price as number) : undefined,
      hasInstallment: payload.hasInstallment,
      notes: payload.notes,
      maintenanceDueAt: payload.maintenanceDueAt,
    };
    return prisma.job.update({
      where: { id: jobId },
      data: updateData,
    });
  }

  async assignPersonnel(adminId: string, jobId: string, personnelIds: string[]) {
    await this.ensureJob(adminId, jobId);
    await this.validatePersonnel(adminId, personnelIds);

    const job = await prisma.$transaction(async (tx) => {
      await tx.jobPersonnel.deleteMany({ where: { jobId } });
      await tx.jobPersonnel.createMany({
        data: personnelIds.map((personnelId) => ({ jobId, personnelId })),
      });
      return tx.job.findUnique({
        where: { id: jobId },
        include: { personnel: { include: { personnel: true } }, customer: true },
      });
    });

    // Send notifications to assigned personnel
    if (job && job.personnel) {
      const notificationPromises = job.personnel.map((assignment) =>
        notificationService
          .sendJobAssignedToEmployee(assignment.personnelId, job.id, job.title ?? "İş")
          .catch((error) => {
            logger.error(
              `Failed to send notification to personnel ${assignment.personnelId}:`,
              error,
            );
          }),
      );
      await Promise.allSettled(notificationPromises);
    }

    return job;
  }

  async updateStatus(
    adminId: string,
    jobId: string,
    payload: StatusUpdatePayload,
    tx?: PrismaTransaction,
  ) {
    if (tx) {
      return this.updateStatusWithTx(tx, adminId, jobId, payload);
    }
    const job = await prisma.$transaction((transaction) =>
      this.updateStatusWithTx(transaction, adminId, jobId, payload),
    );
    return job;
  }

  private async updateStatusWithTx(
    tx: PrismaTransaction,
    adminId: string,
    jobId: string,
    payload: StatusUpdatePayload,
  ) {
    await this.ensureJob(adminId, jobId, tx);
    const timestampField = statusTimestampMap[payload.status];
    const now = new Date();

    const job = await tx.job.update({
      where: { id: jobId },
      data: {
        status: payload.status,
        statusChangedAt: now,
        ...(timestampField ? { [timestampField]: now } : {}),
      },
    });

    await tx.jobStatusHistory.create({
      data: {
        jobId,
        status: payload.status,
        note: payload.note,
        changedByAdminId: payload.performerType === "admin" ? payload.performerId : undefined,
        changedByPersonnelId:
          payload.performerType === "personnel" ? payload.performerId : undefined,
      },
    });

    if (payload.note) {
      await tx.jobNote.create({
        data: {
          jobId,
          authorType:
            payload.performerType === "admin"
              ? JobNoteAuthorType.ALT_ADMIN
              : JobNoteAuthorType.PERSONNEL,
          adminAuthorId: payload.performerType === "admin" ? payload.performerId : undefined,
          personnelAuthorId:
            payload.performerType === "personnel" ? payload.performerId : undefined,
          content: payload.note,
        },
      });
    }

    if (payload.performerType === "personnel") {
      const updateData: Prisma.JobPersonnelUpdateInput = {};
      if (payload.status === JobStatus.IN_PROGRESS) {
        updateData.startedAt = now;
      }
      if (payload.status === JobStatus.DELIVERED) {
        updateData.deliveredAt = now;
      }
      if (Object.keys(updateData).length > 0) {
        await tx.jobPersonnel.update({
          where: { jobId_personnelId: { jobId, personnelId: payload.performerId } },
          data: updateData,
        });
      }
    }

    realtimeGateway.emitJobStatus(jobId, job);

    // Notification göndermeyi try-catch ile sarmalayalım - hata durumunda job update devam etmeli
    try {
      const statusText = this.getStatusText(payload.status);
      await notificationService.notifyRole("admin", {
        title: "İş Durumu Değişti",
        body: `"${job.title}" işi ${statusText} durumuna güncellendi`,
        data: { 
          type: "job_status_updated",
          jobId, 
          status: payload.status,
          title: job.title,
        },
      });
    } catch (error) {
      // Notification hatası job update'i engellememeli
      logger.error("Failed to send notification:", error);
    }

    return job;
  }

  async listHistory(adminId: string, jobId: string) {
    await this.ensureJob(adminId, jobId);
    return prisma.jobStatusHistory.findMany({
      where: { jobId },
      orderBy: { createdAt: "desc" },
    });
  }

  async listNotes(adminId: string, jobId: string) {
    await this.ensureJob(adminId, jobId);
    return prisma.jobNote.findMany({
      where: { jobId },
      orderBy: { createdAt: "desc" },
    });
  }

  async addNote(adminId: string, jobId: string, content: string, performerId: string) {
    await this.ensureJob(adminId, jobId);
    return prisma.jobNote.create({
      data: {
        jobId,
        content,
        authorType: JobNoteAuthorType.ALT_ADMIN,
        adminAuthorId: performerId,
      },
    });
  }

  async delete(adminId: string, jobId: string) {
    await this.ensureJob(adminId, jobId);

    // MaintenanceReminder will be automatically deleted due to CASCADE
    await prisma.job.delete({
      where: { id: jobId },
    });
  }

  private isAssignmentReadOnly(deliveredAt?: Date | null) {
    if (!deliveredAt) {
      return false;
    }
    const diffMs = Date.now() - deliveredAt.getTime();
    const hours = diffMs / (1000 * 60 * 60);
    return hours > READ_ONLY_WINDOW_HOURS;
  }

  private async ensurePersonnelAssignment(
    jobId: string,
    personnelId: string,
    tx: PrismaClientOrTx = prisma,
  ) {
    const assignment = await tx.jobPersonnel.findUnique({
      where: { jobId_personnelId: { jobId, personnelId } },
      include: {
        job: true,
      },
    });
    if (!assignment) {
      throw new AppError("Personnel is not assigned to this job", 404);
    }
    return assignment;
  }

  async listAssignedJobs(personnelId: string, filters: JobListFilters) {
    const jobs = await prisma.job.findMany({
      where: {
        status: filters.status,
        ...(filters.search
          ? {
              OR: [
                { title: { contains: filters.search, mode: Prisma.QueryMode.insensitive } },
                {
                  customer: {
                    name: { contains: filters.search, mode: Prisma.QueryMode.insensitive },
                  },
                },
                { notes: { contains: filters.search, mode: Prisma.QueryMode.insensitive } },
              ],
            }
          : {}),
        personnel: {
          some: { personnelId },
        },
      },
      include: {
        customer: true,
        personnel: { include: { personnel: true } },
      },
      orderBy: { scheduledAt: "asc" },
    });

    return jobs.map((job) => {
      const assignment = job.personnel.find((p) => p.personnelId === personnelId);
      const readOnly = this.isAssignmentReadOnly(assignment?.deliveredAt ?? undefined);
      return { ...job, readOnly };
    });
  }

  async getAssignedJob(personnelId: string, jobId: string) {
    const assignment = await prisma.jobPersonnel.findUnique({
      where: { jobId_personnelId: { jobId, personnelId } },
      include: {
        job: {
          include: {
            customer: true,
            materials: { include: { inventoryItem: true } },
            personnel: { include: { personnel: true } },
          },
        },
      },
    });
    if (!assignment) {
      throw new AppError("Job not found", 404);
    }
    return {
      job: assignment.job,
      assignment,
      readOnly: this.isAssignmentReadOnly(assignment.deliveredAt ?? undefined),
    };
  }

  async startJobByPersonnel(personnelId: string, jobId: string) {
    const assignment = await this.ensurePersonnelAssignment(jobId, personnelId);
    const job = await this.updateStatus(assignment.job.adminId, jobId, {
      status: JobStatus.IN_PROGRESS,
      performerType: "personnel",
      performerId: personnelId,
    });

    // Send notification to admin
    try {
      const personnel = await prisma.personnel.findUnique({
        where: { id: personnelId },
        select: { name: true },
      });
      await notificationService.sendJobStartedToAdmin(
        assignment.job.adminId,
        personnelId,
        jobId,
        job.title ?? "İş",
        personnel?.name ?? "Personel",
      );
    } catch (error) {
      logger.error("Failed to send job started notification:", error);
    }

    return job;
  }

  async deliverJobByPersonnel(personnelId: string, jobId: string, payload: DeliveryPayload) {
    const assignment = await this.ensurePersonnelAssignment(jobId, personnelId);
    if (this.isAssignmentReadOnly(assignment.deliveredAt ?? undefined)) {
      throw new AppError("Job is read-only after delivery window", 403);
    }

    return prisma.$transaction(async (tx) => {
      const adminId = assignment.job.adminId;
      const now = new Date();

      if (payload.usedMaterials?.length) {
        await tx.jobMaterial.deleteMany({ where: { jobId } });
        for (const material of payload.usedMaterials) {
          const item = await tx.inventoryItem.findFirst({
            where: { id: material.inventoryItemId, adminId },
          });
          if (!item) {
            throw new AppError("Inventory item not found", 404);
          }
          if (item.stockQty < material.quantity) {
            throw new AppError("Insufficient stock", 400);
          }
          await tx.inventoryItem.update({
            where: { id: item.id },
            data: { stockQty: item.stockQty - material.quantity },
          });
          await tx.inventoryTransaction.create({
            data: {
              inventoryItemId: item.id,
              type: InventoryTransactionType.OUTBOUND,
              quantity: material.quantity,
              jobId,
              note: "Personel teslimatı",
            },
          });
          await tx.jobMaterial.create({
            data: {
              jobId,
              inventoryItemId: item.id,
              quantity: material.quantity,
              unitPrice: item.unitPrice,
            },
          });
        }
      }

      const maintenanceDate =
        payload.maintenanceIntervalMonths && payload.maintenanceIntervalMonths > 0
          ? addMonths(now, payload.maintenanceIntervalMonths)
          : assignment.job.maintenanceDueAt;

      // Calculate payment status based on collected amount and price
      let paymentStatus: PaymentStatus | undefined = undefined;
      if (payload.collectedAmount !== undefined) {
        const collectedAmount = new Prisma.Decimal(payload.collectedAmount);
        const jobPrice = assignment.job.price;

        if (jobPrice && jobPrice.gt(0)) {
          if (collectedAmount.gte(jobPrice)) {
            paymentStatus = PaymentStatus.PAID;
          } else if (collectedAmount.gt(0)) {
            paymentStatus = PaymentStatus.PARTIAL;
          } else {
            paymentStatus = PaymentStatus.NOT_PAID;
          }
        } else if (collectedAmount.gt(0)) {
          // If no price set but amount collected, mark as PAID
          paymentStatus = PaymentStatus.PAID;
        } else {
          paymentStatus = PaymentStatus.NOT_PAID;
        }
      }

      await tx.job.update({
        where: { id: jobId },
        data: {
          collectedAmount: payload.collectedAmount
            ? new Prisma.Decimal(payload.collectedAmount)
            : undefined,
          paymentStatus: paymentStatus,
          deliveryNote: payload.note,
          deliveryMediaUrls: (payload.photoUrls ?? []) as Prisma.InputJsonValue,
          maintenanceDueAt: maintenanceDate ?? assignment.job.maintenanceDueAt,
          nextMaintenanceIntervalMonths: payload.maintenanceIntervalMonths,
          deliveredAt: now, // Personel teslim ettiği andaki saat
        },
      });

      if (maintenanceDate) {
        const reminder = await tx.maintenanceReminder.upsert({
          where: { jobId },
          update: {
            dueAt: maintenanceDate,
            status: MaintenanceStatus.PENDING,
            sentAt: null,
            lastWindowNotified: null,
            lastNotifiedAt: null,
          },
          create: {
            jobId,
            dueAt: maintenanceDate,
          },
        });
        this.emitMaintenanceUpdate(reminder, assignment.job.title ?? jobId);
      } else {
        await tx.maintenanceReminder.deleteMany({ where: { jobId } });
        realtimeGateway.emitMaintenanceReminder({
          id: null,
          jobId,
          cleared: true,
        });
      }

      await tx.jobPersonnel.update({
        where: { jobId_personnelId: { jobId, personnelId } },
        data: { deliveredAt: now },
      });

      // Update customer records based on personnel input
      const customerId = assignment.job.customerId;
      if (customerId) {
        const customer = await tx.customer.findUnique({
          where: { id: customerId },
          select: {
            remainingDebtAmount: true,
            paidDebtAmount: true,
            hasDebt: true,
          },
        });

        if (customer) {
          const customerUpdateData: Prisma.CustomerUpdateInput = {};

          // 1. If payment was collected, add to debt payment history and update remaining debt
          if (payload.collectedAmount && payload.collectedAmount > 0) {
            const collectedDecimal = new Prisma.Decimal(payload.collectedAmount);

            // Create debt payment history record
            await tx.debtPaymentHistory.create({
              data: {
                customerId,
                amount: collectedDecimal,
                paidAt: now,
              },
            });

            logger.info(
              `💰 Payment recorded: ${payload.collectedAmount} TL for customer ${customerId}`,
            );

            // Update remaining debt if customer has debt
            if (customer.hasDebt && customer.remainingDebtAmount) {
              const currentRemaining = customer.remainingDebtAmount;
              const newRemaining = currentRemaining.sub(collectedDecimal);
              const currentPaid = customer.paidDebtAmount || new Prisma.Decimal(0);
              const newPaid = currentPaid.add(collectedDecimal);

              customerUpdateData.remainingDebtAmount = newRemaining.gt(0)
                ? newRemaining
                : new Prisma.Decimal(0);
              customerUpdateData.paidDebtAmount = newPaid;

              // If all debt is paid, update hasDebt flag
              if (newRemaining.lte(0)) {
                customerUpdateData.hasDebt = false;
                customerUpdateData.remainingDebtAmount = new Prisma.Decimal(0);
              }
            }
          }

          // 2. Update customer's nextMaintenanceDate if maintenance interval was set
          if (maintenanceDate) {
            customerUpdateData.nextMaintenanceDate = maintenanceDate;
            logger.info(
              `🔧 Maintenance date updated: ${maintenanceDate.toISOString()} for customer ${customerId}`,
            );
          }

          // Apply customer updates if any
          if (Object.keys(customerUpdateData).length > 0) {
            await tx.customer.update({
              where: { id: customerId },
              data: customerUpdateData,
            });
          }
        }
      }

      const updatedJob = await this.updateStatus(
        adminId,
        jobId,
        {
          status: JobStatus.DELIVERED,
          performerType: "personnel",
          performerId: personnelId,
          note: payload.note,
        },
        tx,
      );

      // Emit customer update event to refresh customer list in admin panel
      // This ensures payment status, maintenance dates, etc. are updated in real-time
      realtimeGateway.emitToAdmin(adminId, "customer-update", {
        customerId: assignment.job.customerId,
        jobId: jobId,
      });

      return updatedJob;
    });
  }

  // Send notification after transaction completes
  async notifyJobCompleted(adminId: string, personnelId: string, jobId: string, jobTitle: string) {
    try {
      const personnel = await prisma.personnel.findUnique({
        where: { id: personnelId },
        select: { name: true },
      });
      await notificationService.sendJobCompletedToAdmin(
        adminId,
        personnelId,
        jobId,
        jobTitle,
        personnel?.name ?? "Personel",
      );
    } catch (error) {
      logger.error("Failed to send job completed notification:", error);
    }
  }

  private emitMaintenanceUpdate(
    reminder: Prisma.MaintenanceReminderGetPayload<{
      select: {
        id: true;
        jobId: true;
        dueAt: true;
        status: true;
        lastWindowNotified: true;
      };
    }>,
    jobTitle: string,
  ) {
    const daysUntilDue = Math.ceil((reminder.dueAt.getTime() - Date.now()) / MS_IN_DAY);
    realtimeGateway.emitMaintenanceReminder({
      id: reminder.id,
      jobId: reminder.jobId,
      jobTitle,
      dueAt: reminder.dueAt,
      status: reminder.status,
      daysUntilDue,
      lastWindowNotified: reminder.lastWindowNotified,
    });
  }
}

export const jobService = new JobService();
