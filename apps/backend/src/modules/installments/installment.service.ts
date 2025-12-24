import { Prisma } from "@prisma/client";
import { prisma } from "../../lib/prisma";
import { AppError } from "../../middleware/error-handler";
import { invoiceService } from "../invoices/invoice.service";

class InstallmentService {
  /**
   * Müşteri için taksitleri oluştur
   */
  async createInstallments(
    customerId: string,
    count: number,
    totalAmount: number,
    startDate: Date,
    intervalDays: number = 30,
  ) {
    // Her taksit tutarı eşit
    const installmentAmount = totalAmount / count;

    const installments = [];
    for (let i = 1; i <= count; i++) {
      // Vade tarihi: başlangıç + (interval * taksit no)
      const dueDate = new Date(startDate);
      dueDate.setDate(dueDate.getDate() + intervalDays * i);

      installments.push({
        customerId,
        installmentNo: i,
        amount: new Prisma.Decimal(installmentAmount.toFixed(2)),
        dueDate,
        isPaid: false,
      });
    }

    // Mevcut taksitleri sil ve yenilerini oluştur
    await prisma.installment.deleteMany({ where: { customerId } });
    
    await prisma.installment.createMany({
      data: installments,
    });

    return this.getInstallments(customerId);
  }

  /**
   * Müşterinin taksitlerini getir
   */
  async getInstallments(customerId: string) {
    return prisma.installment.findMany({
      where: { customerId },
      orderBy: { installmentNo: "asc" },
    });
  }

  /**
   * Taksit ödemesi yap ve fatura oluştur
   */
  async payInstallment(installmentId: string, adminId: string) {
    const installment = await prisma.installment.findUnique({
      where: { id: installmentId },
      include: {
        customer: true,
      },
    });

    if (!installment) {
      throw new AppError("Taksit bulunamadı", 404);
    }

    if (installment.isPaid) {
      throw new AppError("Bu taksit zaten ödenmiş", 400);
    }

    // Fatura oluştur
    const invoice = await invoiceService.createCustomerInvoice(adminId, {
      customerId: installment.customerId,
      customerName: installment.customer.name,
      customerPhone: installment.customer.phone,
      customerAddress: installment.customer.address,
      customerEmail: installment.customer.email || undefined,
      subtotal: Number(installment.amount),
      total: Number(installment.amount),
      notes: `Taksit ${installment.installmentNo} ödemesi`,
      invoiceDate: new Date(),
    });

    // Taksiti ödendi olarak işaretle
    const updatedInstallment = await prisma.installment.update({
      where: { id: installmentId },
      data: {
        isPaid: true,
        paidAt: new Date(),
        invoiceId: invoice.id,
      },
    });

    // Müşterinin kalan borcunu güncelle
    const customer = installment.customer;
    const newRemainingDebt = Number(customer.remainingDebtAmount || 0) - Number(installment.amount);
    const newPaidDebt = Number(customer.paidDebtAmount || 0) + Number(installment.amount);

    await prisma.customer.update({
      where: { id: installment.customerId },
      data: {
        remainingDebtAmount: new Prisma.Decimal(Math.max(0, newRemainingDebt).toFixed(2)),
        paidDebtAmount: new Prisma.Decimal(newPaidDebt.toFixed(2)),
      },
    });

    // Borç ödeme geçmişine ekle
    await prisma.debtPaymentHistory.create({
      data: {
        customerId: installment.customerId,
        amount: installment.amount,
        paidAt: new Date(),
      },
    });

    return {
      installment: updatedInstallment,
      invoice,
    };
  }

  /**
   * Belirli bir taksiti getir
   */
  async getInstallmentById(installmentId: string) {
    return prisma.installment.findUnique({
      where: { id: installmentId },
      include: { customer: true },
    });
  }
}

export const installmentService = new InstallmentService();
