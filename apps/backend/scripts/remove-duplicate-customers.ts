import { prisma } from "../src/lib/prisma";

// Telefon numarasını normalize et (boşlukları ve özel karakterleri temizle)
function normalizePhoneNumber(phone: string): string {
  return phone.replace(/[\s\-\(\)]/g, "");
}

async function removeDuplicateCustomers() {
  console.log("🔍 Duplicate müşteri taraması başlıyor...\n");

  try {
    // Tüm müşterileri al
    const customers = await prisma.customer.findMany({
      select: {
        id: true,
        name: true,
        phone: true,
        createdAt: true,
        adminId: true,
      },
      orderBy: { createdAt: "asc" }, // En eski ilk sırada
    });

    console.log(`📊 Toplam ${customers.length} müşteri bulundu\n`);

    // Müşterileri adminId + name + phone bazında grupla
    const groupedMap = new Map<string, typeof customers>();

    for (const customer of customers) {
      const normalizedPhone = normalizePhoneNumber(customer.phone);
      const key = `${customer.adminId}_${customer.name.toLowerCase().trim()}_${normalizedPhone}`;
      
      const existing = groupedMap.get(key);
      if (existing) {
        existing.push(customer);
      } else {
        groupedMap.set(key, [customer]);
      }
    }

    // Duplicate gruplarını bul
    const duplicateGroups: Array<{ key: string; customers: typeof customers }> = [];
    
    for (const [key, group] of groupedMap) {
      if (group.length > 1) {
        duplicateGroups.push({ key, customers: group });
      }
    }

    if (duplicateGroups.length === 0) {
      console.log("✅ Duplicate müşteri bulunamadı!");
      return;
    }

    console.log(`⚠️ ${duplicateGroups.length} duplicate grup bulundu:\n`);

    let totalDeleted = 0;
    const idsToDelete: string[] = [];

    for (const group of duplicateGroups) {
      console.log(`\n📋 Grup: "${group.customers[0].name}" - ${group.customers[0].phone}`);
      console.log(`   ${group.customers.length} kayıt bulundu:`);
      
      // En eski kaydı koru (index 0, çünkü createdAt'e göre sıralandı)
      const keepCustomer = group.customers[0];
      console.log(`   ✅ KORUNACAK: ID=${keepCustomer.id}, createdAt=${keepCustomer.createdAt.toISOString()}`);
      
      // Diğerlerini sil
      for (let i = 1; i < group.customers.length; i++) {
        const deleteCustomer = group.customers[i];
        console.log(`   ❌ SİLİNECEK: ID=${deleteCustomer.id}, createdAt=${deleteCustomer.createdAt.toISOString()}`);
        idsToDelete.push(deleteCustomer.id);
        totalDeleted++;
      }
    }

    console.log(`\n🗑️ Toplam ${totalDeleted} duplicate kayıt silinecek...\n`);

    // Silme işlemi (cascade ile ilişkili tablolar da silinecek)
    if (idsToDelete.length > 0) {
      // Her bir müşteriyi tek tek sil (cascade çalışsın diye)
      for (const id of idsToDelete) {
        await prisma.customer.delete({
          where: { id },
        });
        console.log(`   ✅ Silindi: ${id}`);
      }
    }

    // Sonuç raporu
    const remainingCount = await prisma.customer.count();
    console.log(`\n📊 Sonuç:`);
    console.log(`   Önceki toplam: ${customers.length}`);
    console.log(`   Silinen: ${totalDeleted}`);
    console.log(`   Kalan: ${remainingCount}`);
  } catch (error) {
    console.error("❌ Hata:", error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

removeDuplicateCustomers()
  .then(() => {
    console.log("\n✅ Script başarıyla tamamlandı");
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ Script hatası:", error);
    process.exit(1);
  });
