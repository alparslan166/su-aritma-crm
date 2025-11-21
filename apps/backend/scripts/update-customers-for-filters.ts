import { PrismaClient } from "@prisma/client";

import { prisma } from "../src/lib/prisma";

const ADMIN_ID = "ALT-ADMIN-QA";

async function updateCustomersForFilters() {
  console.log("🔄 Updating customers for filter testing...\n");

  try {
    // Tüm müşterileri al
    const customers = await prisma.customer.findMany({
      where: { adminId: ADMIN_ID },
      include: {
        jobs: {
          include: {
            maintenanceReminders: true,
          },
        },
      },
    });

    if (customers.length === 0) {
      console.log("❌ No customers found. Please run seed-full.ts first.");
      return;
    }

    const now = new Date();

    // 1. Ödemesi Gelen (Borcu Geçen) - İlk 3 müşteri
    // Bu müşterilerin işlerinde ödenmemiş borç olacak
    for (let i = 0; i < Math.min(3, customers.length); i++) {
      const customer = customers[i];
      
      // Müşteriye borç ekle
      await prisma.customer.update({
        where: { id: customer.id },
        data: {
          hasDebt: true,
          debtAmount: 1500 + (i * 500),
          hasInstallment: false,
          installmentCount: null,
          nextDebtDate: null,
          remainingDebtAmount: 1500 + (i * 500),
          paidDebtAmount: 0,
        },
      });

      // Bu müşterinin işlerinde ödenmemiş borç oluştur
      const customerJobs = await prisma.job.findMany({
        where: { customerId: customer.id },
      });

      if (customerJobs.length > 0) {
        const job = customerJobs[0];
        const price = 2000 + (i * 300);
        const collectedAmount = price * 0.3; // Sadece %30 ödenmiş

        await prisma.job.update({
          where: { id: job.id },
          data: {
            price,
            collectedAmount,
            paymentStatus: "PARTIAL", // Kısmen ödenmiş
          },
        });
      }

      console.log(`  ✓ Updated customer ${customer.name} - Ödemesi Gelen (Borcu Geçen)`);
    }

    // 2. Bakımı Gelen - Sonraki 4 müşteri
    // Bu müşterilerin işlerinde yaklaşan bakım tarihi olacak
    for (let i = 3; i < Math.min(7, customers.length); i++) {
      const customer = customers[i];
      
      const customerJobs = await prisma.job.findMany({
        where: { customerId: customer.id },
      });

      if (customerJobs.length > 0) {
        const job = customerJobs[0];
        
        // Bakım tarihleri: 2 geçmiş, 2 yaklaşıyor
        let maintenanceDueAt: Date;
        if (i < 5) {
          // Geçmiş bakım (5-10 gün önce)
          maintenanceDueAt = new Date(now);
          maintenanceDueAt.setDate(maintenanceDueAt.getDate() - (5 + (i - 3) * 2));
        } else {
          // Yaklaşan bakım (5-20 gün sonra)
          maintenanceDueAt = new Date(now);
          maintenanceDueAt.setDate(maintenanceDueAt.getDate() + (5 + (i - 5) * 5));
        }

        await prisma.job.update({
          where: { id: job.id },
          data: {
            maintenanceDueAt,
            status: "DELIVERED", // Teslim edilmiş işlerde bakım olur
          },
        });

        // Maintenance reminder oluştur veya güncelle
        await prisma.maintenanceReminder.upsert({
          where: { jobId: job.id },
          update: {
            dueAt: maintenanceDueAt,
            status: "PENDING",
          },
          create: {
            jobId: job.id,
            dueAt: maintenanceDueAt,
            status: "PENDING",
          },
        });
      }

      console.log(`  ✓ Updated customer ${customer.name} - Bakımı Gelen`);
    }

    // 3. Taksidi Geçen - Sonraki 3 müşteri
    // Bu müşterilerin taksitli borcu var ve taksit tarihi geçmiş
    for (let i = 7; i < Math.min(10, customers.length); i++) {
      const customer = customers[i];
      
      // Geçmiş taksit tarihi (5-15 gün önce)
      const nextDebtDate = new Date(now);
      nextDebtDate.setDate(nextDebtDate.getDate() - (5 + (i - 7) * 5));

      const totalDebt = 3000 + (i - 7) * 1000;
      const installmentCount = 6;
      const installmentAmount = totalDebt / installmentCount;
      const paidInstallments = 2; // 2 taksit ödenmiş
      const remainingDebt = totalDebt - (installmentAmount * paidInstallments);

      await prisma.customer.update({
        where: { id: customer.id },
        data: {
          hasDebt: true,
          debtAmount: totalDebt,
          hasInstallment: true,
          installmentCount,
          nextDebtDate,
          remainingDebtAmount: remainingDebt,
          paidDebtAmount: installmentAmount * paidInstallments,
        },
      });

      console.log(`  ✓ Updated customer ${customer.name} - Taksidi Geçen`);
    }

    // 4. Normal müşteriler (kalanlar) - Borç yok, bakım yok
    for (let i = 10; i < customers.length; i++) {
      const customer = customers[i];
      
      await prisma.customer.update({
        where: { id: customer.id },
        data: {
          hasDebt: false,
          debtAmount: null,
          hasInstallment: false,
          installmentCount: null,
          nextDebtDate: null,
          remainingDebtAmount: null,
          paidDebtAmount: null,
        },
      });

      // İşlerde ödeme tamamlanmış olsun
      const customerJobs = await prisma.job.findMany({
        where: { customerId: customer.id },
      });

      for (const job of customerJobs) {
        if (job.price) {
          await prisma.job.update({
            where: { id: job.id },
            data: {
              collectedAmount: job.price,
              paymentStatus: "PAID",
            },
          });
        }
      }

      console.log(`  ✓ Updated customer ${customer.name} - Normal (Sorun Yok)`);
    }

    console.log("\n✅ Customer updates completed successfully!");
    console.log("\n📊 Summary:");
    console.log(`  - Ödemesi Gelen (Borcu Geçen): 3 müşteri`);
    console.log(`  - Bakımı Gelen: 4 müşteri (2 geçmiş, 2 yaklaşıyor)`);
    console.log(`  - Taksidi Geçen: 3 müşteri`);
    console.log(`  - Normal: ${Math.max(0, customers.length - 10)} müşteri`);
  } catch (error) {
    console.error("\n❌ Update failed:", error);
    throw error;
  }
}

updateCustomersForFilters()
  .catch((error) => {
    console.error("Fatal error:", error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

