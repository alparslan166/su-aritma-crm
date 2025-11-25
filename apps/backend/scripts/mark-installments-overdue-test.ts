/// <reference types="node" />
import { prisma } from "../src/lib/prisma";

async function markInstallmentsOverdueForTest() {
  console.log("🔄 Test amaçlı taksitleri geçirmeye başlıyor...");

  try {
    // hasInstallment=true olan tüm müşterileri bul
    const customersWithInstallments = await prisma.customer.findMany({
      where: {
        hasInstallment: true,
      },
      select: {
        id: true,
        name: true,
        hasInstallment: true,
        installmentStartDate: true,
        installmentIntervalDays: true,
        nextDebtDate: true,
        hasDebt: true,
        debtAmount: true,
      },
      take: 10,
    });

    console.log(`📊 ${customersWithInstallments.length} taksitli müşteri bulundu`);

    if (customersWithInstallments.length === 0) {
      console.log("❌ Taksitli müşteri bulunamadı");
      return;
    }

    const now = new Date();
    let updatedCount = 0;

    // İlk 5 taksitli müşteriyi güncelle
    const customersToUpdate = customersWithInstallments.slice(
      0,
      Math.min(5, customersWithInstallments.length),
    );

    for (const customer of customersToUpdate) {
      // Eğer installmentStartDate veya installmentIntervalDays yoksa, varsayılan değerler ver
      const intervalDays = customer.installmentIntervalDays ?? 30; // Varsayılan 30 gün
      let startDate = customer.installmentStartDate;

      // Eğer startDate yoksa, bugünden 60 gün öncesine ayarla
      if (!startDate) {
        startDate = new Date(now);
        startDate.setDate(startDate.getDate() - 60);
        startDate.setHours(0, 0, 0, 0);
      }

      // Taksit başlangıç tarihini geçmiş bir tarihe ayarla
      // En az bir taksit aralığı + 1 gün geçmiş
      const overdueStartDate = new Date(now);
      overdueStartDate.setDate(overdueStartDate.getDate() - (intervalDays + 1));
      overdueStartDate.setHours(0, 0, 0, 0);

      // nextDebtDate'i de geçmiş bir tarihe ayarla
      const overdueNextDebtDate = new Date(overdueStartDate);
      overdueNextDebtDate.setDate(overdueNextDebtDate.getDate() + intervalDays);
      overdueNextDebtDate.setHours(0, 0, 0, 0);

      // Eğer installmentIntervalDays yoksa, onu da güncelle
      const updateData: {
        installmentStartDate: Date;
        nextDebtDate: Date;
        installmentIntervalDays?: number;
      } = {
        installmentStartDate: overdueStartDate,
        nextDebtDate: overdueNextDebtDate,
      };

      if (!customer.installmentIntervalDays) {
        updateData.installmentIntervalDays = intervalDays;
      }

      await prisma.customer.update({
        where: { id: customer.id },
        data: updateData,
      });

      updatedCount++;
      console.log(`✅ ${customer.name} (${customer.id}):`);
      console.log(`   Eski başlangıç: ${customer.installmentStartDate?.toISOString() ?? "null"}`);
      console.log(`   Yeni başlangıç: ${overdueStartDate.toISOString()}`);
      console.log(`   Eski nextDebtDate: ${customer.nextDebtDate?.toISOString() ?? "null"}`);
      console.log(`   Yeni nextDebtDate: ${overdueNextDebtDate.toISOString()}`);
      console.log(
        `   IntervalDays: ${customer.installmentIntervalDays ?? "null"} -> ${intervalDays}`,
      );
    }

    console.log(`\n✅ Tamamlandı!`);
    console.log(`   Güncellenen müşteri sayısı: ${updatedCount}`);
  } catch (error) {
    console.error("❌ Hata:", error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

markInstallmentsOverdueForTest()
  .then(() => {
    console.log("✅ Script başarıyla tamamlandı");
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ Script hatası:", error);
    process.exit(1);
  });
