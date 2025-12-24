import { Prisma } from "@prisma/client";

import { prisma } from "../../lib/prisma";
import { logger } from "../../lib/logger";
import { AppError } from "../../middleware/error-handler";
import { realtimeGateway } from "../realtime/realtime.gateway";

// Telefon numarasını normalize et (boşlukları ve özel karakterleri temizle)
function normalizePhoneNumber(phone: string): string {
  // Tüm boşlukları, tireleri, parantezleri ve diğer özel karakterleri temizle
  // Sadece rakamları ve başta + işaretini tut
  return phone.replace(/[\s\-()]/g, "");
}

type CreateCustomerPayload = {
  name: string;
  phone: string;
  email?: string;
  address: string;
  location?: Record<string, unknown>;
  status?: "ACTIVE" | "INACTIVE";
  createdAt?: string;
  hasDebt?: boolean;
  debtAmount?: number;
  hasInstallment?: boolean;
  installmentCount?: number;
  nextDebtDate?: string;
  installmentStartDate?: string;
  installmentIntervalDays?: number;
  nextMaintenanceDate?: string | null;
  receivedAmount?: number;
  paymentDate?: string;
};

type UpdateCustomerPayload = Partial<CreateCustomerPayload> & {
  remainingDebtAmount?: number;
  nextMaintenanceDate?: string | null;
  receivedAmount?: number;
  paymentDate?: string;
};

type CustomerListFilters = {
  search?: string;
  phoneSearch?: string;
  createdAtFrom?: Date;
  createdAtTo?: Date;
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
        debtPaymentHistory: {
          orderBy: { paidAt: "desc" },
        },
        receivedAmountHistory: {
          orderBy: { receivedAt: "desc" },
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
      const normalizedSearch = normalizePhoneNumber(filters.search);
      where.OR = [
        { name: { startsWith: filters.search, mode: Prisma.QueryMode.insensitive } },
        { phone: { contains: normalizedSearch, mode: Prisma.QueryMode.insensitive } },
        { address: { contains: filters.search, mode: Prisma.QueryMode.insensitive } },
      ];
    }

    // Telefon numarasına göre arama (içerir - doğru sırada)
    if (filters.phoneSearch) {
      // Telefon numarasında doğru sırada içeren arama
      // Örneğin "2324" yazıldığında sonu "2324" olan veya içinde "2324" geçen numaralar bulunur
      // Boşluklu veya boşluksuz yazım fark etmez
      const normalizedPhoneSearch = normalizePhoneNumber(filters.phoneSearch);
      where.phone = { contains: normalizedPhoneSearch, mode: Prisma.QueryMode.insensitive };
    }

    // Tarih filtreleme
    if (filters.createdAtFrom || filters.createdAtTo) {
      where.createdAt = {};
      if (filters.createdAtFrom) {
        where.createdAt.gte = filters.createdAtFrom;
      }
      if (filters.createdAtTo) {
        // Tarihin sonuna kadar (23:59:59)
        const endOfDay = new Date(filters.createdAtTo);
        endOfDay.setHours(23, 59, 59, 999);
        where.createdAt.lte = endOfDay;
      }
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
        const now = new Date();
        // Bugünün tarihini sıfırla (sadece tarih karşılaştırması için)
        const today = new Date(now);
        today.setHours(0, 0, 0, 0);

        // 1. Borç ödeme tarihi geçmiş müşteriler
        // hasDebt = true ve nextDebtDate var ve nextDebtDate <= bugün (bugün dahil)
        let hasOverdueDebtDate = false;
        if (customer.hasDebt && customer.nextDebtDate) {
          const debtDate = new Date(customer.nextDebtDate);
          debtDate.setHours(0, 0, 0, 0);
          // Bugün dahil geçmiş tarihleri kontrol et
          hasOverdueDebtDate = debtDate <= today;
        }

        // 2. Borç durumu "Ödeme gecikmiş" olan müşteriler
        // hasDebt = true ve remainingDebtAmount > 0 ve nextDebtDate geçmiş
        // (Frontend'de "Ödeme gecikmiş" durumu: remainingDebtAmount > 0 ve nextDebtDate geçmiş)
        let hasOverdueDebtStatus = false;
        if (
          customer.hasDebt &&
          customer.remainingDebtAmount &&
          Number(customer.remainingDebtAmount) > 0
        ) {
          // Eğer nextDebtDate var ve geçmişse, borç durumu "Ödeme gecikmiş"
          if (customer.nextDebtDate) {
            const debtDate = new Date(customer.nextDebtDate);
            debtDate.setHours(0, 0, 0, 0);
            if (debtDate <= today) {
              hasOverdueDebtStatus = true;
            }
          }
          // Eğer nextDebtDate yoksa ama kalan borç varsa, yine de "Ödeme gecikmiş" sayılabilir
          // (Bu durumda borç durumu "Ödeme gecikmiş" olabilir)
          else {
            hasOverdueDebtStatus = true;
          }
        }

        // 3. Taksit ödeme tarihi geçmiş müşteriler
        // hasInstallment = true ve taksit tekrar günü geçmiş
        let hasOverdueInstallment = false;
        if (
          customer.hasInstallment &&
          customer.installmentStartDate &&
          customer.installmentIntervalDays &&
          customer.installmentIntervalDays > 0
        ) {
          const startDate = new Date(customer.installmentStartDate);
          startDate.setHours(0, 0, 0, 0);
          const intervalDays = customer.installmentIntervalDays;

          // Başlangıç tarihinden bu yana geçen gün sayısı
          const daysSinceStart = Math.floor(
            (today.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24),
          );

          // Eğer başlangıç tarihi bugünden önceyse ve en az bir taksit aralığı geçtiyse kontrol et
          if (daysSinceStart > 0 && daysSinceStart >= intervalDays) {
            // Kaç taksit geçti (tam sayı)
            const installmentsPassed = Math.floor(daysSinceStart / intervalDays);

            if (installmentsPassed > 0) {
              // Son taksit ödeme tarihini hesapla
              // Örnek: Başlangıç: 1 Ocak, Aralık: 30 gün, Bugün: 15 Şubat (45 gün geçmiş)
              // installmentsPassed = 1, Son taksit tarihi = 1 Ocak + 30 gün = 31 Ocak
              const lastInstallmentDate = new Date(startDate);
              lastInstallmentDate.setDate(
                lastInstallmentDate.getDate() + installmentsPassed * intervalDays,
              );
              lastInstallmentDate.setHours(0, 0, 0, 0);

              // Son taksit tarihi bugünden önce veya bugüne eşitse, ödeme gecikmiş
              hasOverdueInstallment = lastInstallmentDate <= today;
            }
          }
        }

        // 4. Job'lardaki ödenmemiş borçlar - artık "Ödemesi Gelen" filtresine dahil değil
        // Sadece borç tarihi geçmiş müşteriler gösterilecek
        // hasUnpaidJob kontrolü kaldırıldı

        // Sonuç: Borç ödeme tarihi geçmiş, borç durumu "Ödeme gecikmiş" veya taksit ödeme tarihi geçmiş müşteriler
        const result = hasOverdueDebtDate || hasOverdueDebtStatus || hasOverdueInstallment;

        // Debug log (tüm müşteriler için - sorun tespiti için)
        if (
          customer.hasDebt ||
          customer.hasInstallment
        ) {
          console.log(`[OverduePayment] Customer ${customer.id} (${customer.name}):`, {
            hasDebt: customer.hasDebt,
            nextDebtDate: customer.nextDebtDate,
            remainingDebtAmount: customer.remainingDebtAmount,
            hasOverdueDebtDate,
            hasOverdueDebtStatus,
            hasInstallment: customer.hasInstallment,
            installmentStartDate: customer.installmentStartDate,
            installmentIntervalDays: customer.installmentIntervalDays,
            hasOverdueInstallment,
            result,
            today: today.toISOString(),
          });
        }

        return result;
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
    const installmentIntervalDays = payload.installmentIntervalDays ?? null;

    // Parse dates
    const createdAt = payload.createdAt ? new Date(payload.createdAt) : new Date();
    const nextDebtDate = payload.nextDebtDate ? new Date(payload.nextDebtDate) : null;
    const installmentStartDate = payload.installmentStartDate
      ? new Date(payload.installmentStartDate)
      : null;
    const nextMaintenanceDate = payload.nextMaintenanceDate
      ? new Date(payload.nextMaintenanceDate)
      : null;
    const paymentDate = payload.paymentDate ? new Date(payload.paymentDate) : null;
    const receivedAmount = payload.receivedAmount
      ? new Prisma.Decimal(payload.receivedAmount)
      : null;

    // Calculate remaining debt amount
    let remainingDebtAmount: Prisma.Decimal | null = null;

    if (hasDebt && debtAmount) {
      // Remaining debt is total debt minus paid amount (initially 0)
      remainingDebtAmount = debtAmount;
    }

    return prisma.customer.create({
      data: {
        adminId,
        name: payload.name,
        phone: normalizePhoneNumber(payload.phone),
        email: payload.email,
        address: payload.address,
        location: payload.location as Prisma.InputJsonValue,
        status: payload.status ?? "ACTIVE",
        createdAt,
        hasDebt,
        debtAmount,
        hasInstallment,
        installmentCount,
        nextDebtDate,
        installmentStartDate,
        installmentIntervalDays,
        remainingDebtAmount,
        nextMaintenanceDate,
        receivedAmount,
        paymentDate,
      },
    });
  }

  async update(adminId: string, customerId: string, payload: UpdateCustomerPayload) {
    const existing = await this.ensureCustomer(adminId, customerId);

    const updateData: Prisma.CustomerUpdateInput = {};

    // Only set fields that are explicitly provided (not undefined)
    if (payload.name !== undefined) {
      updateData.name = payload.name;
    }
    if (payload.phone !== undefined) {
      // Prisma doesn't accept null for string fields, use undefined or set to empty string
      updateData.phone = payload.phone ? normalizePhoneNumber(payload.phone) : undefined;
    }
    if (payload.email !== undefined) {
      // Prisma accepts null for optional fields
      updateData.email = payload.email === "" ? null : payload.email;
    }
    if (payload.address !== undefined) {
      updateData.address = payload.address;
    }
    if (payload.location !== undefined) {
      updateData.location = payload.location as Prisma.InputJsonValue;
    }

    if (payload.status !== undefined) {
      updateData.status = payload.status;
    }

    // Handle receivedAmount and paymentDate
    // Eğer receivedAmount değiştiyse, geçmişe kaydet
    if (payload.receivedAmount !== undefined) {
      const newReceivedAmount = payload.receivedAmount
        ? new Prisma.Decimal(payload.receivedAmount)
        : null;
      const existingReceivedAmount = existing.receivedAmount;

      // Sadece değer değiştiyse geçmişe kaydet
      if (
        newReceivedAmount &&
        (!existingReceivedAmount || !newReceivedAmount.equals(existingReceivedAmount))
      ) {
        // Geçmişe kaydet (transaction içinde)
        // Bu işlem update ile birlikte yapılacak
        updateData.receivedAmount = newReceivedAmount;
        updateData.paymentDate = payload.paymentDate ? new Date(payload.paymentDate) : new Date();
      } else {
        updateData.receivedAmount = newReceivedAmount;
      }
    }
    if (payload.paymentDate !== undefined && payload.receivedAmount === undefined) {
      updateData.paymentDate = payload.paymentDate ? new Date(payload.paymentDate) : null;
    }

    // Handle debt fields
    const hasDebt = payload.hasDebt ?? existing.hasDebt;
    const debtAmount =
      payload.debtAmount !== undefined
        ? payload.debtAmount
          ? new Prisma.Decimal(payload.debtAmount)
          : null
        : existing.debtAmount;
    const hasInstallment = payload.hasInstallment ?? existing.hasInstallment;
    const installmentCount = payload.installmentCount ?? existing.installmentCount;

    // Parse dates
    if (payload.nextDebtDate !== undefined) {
      updateData.nextDebtDate = payload.nextDebtDate ? new Date(payload.nextDebtDate) : null;
    }
    if (payload.installmentStartDate !== undefined) {
      updateData.installmentStartDate = payload.installmentStartDate
        ? new Date(payload.installmentStartDate)
        : null;
    }
    if (payload.installmentIntervalDays !== undefined) {
      updateData.installmentIntervalDays = payload.installmentIntervalDays;
    }

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

    // Update maintenance date for customer and jobs if provided
    // Production'da da görünmesi için console.log kullanıyoruz
    console.log("🔵 Backend Service - payload.nextMaintenanceDate:", payload.nextMaintenanceDate);
    console.log(
      "🔵 Backend Service - payload.nextMaintenanceDate !== undefined:",
      payload.nextMaintenanceDate !== undefined,
    );
    if (payload.nextMaintenanceDate !== undefined) {
      const maintenanceDate = payload.nextMaintenanceDate
        ? new Date(payload.nextMaintenanceDate)
        : null;

      console.log("🔵 Backend Service - maintenanceDate:", maintenanceDate);
      console.log(
        "🔵 Backend Service - updateData.nextMaintenanceDate set ediliyor:",
        maintenanceDate,
      );

      // Update customer's nextMaintenanceDate field
      updateData.nextMaintenanceDate = maintenanceDate;

      // Also update the customer's nearest job if maintenance date is provided
      if (maintenanceDate) {
        // Find the customer's nearest job (by maintenanceDueAt)
        const customerJobs = await prisma.job.findMany({
          where: {
            customerId,
            adminId,
            status: { not: "ARCHIVED" },
          },
          orderBy: {
            maintenanceDueAt: "asc",
          },
          take: 1,
        });

        if (customerJobs.length > 0) {
          // Update the nearest job's maintenance date
          const updatedJob = await prisma.job.update({
            where: { id: customerJobs[0].id },
            data: { maintenanceDueAt: maintenanceDate },
          });

          // Update or create maintenance reminder
          await prisma.maintenanceReminder.upsert({
            where: { jobId: customerJobs[0].id },
            update: { dueAt: maintenanceDate },
            create: {
              jobId: customerJobs[0].id,
              dueAt: maintenanceDate,
            },
          });

          // Emit real-time events
          realtimeGateway.emitJobStatus(customerJobs[0].id, updatedJob);
          realtimeGateway.emitToAdmin(adminId, "customer-update", {
            customerId,
          });
        }
      } else {
        // If maintenance date is null, also clear job maintenance dates
        const customerJobs = await prisma.job.findMany({
          where: {
            customerId,
            adminId,
            status: { not: "ARCHIVED" },
          },
        });

        for (const job of customerJobs) {
          await prisma.job.update({
            where: { id: job.id },
            data: { maintenanceDueAt: null },
          });
          // Delete maintenance reminders for this job
          await prisma.maintenanceReminder.deleteMany({
            where: { jobId: job.id },
          });
        }
      }
    }

    console.log(
      "🔵 Backend Service - updateData.nextMaintenanceDate:",
      updateData.nextMaintenanceDate,
    );
    console.log("🔵 Backend Service - updateData (full):", JSON.stringify(updateData, null, 2));

    // Eğer receivedAmount değiştiyse, geçmişe kaydet
    const shouldAddHistory =
      payload.receivedAmount !== undefined &&
      payload.receivedAmount !== null &&
      (!existing.receivedAmount ||
        !new Prisma.Decimal(payload.receivedAmount).equals(existing.receivedAmount));

    const updatedCustomer = await prisma.$transaction(async (tx) => {
      const updated = await tx.customer.update({
        where: { id: customerId },
        data: updateData,
        include: {
          debtPaymentHistory: true,
          receivedAmountHistory: true,
        },
      });

      // Eğer receivedAmount değiştiyse, geçmişe kaydet
      if (shouldAddHistory && payload.receivedAmount) {
        await tx.receivedAmountHistory.create({
          data: {
            customerId,
            amount: new Prisma.Decimal(payload.receivedAmount),
            receivedAt: payload.paymentDate ? new Date(payload.paymentDate) : new Date(),
          },
        });
        // Geçmişi tekrar yükle
        const reloaded = await tx.customer.findUnique({
          where: { id: customerId },
          include: {
            debtPaymentHistory: true,
            receivedAmountHistory: {
              orderBy: { receivedAt: "desc" },
            },
          },
        });
        if (!reloaded) {
          throw new AppError("Customer not found after update", 404);
        }
        return reloaded;
      }

      return updated;
    });

    if (!updatedCustomer) {
      throw new AppError("Customer not found after update", 404);
    }

    console.log(
      "🔵 Backend Service - updatedCustomer.nextMaintenanceDate:",
      updatedCustomer.nextMaintenanceDate,
    );
    console.log(
      "🔵 Backend Service - updatedCustomer (full):",
      JSON.stringify(
        {
          id: updatedCustomer.id,
          name: updatedCustomer.name,
          nextMaintenanceDate: updatedCustomer.nextMaintenanceDate,
        },
        null,
        2,
      ),
    );

    // Emit customer update event
    realtimeGateway.emitToAdmin(adminId, "customer-update", {
      customerId,
    });

    return updatedCustomer;
  }

  async markInstallmentOverdue(adminId: string, customerId: string) {
    const customer = await this.ensureCustomer(adminId, customerId);

    if (
      !customer.hasInstallment ||
      !customer.installmentStartDate ||
      !customer.installmentIntervalDays
    ) {
      throw new AppError("Customer does not have installment plan", 400);
    }

    const now = new Date();
    const intervalDays = customer.installmentIntervalDays;

    // Taksit başlangıç tarihini geçmiş bir tarihe ayarla
    // En az bir taksit aralığı geçmiş olacak şekilde ayarla
    const overdueStartDate = new Date(now);
    overdueStartDate.setDate(overdueStartDate.getDate() - (intervalDays + 1)); // En az 1 gün daha geçmiş

    // nextDebtDate'i de geçmiş bir tarihe ayarla
    const overdueNextDebtDate = new Date(overdueStartDate);
    overdueNextDebtDate.setDate(overdueNextDebtDate.getDate() + intervalDays);

    return prisma.customer.update({
      where: { id: customerId },
      data: {
        installmentStartDate: overdueStartDate,
        nextDebtDate: overdueNextDebtDate,
      },
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
    let updatedInstallmentCount =
      installmentCount !== undefined ? installmentCount : customer.installmentCount;
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

    // Record payment history
    return prisma.$transaction(async (tx) => {
      // Create payment history record
      const newPayment = await tx.debtPaymentHistory.create({
        data: {
          customerId,
          amount: paymentAmount,
          paidAt: new Date(),
        },
      });

      console.log("🔵 Backend payDebt - Yeni ödeme kaydı oluşturuldu:");
      console.log(`   - id: ${newPayment.id}`);
      console.log(`   - amount: ${newPayment.amount}`);
      console.log(`   - paidAt: ${newPayment.paidAt}`);

      // Update customer
      const updatedCustomer = await tx.customer.update({
        where: { id: customerId },
        data: {
          paidDebtAmount: newPaid,
          remainingDebtAmount: finalRemaining,
          hasDebt,
          nextDebtDate,
          installmentCount: updatedInstallmentCount,
        },
        include: {
          debtPaymentHistory: {
            orderBy: { paidAt: "desc" },
          },
        },
      });

      console.log("🟢 Backend payDebt - Güncellenmiş customer:");
      console.log(
        `   - debtPaymentHistory: ${updatedCustomer.debtPaymentHistory?.length ?? 0} adet`,
      );
      if (updatedCustomer.debtPaymentHistory && updatedCustomer.debtPaymentHistory.length > 0) {
        for (const payment of updatedCustomer.debtPaymentHistory) {
          console.log(`   - ${payment.amount} TL - ${payment.paidAt}`);
        }
      }

      return updatedCustomer;
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
