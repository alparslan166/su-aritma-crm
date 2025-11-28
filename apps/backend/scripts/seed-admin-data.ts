/* eslint-disable @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-member-access, @typescript-eslint/no-unsafe-call */
import { JobStatus, PersonnelStatus, PaymentStatus, MaintenanceStatus } from "@prisma/client";
import bcrypt from "bcryptjs";

import { prisma } from "../src/lib/prisma";
import { generateLoginCode } from "../src/lib/generators";

// TypeScript için process tanımı
declare const process: {
  argv: string[];
  exit: (code: number) => never;
};

async function main() {
  // Komut satırı argümanlarını al
  const args = process.argv.slice(2);
  const emailArg = args.find((arg) => arg.startsWith("--email="));
  const email = emailArg ? emailArg.split("=")[1] : null;

  if (!email) {
    console.log("📋 Mevcut Adminler:\n");
    const admins = await prisma.admin.findMany({
      select: {
        id: true,
        name: true,
        email: true,
      },
      orderBy: { createdAt: "desc" },
    });

    if (admins.length === 0) {
      console.log("   Henüz admin bulunmuyor.\n");
      return;
    }

    admins.forEach((admin, index) => {
      console.log(`   ${index + 1}. ${admin.name} (${admin.email})`);
    });

    console.log("\n💡 Admin'e veri eklemek için:");
    console.log("   npm run seed:admin-data -- --email=admin@example.com\n");
    return;
  }

  // Email ile admini bul
  const admin = await prisma.admin.findFirst({
    where: { email },
  });

  if (!admin) {
    console.error(`❌ Email '${email}' ile admin bulunamadı!`);
    // eslint-disable-next-line no-process-exit
    process.exit(1);
    return;
  }

  console.log(`\n📝 Admin bulundu: ${admin.name} (${admin.email})\n`);
  console.log("🔄 Veri ekleme başlatılıyor...\n");

  try {
    // 1. Personel ekle
    const personnel = await seedPersonnel(admin.id);

    // 2. Müşteriler ekle (borcu gelen, bakımı gelen, normal)
    const customers = await seedCustomers(admin.id);

    // 3. Stok ekle
    const inventoryItems = await seedInventory(admin.id);

    // 4. Geçmiş işler ekle
    const jobs = await seedJobs(admin.id, customers, personnel);

    // 5. Bakım hatırlatmaları ekle
    await seedMaintenanceReminders(admin.id, jobs);

    // 6. Bildirimler ekle
    await seedNotifications(admin.id, jobs);

    console.log("\n✅ Tüm veriler başarıyla eklendi!");
    console.log("\n📊 Özet:");
    console.log(`   - Personel: ${personnel.length}`);
    console.log(`   - Müşteriler: ${customers.length}`);
    console.log(`   - Stok: ${inventoryItems.length}`);
    console.log(`   - İşler: ${jobs.length}`);
    console.log(
      `   - Bildirimler: ${await prisma.notification.count({ where: { adminId: admin.id } })}`,
    );
  } catch (error) {
    console.error("\n❌ Veri eklenirken hata oluştu:", error);
    // eslint-disable-next-line no-process-exit
    process.exit(1);
  }
}

async function seedPersonnel(adminId: string) {
  console.log("🔄 Personel ekleniyor...");
  const personnelNames = ["Ahmet Yılmaz", "Mehmet Demir", "Ayşe Kaya", "Fatma Şahin", "Ali Çelik"];

  const personnel: Array<{
    id: string;
    name: string;
    status: PersonnelStatus;
  }> = [];
  for (let i = 0; i < personnelNames.length; i++) {
    const name = personnelNames[i];
    const loginCode = generateLoginCode();
    const hireDate = new Date();
    hireDate.setMonth(hireDate.getMonth() - (6 + i * 2));

    const created = await prisma.personnel.create({
      data: {
        adminId,
        name,
        phone: `+90 555 ${100 + i} ${20 + i} ${30 + i}`,
        email: `personel${i + 1}@suaritma.com`,
        loginCode,
        loginCodeUpdatedAt: new Date(),
        hireDate,
        status: "ACTIVE",
        canShareLocation: true,
        permissions: {},
      },
    });
    personnel.push({ id: created.id, name: created.name, status: created.status });
    console.log(`   ✓ ${name} eklendi`);
  }
  return personnel;
}

async function seedCustomers(adminId: string) {
  console.log("\n🔄 Müşteriler ekleniyor...");
  const customerData = [
    { name: "Ahmet Yılmaz", hasDebt: true, hasMaintenance: true },
    { name: "Hasan Demir", hasDebt: true, hasMaintenance: false },
    { name: "Ayşe Kaya", hasDebt: false, hasMaintenance: true },
    { name: "Mehmet Öztürk", hasDebt: false, hasMaintenance: false },
    { name: "Fatma Şahin", hasDebt: true, hasMaintenance: true },
    { name: "Ali Çelik", hasDebt: false, hasMaintenance: false },
    { name: "Zeynep Arslan", hasDebt: true, hasMaintenance: false },
    { name: "Mustafa Yıldız", hasDebt: false, hasMaintenance: true },
  ];

  const customers: Array<{
    id: string;
    name: string;
    address: string;
  }> = [];
  for (let i = 0; i < customerData.length; i++) {
    const data = customerData[i];
    const createdAt = new Date();
    createdAt.setMonth(createdAt.getMonth() - (3 + i));

    const customer = await prisma.customer.create({
      data: {
        adminId,
        name: data.name,
        phone: `+90 212 ${500 + i} ${10 + i} ${20 + i}`,
        email: `musteri${i + 1}@example.com`,
        address: `${data.name.split(" ")[0]} Mahallesi, ${data.name.split(" ")[1]} Sokak No: ${i + 1}`,
        status: "ACTIVE",
        createdAt,
      },
    });

    // Borç ekle
    if (data.hasDebt) {
      const debtAmount = 500 + i * 100;
      const nextDebtDate = new Date(Date.now() - (i + 1) * 7 * 24 * 60 * 60 * 1000); // Geçmiş tarihler
      await prisma.customer.update({
        where: { id: customer.id },
        data: {
          hasDebt: true,
          debtAmount,
          remainingDebtAmount: debtAmount,
          nextDebtDate,
          paidDebtAmount: 0,
        },
      });
    }

    customers.push({
      id: customer.id,
      name: customer.name,
      address: customer.address,
    });
    console.log(
      `   ✓ ${data.name} eklendi${data.hasDebt ? " (Borçlu)" : ""}${data.hasMaintenance ? " (Bakımı Gelen)" : ""}`,
    );
  }
  return customers;
}

async function seedInventory(adminId: string) {
  console.log("\n🔄 Stok ekleniyor...");
  const items = [
    {
      category: "Filtre",
      name: "Sediment Filtre 10 inç",
      sku: "FIL-SED-10",
      unit: "adet",
      unitPrice: 45.5,
      stockQty: 5,
      criticalThreshold: 20,
    },
    {
      category: "Filtre",
      name: "Karbon Filtre 10 inç",
      sku: "FIL-KAR-10",
      unit: "adet",
      unitPrice: 65.0,
      stockQty: 3,
      criticalThreshold: 15,
    },
    {
      category: "Filtre",
      name: "RO Membran 50 GPD",
      sku: "MEM-RO-50",
      unit: "adet",
      unitPrice: 180.0,
      stockQty: 8,
      criticalThreshold: 10,
    },
    {
      category: "Pompa",
      name: "RO Pompa 24V",
      sku: "POM-RO-24",
      unit: "adet",
      unitPrice: 350.0,
      stockQty: 2,
      criticalThreshold: 5,
    },
    {
      category: "Yedek Parça",
      name: "Vana Seti",
      sku: "YP-VAN-001",
      unit: "takım",
      unitPrice: 85.0,
      stockQty: 12,
      criticalThreshold: 10,
    },
    {
      category: "Filtre",
      name: "Post Karbon Filtre",
      sku: "FIL-POST-10",
      unit: "adet",
      unitPrice: 55.0,
      stockQty: 4,
      criticalThreshold: 15,
    },
  ];

  const inventoryItems: Array<{ id: string }> = [];
  for (const itemData of items) {
    const created = await prisma.inventoryItem.create({
      data: {
        adminId,
        ...itemData,
        reorderPoint: itemData.criticalThreshold * 2,
        reorderQuantity: itemData.criticalThreshold * 3,
      },
    });
    inventoryItems.push({ id: created.id });
    console.log(`   ✓ ${itemData.name} (Stok: ${itemData.stockQty})`);
  }
  return inventoryItems;
}

async function seedJobs(
  adminId: string,
  customers: Array<{ id: string; name: string; address: string }>,
  personnel: Array<{ id: string; name: string; status: PersonnelStatus }>,
) {
  console.log("\n🔄 Geçmiş işler ekleniyor...");
  const jobs: Array<{
    id: string;
    customerId: string;
    maintenanceDueAt: Date | null;
  }> = [];

  // Tamamlanmış işler (geçmiş)
  for (let i = 0; i < Math.min(8, customers.length); i++) {
    const customer = customers[i];
    const personnelIndex = i % personnel.length;
    const assignedPersonnel = personnel[personnelIndex];

    const scheduledAt = new Date();
    scheduledAt.setDate(scheduledAt.getDate() - (30 + i * 5)); // 30-65 gün önce

    const deliveredAt = new Date(scheduledAt);
    deliveredAt.setDate(deliveredAt.getDate() + 1);

    const price = 2500 + i * 100;
    const collectedAmount = i % 2 === 0 ? price : price * 0.5;
    const maintenanceDueAt = new Date(deliveredAt.getTime() + 6 * 30 * 24 * 60 * 60 * 1000);

    const job = await prisma.job.create({
      data: {
        adminId,
        customerId: customer.id,
        title: "Su Arıtma Cihazı Kurulumu",
        notes: `${customer.name} için su arıtma cihazı kurulumu yapıldı.`,
        status: JobStatus.DELIVERED,
        scheduledAt,
        deliveredAt,
        location: {
          address: customer.address,
          latitude: 41.0082 + i * 0.01,
          longitude: 28.9784 + i * 0.01,
        },
        price,
        collectedAmount,
        paymentStatus: i % 2 === 0 ? PaymentStatus.PAID : PaymentStatus.PARTIAL,
        nextMaintenanceIntervalMonths: 6,
        maintenanceDueAt,
      },
    });

    // Personel atama
    await prisma.jobPersonnel.create({
      data: {
        jobId: job.id,
        personnelId: assignedPersonnel.id,
        assignedAt: scheduledAt,
        startedAt: scheduledAt,
        deliveredAt,
      },
    });

    // İş durumu geçmişi
    await prisma.jobStatusHistory.create({
      data: {
        jobId: job.id,
        status: JobStatus.PENDING,
        changedByAdminId: adminId,
        createdAt: scheduledAt,
      },
    });

    await prisma.jobStatusHistory.create({
      data: {
        jobId: job.id,
        status: JobStatus.IN_PROGRESS,
        changedByPersonnelId: assignedPersonnel.id,
        createdAt: new Date(scheduledAt.getTime() + 2 * 60 * 60 * 1000),
      },
    });

    await prisma.jobStatusHistory.create({
      data: {
        jobId: job.id,
        status: job.status,
        changedByPersonnelId: assignedPersonnel.id,
        createdAt: deliveredAt,
      },
    });

    jobs.push({
      id: job.id,
      customerId: job.customerId,
      maintenanceDueAt: job.maintenanceDueAt,
    });
    console.log(`   ✓ ${customer.name} - ${job.title} (${job.status})`);
  }

  return jobs;
}

async function seedMaintenanceReminders(
  adminId: string,
  jobs: Array<{ id: string; customerId: string; maintenanceDueAt: Date | null }>,
) {
  console.log("\n🔄 Bakım hatırlatmaları ekleniyor...");
  let count = 0;

  for (const job of jobs) {
    if (job.maintenanceDueAt) {
      const dueDate = new Date(job.maintenanceDueAt);
      // Bazı bakımları yaklaşan, bazılarını gelecek yap
      if (count % 2 === 0) {
        dueDate.setDate(dueDate.getDate() - 5); // 5 gün önce (yaklaşan)
      } else {
        dueDate.setDate(dueDate.getDate() + 20); // 20 gün sonra (gelecek)
      }

      await prisma.maintenanceReminder.create({
        data: {
          jobId: job.id,
          dueAt: dueDate,
          status: MaintenanceStatus.PENDING,
        },
      });
      count++;
      console.log(`   ✓ Bakım hatırlatması eklendi (${dueDate.toLocaleDateString("tr-TR")})`);
    }
  }
}

async function seedNotifications(
  adminId: string,
  jobs: Array<{ id: string; customerId: string; maintenanceDueAt: Date | null }>,
) {
  console.log("\n🔄 Bildirimler ekleniyor...");
  const notifications = [
    {
      type: "job_completed",
      title: "İş Tamamlandı",
      body: "Ahmet Yılmaz için yapılan iş tamamlandı.",
      jobId: jobs[0]?.id,
    },
    {
      type: "payment_overdue",
      title: "Ödeme Gecikmesi",
      body: "Hasan Demir için ödeme gecikmesi var.",
    },
    {
      type: "maintenance_due",
      title: "Bakım Zamanı",
      body: "Ayşe Kaya için bakım zamanı yaklaşıyor.",
      jobId: jobs[2]?.id,
    },
    {
      type: "low_stock",
      title: "Düşük Stok Uyarısı",
      body: "Sediment Filtre 10 inç stokta azaldı.",
    },
    {
      type: "job_assigned",
      title: "Yeni İş Atandı",
      body: "Size yeni bir iş atandı.",
      jobId: jobs[1]?.id,
    },
  ];

  for (let i = 0; i < notifications.length; i++) {
    const notif = notifications[i];
    const createdAt = new Date();
    createdAt.setHours(createdAt.getHours() - (notifications.length - i));

    await prisma.notification.create({
      data: {
        adminId,
        jobId: notif.jobId || null,
        targetRole: "admin",
        type: notif.type,
        payload: {
          title: notif.title,
          body: notif.body,
        },
        readAt: i < 2 ? null : createdAt, // İlk 2'si okunmamış
        createdAt,
      },
    });
    console.log(`   ✓ ${notif.title}`);
  }
}

main()
  .catch((error) => {
    console.error("❌ Veri eklenirken hata oluştu:", error);
    // eslint-disable-next-line no-process-exit
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
