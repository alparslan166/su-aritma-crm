import { Prisma } from "@prisma/client";

import { prisma } from "@/lib/prisma";
import { AppError } from "@/middleware/error-handler";

type CreateCustomerPayload = {
  name: string;
  phone: string;
  email?: string;
  address: string;
  location?: Record<string, unknown>;
  hasDebt?: boolean;
  debtAmount?: number;
  hasInstallment?: boolean;
  installmentCount?: number;
};

type UpdateCustomerPayload = Partial<CreateCustomerPayload> & {
  remainingDebtAmount?: number;
};

type CustomerListFilters = {
  search?: string;
  hasOverduePayment?: boolean;
  hasUpcomingMaintenance?: boolean;
  hasOverdueInstallment?: boolean;
};

class CustomerService {
  private async ensureCustomer(adminId: string, customerId: string) {
    const customer = await prisma.customer.findFirst({
      where: { id: customerId, adminId },
      include: {
        jobs: {
          include: {
            maintenanceReminders: true,
          },
        },
      },
    });
    if (!customer) {
      throw new AppError("Customer not found", 404);
    }
    return customer;
  }

  async list(adminId: string, filters: CustomerListFilters) {
    const where: Prisma.CustomerWhereInput = {
      adminId,
    };

    if (filters.search) {
      // Kelime kelime duyarlı arama - isim ile başlayanlar
      where.OR = [
        { name: { startsWith: filters.search, mode: Prisma.QueryMode.insensitive } },
        { phone: { contains: filters.search, mode: Prisma.QueryMode.insensitive } },
        { address: { contains: filters.search, mode: Prisma.QueryMode.insensitive } },
      ];
    }

    const customers = await prisma.customer.findMany({
      where,
      include: {
        jobs: {
          where: {
            status: { not: "ARCHIVED" },
          },
          include: {
            maintenanceReminders: true,
          },
          orderBy: { createdAt: "desc" },
        },
      },
      orderBy: { createdAt: "desc" },
    });

    // Filter customers based on payment and maintenance status
    let filtered = customers;
    if (filters.hasOverduePayment) {
      filtered = filtered.filter((customer) => {
        // Check job payments
        const hasOverdueJobPayment = customer.jobs.some((job) => {
          if (!job.price || !job.collectedAmount) return false;
          const totalPrice = Number(job.price);
          const collected = Number(job.collectedAmount);
          const remaining = totalPrice - collected;
          return remaining > 0 && job.paymentStatus === "NOT_PAID";
        });
        
        // Check installment payment due date - if taksit ödeme tarihi geldiyse "ödemesi gelenler" filtresine dahil et
        const hasOverdueInstallment = customer.hasDebt && 
          customer.hasInstallment && 
          customer.nextDebtDate && 
          customer.nextDebtDate < new Date();
        
        return hasOverdueJobPayment || hasOverdueInstallment;
      });
    }

    if (filters.hasUpcomingMaintenance) {
      filtered = filtered.filter((customer) => {
        return customer.jobs.some((job) => {
          if (!job.maintenanceReminders.length) return false;
          const reminder = job.maintenanceReminders[0];
          const daysUntilDue = Math.ceil(
            (reminder.dueAt.getTime() - Date.now()) / (1000 * 60 * 60 * 24),
          );
          // Geçmiş veya 30 gün içinde olan bakımlar (geçmiş olanlar da dahil)
          return daysUntilDue <= 30;
        });
      });
    }

    if (filters.hasOverdueInstallment) {
      filtered = filtered.filter((customer) => {
        if (!customer.hasDebt || !customer.hasInstallment || !customer.nextDebtDate) {
          return false;
        }
        // Check if next debt date has passed
        return customer.nextDebtDate < new Date();
      });
    }

    return filtered;
  }

  async getById(adminId: string, customerId: string) {
    return this.ensureCustomer(adminId, customerId);
  }

  async create(adminId: string, payload: CreateCustomerPayload) {
    const hasDebt = payload.hasDebt ?? false;
    const debtAmount = payload.debtAmount ? new Prisma.Decimal(payload.debtAmount) : null;
    const hasInstallment = payload.hasInstallment ?? false;
    const installmentCount = payload.installmentCount ?? null;
    
    // Calculate next debt date and remaining debt amount
    let nextDebtDate: Date | null = null;
    let remainingDebtAmount: Prisma.Decimal | null = null;
    
    if (hasDebt && debtAmount) {
      // Remaining debt is total debt minus paid amount (initially 0)
      remainingDebtAmount = debtAmount;
      
      if (hasInstallment && installmentCount && installmentCount > 0) {
        // Next debt date is 1 month from now
        nextDebtDate = new Date();
        nextDebtDate.setMonth(nextDebtDate.getMonth() + 1);
      }
    }
    
    return prisma.customer.create({
      data: {
        adminId,
        name: payload.name,
        phone: payload.phone,
        email: payload.email,
        address: payload.address,
        location: payload.location as Prisma.InputJsonValue,
        hasDebt,
        debtAmount,
        hasInstallment,
        installmentCount,
        nextDebtDate,
        remainingDebtAmount,
      },
    });
  }

  async update(adminId: string, customerId: string, payload: UpdateCustomerPayload) {
    const existing = await this.ensureCustomer(adminId, customerId);
    
    const updateData: Prisma.CustomerUpdateInput = {
      name: payload.name,
      phone: payload.phone,
      email: payload.email,
      address: payload.address,
      location: payload.location as Prisma.InputJsonValue | undefined,
    };
    
    // Handle debt fields
    const hasDebt = payload.hasDebt ?? existing.hasDebt;
    const debtAmount = payload.debtAmount !== undefined 
      ? (payload.debtAmount ? new Prisma.Decimal(payload.debtAmount) : null)
      : existing.debtAmount;
    const hasInstallment = payload.hasInstallment ?? existing.hasInstallment;
    const installmentCount = payload.installmentCount ?? existing.installmentCount;
    
    if (payload.hasDebt !== undefined) {
      updateData.hasDebt = payload.hasDebt;
    }
    
    if (payload.debtAmount !== undefined) {
      updateData.debtAmount = payload.debtAmount ? new Prisma.Decimal(payload.debtAmount) : null;
    }
    
    if (payload.hasInstallment !== undefined) {
      updateData.hasInstallment = payload.hasInstallment;
    }
    
    if (payload.installmentCount !== undefined) {
      updateData.installmentCount = payload.installmentCount;
    }
    
    // Handle remainingDebtAmount - can be updated directly
    if (payload.remainingDebtAmount !== undefined) {
      updateData.remainingDebtAmount = payload.remainingDebtAmount 
        ? new Prisma.Decimal(payload.remainingDebtAmount) 
        : null;
      
      // Recalculate paidDebtAmount based on new remainingDebtAmount
      if (hasDebt && debtAmount && payload.remainingDebtAmount !== null) {
        const newRemaining = new Prisma.Decimal(payload.remainingDebtAmount);
        const totalDebt = debtAmount;
        const newPaid = totalDebt.sub(newRemaining);
        updateData.paidDebtAmount = newPaid.gt(0) ? newPaid : new Prisma.Decimal(0);
        
        // Update installment count if has installment
        if (hasInstallment && installmentCount && installmentCount > 0) {
          const installmentAmount = totalDebt.div(installmentCount);
          const paidInstallments = Math.floor(Number(newPaid) / Number(installmentAmount));
          const remainingInstallments = installmentCount - paidInstallments;
          updateData.installmentCount = remainingInstallments > 0 ? remainingInstallments : null;
          
          // Update next debt date
          if (remainingInstallments > 0) {
            const nextDate = new Date();
            nextDate.setMonth(nextDate.getMonth() + 1);
            updateData.nextDebtDate = nextDate;
          } else {
            updateData.nextDebtDate = null;
          }
        }
      }
    }
    
    // Recalculate next debt date and remaining debt amount if debtAmount changed
    if (hasDebt && debtAmount && payload.debtAmount !== undefined) {
      // If remainingDebtAmount was not explicitly set, add new debt to existing remaining
      if (payload.remainingDebtAmount === undefined) {
        const existingRemaining = existing.remainingDebtAmount || new Prisma.Decimal(0);
        const existingDebt = existing.debtAmount || new Prisma.Decimal(0);
        const newDebtAmount = debtAmount.sub(existingDebt);
        // Add new debt to existing remaining debt
        const newRemaining = existingRemaining.add(newDebtAmount);
        updateData.remainingDebtAmount = newRemaining.gt(0) ? newRemaining : new Prisma.Decimal(0);
      }
      
      if (hasInstallment && installmentCount && installmentCount > 0) {
        const nextDate = new Date();
        nextDate.setMonth(nextDate.getMonth() + 1);
        updateData.nextDebtDate = nextDate;
      } else {
        updateData.nextDebtDate = null;
      }
    } else if (hasDebt === false) {
      updateData.debtAmount = null;
      updateData.hasInstallment = false;
      updateData.installmentCount = null;
      updateData.nextDebtDate = null;
      updateData.remainingDebtAmount = null;
      updateData.paidDebtAmount = null;
    }
    
    return prisma.customer.update({
      where: { id: customerId },
      data: updateData,
    });
  }

  async payDebt(adminId: string, customerId: string, amount: number, installmentCount?: number) {
    const customer = await this.ensureCustomer(adminId, customerId);
    
    if (!customer.hasDebt || !customer.remainingDebtAmount) {
      throw new AppError("Customer has no debt to pay", 400);
    }

    const paymentAmount = new Prisma.Decimal(amount);
    const currentPaid = customer.paidDebtAmount || new Prisma.Decimal(0);
    const currentRemaining = customer.remainingDebtAmount;
    
    // Ensure payment doesn't exceed remaining debt
    if (paymentAmount.gt(currentRemaining)) {
      throw new AppError("Payment amount cannot exceed remaining debt", 400);
    }
    
    const newPaid = currentPaid.add(paymentAmount);
    const newRemaining = currentRemaining.sub(paymentAmount);

    // If remaining debt becomes 0 or negative, mark as no debt
    const hasDebt = newRemaining.gt(0);
    const finalRemaining = hasDebt ? newRemaining : new Prisma.Decimal(0);
    
    // Use manual installment count if provided, otherwise keep existing
    let updatedInstallmentCount = installmentCount !== undefined ? installmentCount : customer.installmentCount;
    let nextDebtDate = customer.nextDebtDate;
    
    if (customer.hasInstallment && updatedInstallmentCount && updatedInstallmentCount > 0) {
      if (hasDebt) {
        // Next debt date is 1 month from now
        nextDebtDate = new Date();
        nextDebtDate.setMonth(nextDebtDate.getMonth() + 1);
      } else {
        // All debt paid, no more installments
        updatedInstallmentCount = null;
        nextDebtDate = null;
      }
    } else if (!hasDebt) {
      nextDebtDate = null;
      updatedInstallmentCount = null;
    }

    return prisma.customer.update({
      where: { id: customerId },
      data: {
        paidDebtAmount: newPaid,
        remainingDebtAmount: finalRemaining,
        hasDebt,
        nextDebtDate,
        installmentCount: updatedInstallmentCount,
      },
    });
  }

  async delete(adminId: string, customerId: string) {
    await this.ensureCustomer(adminId, customerId);
    // Check if customer has active jobs
    const activeJobs = await prisma.job.count({
      where: {
        customerId,
        adminId,
        status: { not: "ARCHIVED" },
      },
    });
    if (activeJobs > 0) {
      throw new AppError("Cannot delete customer with active jobs", 400);
    }
    await prisma.customer.delete({ where: { id: customerId } });
  }
}

export const customerService = new CustomerService();

