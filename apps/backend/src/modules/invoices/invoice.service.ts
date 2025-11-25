import { Prisma } from "@prisma/client";

import { prisma } from "@/lib/prisma";
import { AppError } from "@/middleware/error-handler";
import { jobService } from "@/modules/jobs/job.service";

type CreateInvoicePayload = {
  jobId: string;
  invoiceNumber?: string;
  subtotal?: number;
  tax?: number;
  total?: number;
  notes?: string;
};

type UpdateInvoicePayload = {
  customerName?: string;
  customerPhone?: string;
  customerAddress?: string;
  customerEmail?: string;
  jobTitle?: string;
  jobDate?: Date;
  subtotal?: number;
  tax?: number;
  total?: number;
  notes?: string;
  isDraft?: boolean;
};

class InvoiceService {
  private async ensureInvoice(adminId: string, invoiceId: string) {
    const invoice = await prisma.invoice.findFirst({
      where: { id: invoiceId, adminId },
      include: {
        job: {
          include: {
            customer: true,
            materials: {
              include: {
                inventoryItem: true,
              },
            },
          },
        },
      },
    });
    if (!invoice) {
      throw new AppError("Invoice not found", 404);
    }
    return invoice;
  }

  private generateInvoiceNumber(adminId: string): string {
    const timestamp = Date.now();
    const random = Math.floor(Math.random() * 1000);
    return `INV-${adminId.slice(0, 6).toUpperCase()}-${timestamp}-${random}`;
  }

  async createDraft(adminId: string, payload: CreateInvoicePayload) {
    // Get job details with all necessary fields
    const job = await prisma.job.findFirst({
      where: { id: payload.jobId, adminId },
      include: {
        customer: true,
      },
    });
    if (!job) {
      throw new AppError("Job not found", 404);
    }

    // Check if job is delivered
    if (job.status !== "DELIVERED") {
      throw new AppError("Invoice can only be created for delivered jobs", 400);
    }

    // Check if invoice already exists
    if (job.invoiceId) {
      throw new AppError("Invoice already exists for this job", 400);
    }

    // Calculate totals if not provided
    const subtotal = payload.subtotal ?? Number(job.price ?? 0);
    const tax = payload.tax ?? 0;
    const total = payload.total ?? subtotal + tax;

    // Get job date (deliveredAt or scheduledAt or createdAt)
    const jobDate = job.deliveredAt ?? job.scheduledAt ?? job.createdAt ?? new Date();

    // Create invoice
    const invoice = await prisma.invoice.create({
      data: {
        adminId,
        jobId: payload.jobId,
        invoiceNumber: payload.invoiceNumber ?? this.generateInvoiceNumber(adminId),
        customerName: job.customer.name,
        customerPhone: job.customer.phone,
        customerAddress: job.customer.address,
        customerEmail: job.customer.email ?? undefined,
        jobTitle: job.title,
        jobDate,
        subtotal: new Prisma.Decimal(subtotal),
        tax: tax > 0 ? new Prisma.Decimal(tax) : null,
        total: new Prisma.Decimal(total),
        notes: payload.notes,
        isDraft: true,
      },
    });

    // Update job with invoice ID
    await prisma.job.update({
      where: { id: payload.jobId },
      data: { invoiceId: invoice.id },
    });

    return invoice;
  }

  async update(adminId: string, invoiceId: string, payload: UpdateInvoicePayload) {
    await this.ensureInvoice(adminId, invoiceId);

    const updateData: Prisma.InvoiceUpdateInput = {};

    if (payload.customerName !== undefined) {
      updateData.customerName = payload.customerName;
    }
    if (payload.customerPhone !== undefined) {
      updateData.customerPhone = payload.customerPhone;
    }
    if (payload.customerAddress !== undefined) {
      updateData.customerAddress = payload.customerAddress;
    }
    if (payload.customerEmail !== undefined) {
      updateData.customerEmail = payload.customerEmail;
    }
    if (payload.jobTitle !== undefined) {
      updateData.jobTitle = payload.jobTitle;
    }
    if (payload.jobDate !== undefined) {
      updateData.jobDate = payload.jobDate;
    }
    if (payload.subtotal !== undefined) {
      updateData.subtotal = new Prisma.Decimal(payload.subtotal);
    }
    if (payload.tax !== undefined) {
      updateData.tax = payload.tax > 0 ? new Prisma.Decimal(payload.tax) : null;
    }
    if (payload.total !== undefined) {
      updateData.total = new Prisma.Decimal(payload.total);
    }
    if (payload.notes !== undefined) {
      updateData.notes = payload.notes;
    }
    if (payload.isDraft !== undefined) {
      updateData.isDraft = payload.isDraft;
    }

    return prisma.invoice.update({
      where: { id: invoiceId },
      data: updateData,
      include: {
        job: {
          include: {
            customer: true,
            materials: {
              include: {
                inventoryItem: true,
              },
            },
          },
        },
      },
    });
  }

  async getById(adminId: string, invoiceId: string) {
    return this.ensureInvoice(adminId, invoiceId);
  }

  async list(adminId: string) {
    return prisma.invoice.findMany({
      where: { adminId },
      include: {
        job: {
          include: {
            customer: true,
          },
        },
      },
      orderBy: { createdAt: "desc" },
    });
  }

  async delete(adminId: string, invoiceId: string) {
    const invoice = await this.ensureInvoice(adminId, invoiceId);

    // Remove invoice ID from job
    if (invoice.jobId) {
      await prisma.job.update({
        where: { id: invoice.jobId },
        data: { invoiceId: null },
      });
    }

    // Delete invoice
    await prisma.invoice.delete({
      where: { id: invoiceId },
    });
  }

  async getInvoiceForPdf(adminId: string, invoiceId: string) {
    const invoice = await this.ensureInvoice(adminId, invoiceId);

    // Get materials if job exists - fetch job separately to ensure materials are included
    let materials: Array<{
      name: string;
      quantity: number;
      unitPrice: number;
      total: number;
    }> = [];

    if (invoice.jobId) {
      try {
        const job = await jobService.getById(adminId, invoice.jobId);
        if (job && (job as any).materials) {
          const jobMaterials = (job as any).materials || [];
          materials = jobMaterials.map((material: any) => ({
            name: material.inventoryItem?.name || "Bilinmeyen Malzeme",
            quantity: material.quantity || 0,
            unitPrice: Number(material.unitPrice || 0),
            total: (material.quantity || 0) * Number(material.unitPrice || 0),
          }));
        }
      } catch (error) {
        // If job fetch fails, continue without materials
        console.error("Failed to fetch job materials:", error);
      }
    }

    return {
      invoiceNumber: invoice.invoiceNumber,
      customerName: invoice.customerName,
      customerPhone: invoice.customerPhone,
      customerAddress: invoice.customerAddress,
      customerEmail: invoice.customerEmail,
      jobTitle: invoice.jobTitle,
      jobDate: invoice.jobDate,
      subtotal: Number(invoice.subtotal),
      tax: invoice.tax ? Number(invoice.tax) : null,
      total: Number(invoice.total),
      notes: invoice.notes,
      materials,
      createdAt: invoice.createdAt,
    };
  }

  async createAndGeneratePdf(adminId: string, jobId: string) {
    // Check if invoice already exists
    const job = await jobService.getById(adminId, jobId);
    if (!job) {
      throw new AppError("Job not found", 404);
    }

    if (job.status !== "DELIVERED") {
      throw new AppError("Invoice can only be created for delivered jobs", 400);
    }

    let invoice;
    if (job.invoiceId) {
      // Invoice already exists, get it with job and materials
      invoice = await this.getById(adminId, job.invoiceId);
    } else {
      // Create new invoice
      invoice = await this.createDraft(adminId, {
        jobId,
      });
      // Fetch invoice again with job and materials included
      invoice = await this.getById(adminId, invoice.id);
    }

    // Get invoice data for PDF
    return this.getInvoiceForPdf(adminId, invoice.id);
  }
}

export const invoiceService = new InvoiceService();

