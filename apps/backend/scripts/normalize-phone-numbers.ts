import { prisma } from "../src/lib/prisma";

// Telefon numarasını normalize et (boşlukları ve özel karakterleri temizle)
function normalizePhoneNumber(phone: string): string {
  // Tüm boşlukları, tireleri, parantezleri ve diğer özel karakterleri temizle
  // Sadece rakamları ve başta + işaretini tut
  return phone.replace(/[\s\-\(\)]/g, "");
}

async function normalizeAllPhoneNumbers() {
  console.log("🔄 Telefon numaralarını normalize etmeye başlıyor...");

  try {
    // Tüm müşterileri al
    const customers = await prisma.customer.findMany({
      select: {
        id: true,
        phone: true,
      },
    });

    console.log(`📊 ${customers.length} müşteri bulundu`);

    let updatedCount = 0;
    let skippedCount = 0;

    for (const customer of customers) {
      const normalized = normalizePhoneNumber(customer.phone);
      
      // Eğer normalize edilmiş numara orijinalinden farklıysa güncelle
      if (normalized !== customer.phone) {
        await prisma.customer.update({
          where: { id: customer.id },
          data: { phone: normalized },
        });
        updatedCount++;
        console.log(`✅ ${customer.id}: "${customer.phone}" -> "${normalized}"`);
      } else {
        skippedCount++;
      }
    }

    // Tüm personelleri al
    const personnel = await prisma.personnel.findMany({
      select: {
        id: true,
        phone: true,
      },
    });

    console.log(`📊 ${personnel.length} personel bulundu`);

    for (const p of personnel) {
      const normalized = normalizePhoneNumber(p.phone);
      
      if (normalized !== p.phone) {
        await prisma.personnel.update({
          where: { id: p.id },
          data: { phone: normalized },
        });
        updatedCount++;
        console.log(`✅ ${p.id}: "${p.phone}" -> "${normalized}"`);
      } else {
        skippedCount++;
      }
    }

    console.log(`\n✅ Tamamlandı!`);
    console.log(`   Güncellenen: ${updatedCount}`);
    console.log(`   Değişmeyen: ${skippedCount}`);
  } catch (error) {
    console.error("❌ Hata:", error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

normalizeAllPhoneNumbers()
  .then(() => {
    console.log("✅ Script başarıyla tamamlandı");
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ Script hatası:", error);
    process.exit(1);
  });

