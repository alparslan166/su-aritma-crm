import { JobStatus, PersonnelStatus, PaymentStatus, MaintenanceStatus } from "@prisma/client";
import bcrypt from "bcryptjs";

import { prisma } from "../src/lib/prisma";
import { generateLoginCode } from "../src/lib/generators";

const ADMIN_ID = "ALT-ADMIN-QA";

// Türkçe gerçekçi test verileri
const PERSONNEL_NAMES = [
  "Ahmet Yılmaz",
  "Mehmet Demir",
  "Ayşe Kaya",
  "Fatma Şahin",
  "Ali Çelik",
  "Zeynep Arslan",
  "Mustafa Öztürk",
  "Emine Yıldız",
  "Hasan Aydın",
  "Hatice Doğan",
];

const CUSTOMER_NAMES = [
  { name: "İstanbul Su Arıtma Ltd.", city: "İstanbul", district: "Kadıköy" },
  { name: "Ankara Temiz Su A.Ş.", city: "Ankara", district: "Çankaya" },
  { name: "İzmir Filtre Sistemleri", city: "İzmir", district: "Bornova" },
  { name: "Bursa Su Teknolojileri", city: "Bursa", district: "Nilüfer" },
  { name: "Antalya Arıtma Çözümleri", city: "Antalya", district: "Muratpaşa" },
  { name: "Adana Su Filtreleri", city: "Adana", district: "Seyhan" },
  { name: "Gaziantep Arıtma Sistemleri", city: "Gaziantep", district: "Şahinbey" },
  { name: "Konya Temiz Su", city: "Konya", district: "Selçuklu" },
  { name: "Trabzon Su Teknolojileri", city: "Trabzon", district: "Ortahisar" },
  { name: "Eskişehir Filtre Merkezi", city: "Eskişehir", district: "Tepebaşı" },
  { name: "Sakarya Su Arıtma", city: "Sakarya", district: "Adapazarı" },
  { name: "Denizli Filtre Sistemleri", city: "Denizli", district: "Pamukkale" },
  { name: "Mersin Su Teknolojileri", city: "Mersin", district: "Yenişehir" },
  { name: "Kayseri Arıtma Çözümleri", city: "Kayseri", district: "Melikgazi" },
  { name: "Samsun Temiz Su", city: "Samsun", district: "İlkadım" },
];

const INVENTORY_ITEMS = [
  { category: "Filtre", name: "Sediment Filtre 10 inç", sku: "FIL-SED-10", unit: "adet", unitPrice: 45.50, stockQty: 150, criticalThreshold: 20 },
  { category: "Filtre", name: "Karbon Filtre 10 inç", sku: "FIL-KAR-10", unit: "adet", unitPrice: 65.00, stockQty: 120, criticalThreshold: 15 },
  { category: "Filtre", name: "RO Membran 50 GPD", sku: "MEM-RO-50", unit: "adet", unitPrice: 180.00, stockQty: 45, criticalThreshold: 10 },
  { category: "Filtre", name: "RO Membran 75 GPD", sku: "MEM-RO-75", unit: "adet", unitPrice: 220.00, stockQty: 30, criticalThreshold: 8 },
  { category: "Pompa", name: "RO Pompa 24V", sku: "POM-RO-24", unit: "adet", unitPrice: 350.00, stockQty: 25, criticalThreshold: 5 },
  { category: "Pompa", name: "Basınç Pompası", sku: "POM-BAS-001", unit: "adet", unitPrice: 450.00, stockQty: 18, criticalThreshold: 4 },
  { category: "Yedek Parça", name: "Vana Seti", sku: "YP-VAN-001", unit: "takım", unitPrice: 85.00, stockQty: 60, criticalThreshold: 10 },
  { category: "Yedek Parça", name: "Hortum 1/4 inç", sku: "YP-HOR-14", unit: "metre", unitPrice: 12.50, stockQty: 200, criticalThreshold: 30 },
  { category: "Yedek Parça", name: "Hortum 3/8 inç", sku: "YP-HOR-38", unit: "metre", unitPrice: 15.00, stockQty: 180, criticalThreshold: 25 },
  { category: "Filtre", name: "Post Karbon Filtre", sku: "FIL-POST-10", unit: "adet", unitPrice: 55.00, stockQty: 100, criticalThreshold: 15 },
  { category: "Filtre", name: "Mineral Filtre", sku: "FIL-MIN-10", unit: "adet", unitPrice: 75.00, stockQty: 80, criticalThreshold: 12 },
  { category: "Yedek Parça", name: "Fitting Seti", sku: "YP-FIT-001", unit: "takım", unitPrice: 35.00, stockQty: 90, criticalThreshold: 15 },
  { category: "Yedek Parça", name: "Tank Valfi", sku: "YP-TAN-001", unit: "adet", unitPrice: 120.00, stockQty: 40, criticalThreshold: 8 },
  { category: "Filtre", name: "UF Membran", sku: "MEM-UF-001", unit: "adet", unitPrice: 280.00, stockQty: 20, criticalThreshold: 5 },
  { category: "Pompa", name: "Booster Pompa", sku: "POM-BOO-001", unit: "adet", unitPrice: 520.00, stockQty: 12, criticalThreshold: 3 },
  { category: "Yedek Parça", name: "Kartuş Filtre 20 inç", sku: "FIL-KAR-20", unit: "adet", unitPrice: 95.00, stockQty: 70, criticalThreshold: 10 },
  { category: "Yedek Parça", name: "Konsol Kutusu", sku: "YP-KON-001", unit: "adet", unitPrice: 180.00, stockQty: 35, criticalThreshold: 6 },
  { category: "Filtre", name: "Alkali Filtre", sku: "FIL-ALK-10", unit: "adet", unitPrice: 88.00, stockQty: 55, criticalThreshold: 10 },
  { category: "Yedek Parça", name: "Drenaj Valfi", sku: "YP-DRE-001", unit: "adet", unitPrice: 42.00, stockQty: 75, criticalThreshold: 12 },
];

async function ensureAdmin() {
  const existingAdmin = await prisma.admin.findUnique({
    where: { id: ADMIN_ID },
  });

  if (!existingAdmin) {
    const password = "1234";
    const hash = await bcrypt.hash(password, 12);
    await prisma.admin.create({
      data: {
        id: ADMIN_ID,
        name: "QA Alt Admin",
        phone: "+90 555 444 33 22",
        email: "qa.alt@suaritma.com",
        role: "ALT",
        status: "active",
        passwordHash: hash,
      },
    });
    console.log("✅ Admin created:", ADMIN_ID);
  } else {
    console.log("✅ Admin already exists:", ADMIN_ID);
  }
  return ADMIN_ID;
}

async function seedPersonnel(adminId: string) {
  console.log("\n🔄 Seeding Personnel...");
  const personnel = [];

  for (let i = 0; i < PERSONNEL_NAMES.length; i++) {
    const name = PERSONNEL_NAMES[i];
    const [firstName, lastName] = name.split(" ");
    const statuses: PersonnelStatus[] = ["ACTIVE", "ACTIVE", "ACTIVE", "SUSPENDED", "INACTIVE"];
    const status = statuses[i % statuses.length];

    const hireDate = new Date();
    hireDate.setMonth(hireDate.getMonth() - (12 + i * 2)); // 12-30 ay önce işe başlamış

    const created = await prisma.personnel.create({
      data: {
        adminId,
        name,
        phone: `+90 555 ${100 + i} ${2000 + i}`,
        email: `${firstName.toLowerCase()}.${lastName.toLowerCase()}@suaritma.com`,
        loginCode: generateLoginCode(),
        hireDate,
        status,
        canShareLocation: i % 3 !== 0, // Bazıları konum paylaşmıyor
        permissions: {
          canViewJobs: true,
          canStartJobs: status === "ACTIVE",
          canDeliverJobs: status === "ACTIVE",
        },
      },
    });
    personnel.push(created);
    console.log(`  ✓ Created personnel: ${name} (${status})`);
  }

  console.log(`✅ Created ${personnel.length} personnel`);
  return personnel;
}

async function seedCustomers(adminId: string) {
  console.log("\n🔄 Seeding Customers...");
  const customers = [];

  for (const customerData of CUSTOMER_NAMES) {
    const created = await prisma.customer.create({
      data: {
        adminId,
        name: customerData.name,
        phone: `+90 ${312 + Math.floor(Math.random() * 900)} ${100 + Math.floor(Math.random() * 9000)} ${1000 + Math.floor(Math.random() * 9000)}`,
        email: `info@${customerData.name.toLowerCase().replace(/\s+/g, "")}.com`,
        address: `${customerData.district}, ${customerData.city}`,
      },
    });
    customers.push(created);
    console.log(`  ✓ Created customer: ${customerData.name}`);
  }

  console.log(`✅ Created ${customers.length} customers`);
  return customers;
}

async function seedInventory(adminId: string) {
  console.log("\n🔄 Seeding Inventory...");
  const items = [];

  for (const itemData of INVENTORY_ITEMS) {
    const created = await prisma.inventoryItem.create({
      data: {
        adminId,
        ...itemData,
        reorderPoint: itemData.criticalThreshold * 2,
        reorderQuantity: itemData.criticalThreshold * 3,
      },
    });
    items.push(created);
    console.log(`  ✓ Created inventory: ${itemData.name} (Stock: ${itemData.stockQty})`);
  }

  console.log(`✅ Created ${items.length} inventory items`);
  return items;
}

async function seedJobs(adminId: string, customers: any[], personnel: any[]) {
  console.log("\n🔄 Seeding Jobs...");
  const jobs = [];
  const now = new Date();

  const jobTitles = [
    "Su Arıtma Cihazı Kurulumu",
    "Filtre Değişimi",
    "RO Membran Değişimi",
    "Pompa Tamiri",
    "Sistem Bakımı",
    "Yeni Sistem Kurulumu",
    "Filtre Temizliği",
    "Sistem Kontrolü",
    "Acil Müdahale",
    "Periyodik Bakım",
  ];

  const statuses: JobStatus[] = ["PENDING", "IN_PROGRESS", "DELIVERED", "ARCHIVED"];
  const paymentStatuses: PaymentStatus[] = ["NOT_PAID", "PARTIAL", "PAID"];

  for (let i = 0; i < 25; i++) {
    const customer = customers[i % customers.length];
    const status = statuses[i % statuses.length];
    const paymentStatus = paymentStatuses[i % paymentStatuses.length];
    const title = jobTitles[i % jobTitles.length];
    
    const scheduledAt = new Date(now);
    scheduledAt.setDate(scheduledAt.getDate() + (i - 10)); // -10 ile +15 gün arası

    const location = {
      address: customer.address,
      latitude: 39.9334 + (Math.random() - 0.5) * 0.5,
      longitude: 32.8597 + (Math.random() - 0.5) * 0.5,
    };

    const price = 500 + Math.floor(Math.random() * 2000);

    let startedAt: Date | null = null;
    let deliveredAt: Date | null = null;
    let archivedAt: Date | null = null;
    let statusChangedAt: Date | null = null;

    if (status === "IN_PROGRESS" || status === "DELIVERED" || status === "ARCHIVED") {
      startedAt = new Date(scheduledAt);
      startedAt.setHours(startedAt.getHours() + 2);
      statusChangedAt = startedAt;
    }

    if (status === "DELIVERED" || status === "ARCHIVED") {
      deliveredAt = new Date(startedAt!);
      deliveredAt.setHours(deliveredAt.getHours() + 4);
      statusChangedAt = deliveredAt;
    }

    if (status === "ARCHIVED") {
      archivedAt = new Date(deliveredAt!);
      archivedAt.setDate(archivedAt.getDate() + 7);
      statusChangedAt = archivedAt;
    }

    const job = await prisma.job.create({
      data: {
        adminId,
        customerId: customer.id,
        title: `${title} - ${customer.name}`,
        status,
        scheduledAt: status === "PENDING" ? scheduledAt : null,
        location: location as any,
        price,
        paymentStatus,
        notes: i % 3 === 0 ? `Not: ${title} için özel talimatlar` : null,
        statusChangedAt,
        startedAt,
        deliveredAt,
        archivedAt,
        maintenanceDueAt: status === "DELIVERED" || status === "ARCHIVED" 
          ? new Date(now.getTime() + (30 + i * 10) * 24 * 60 * 60 * 1000) 
          : null,
      },
    });

    // Job-Personnel atamaları
    if (status !== "PENDING" && personnel.length > 0) {
      const assignedPersonnel = personnel.filter(p => p.status === "ACTIVE").slice(0, 1 + (i % 2));
      for (const person of assignedPersonnel) {
        await prisma.jobPersonnel.create({
          data: {
            jobId: job.id,
            personnelId: person.id,
            startedAt: startedAt || undefined,
            deliveredAt: deliveredAt || undefined,
          },
        });
      }
    }

    // Job status history
    if (statusChangedAt) {
      await prisma.jobStatusHistory.create({
        data: {
          jobId: job.id,
          status,
          note: `Status changed to ${status}`,
          changedByAdminId: adminId,
        },
      });
    }

    jobs.push(job);
    console.log(`  ✓ Created job: ${title} (${status})`);
  }

  console.log(`✅ Created ${jobs.length} jobs`);
  return jobs;
}

async function seedMaintenanceReminders(adminId: string, jobs: any[]) {
  console.log("\n🔄 Seeding Maintenance Reminders...");
  const reminders = [];
  const now = new Date();

  const deliveredJobs = jobs.filter(j => j.status === "DELIVERED" || j.status === "ARCHIVED");

  for (let i = 0; i < deliveredJobs.length && i < 15; i++) {
    const job = deliveredJobs[i];
    const dueAt = new Date(job.maintenanceDueAt || now);
    
    let status: MaintenanceStatus = "PENDING";
    let sentAt: Date | null = null;
    let lastWindowNotified = null;
    let lastNotifiedAt: Date | null = null;

    const daysUntilDue = Math.ceil((dueAt.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));

    if (daysUntilDue < 0) {
      status = "PENDING";
    } else if (daysUntilDue <= 1) {
      status = "SENT";
      sentAt = new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000);
      lastNotifiedAt = sentAt;
      lastWindowNotified = "ONE_DAY";
    } else if (daysUntilDue <= 3) {
      status = "SENT";
      sentAt = new Date(now.getTime() - 5 * 24 * 60 * 60 * 1000);
      lastNotifiedAt = sentAt;
      lastWindowNotified = "THREE_DAYS";
    } else if (daysUntilDue <= 7) {
      status = "SENT";
      sentAt = new Date(now.getTime() - 10 * 24 * 60 * 60 * 1000);
      lastNotifiedAt = sentAt;
      lastWindowNotified = "SEVEN_DAYS";
    }

    const reminder = await prisma.maintenanceReminder.upsert({
      where: { jobId: job.id },
      update: {
        dueAt,
        status,
        sentAt,
        lastWindowNotified: lastWindowNotified as any,
        lastNotifiedAt,
      },
      create: {
        jobId: job.id,
        dueAt,
        status,
        sentAt,
        lastWindowNotified: lastWindowNotified as any,
        lastNotifiedAt,
      },
    });

    reminders.push(reminder);
    console.log(`  ✓ Created maintenance reminder for job ${job.id.substring(0, 8)}... (${status})`);
  }

  console.log(`✅ Created ${reminders.length} maintenance reminders`);
  return reminders;
}

async function seedJobNotes(adminId: string, jobs: any[], personnel: any[]) {
  console.log("\n🔄 Seeding Job Notes...");
  let noteCount = 0;

  for (let i = 0; i < jobs.length; i++) {
    const job = jobs[i];
    const noteCountForJob = 1 + (i % 3); // 1-3 not per job

    for (let j = 0; j < noteCountForJob; j++) {
      const isAdminNote = j % 2 === 0;
      const authorId = isAdminNote 
        ? adminId 
        : personnel.filter(p => p.status === "ACTIVE")[i % personnel.filter(p => p.status === "ACTIVE").length]?.id;

      if (!authorId) continue;

      await prisma.jobNote.create({
        data: {
          jobId: job.id,
          authorType: isAdminNote ? "ALT_ADMIN" : "PERSONNEL",
          adminAuthorId: isAdminNote ? authorId : undefined,
          personnelAuthorId: !isAdminNote ? authorId : undefined,
          content: `Not ${j + 1}: ${isAdminNote ? "Admin notu" : "Personel notu"} - ${job.title}`,
        },
      });
      noteCount++;
    }
  }

  console.log(`✅ Created ${noteCount} job notes`);
  return noteCount;
}

async function seedInventoryTransactions(adminId: string, jobs: any[], inventoryItems: any[]) {
  console.log("\n🔄 Seeding Inventory Transactions...");
  let transactionCount = 0;

  // Delivered jobs için material kullanımı
  const deliveredJobs = jobs.filter(j => j.status === "DELIVERED" || j.status === "ARCHIVED");

  for (const job of deliveredJobs.slice(0, 10)) {
    const materialCount = 1 + (transactionCount % 3); // 1-3 material per job

    for (let i = 0; i < materialCount; i++) {
      const item = inventoryItems[transactionCount % inventoryItems.length];
      const quantity = 1 + (transactionCount % 5);

      // JobMaterial oluştur
      await prisma.jobMaterial.create({
        data: {
          jobId: job.id,
          inventoryItemId: item.id,
          quantity,
          unitPrice: item.unitPrice,
        },
      });

      // InventoryTransaction oluştur
      await prisma.inventoryTransaction.create({
        data: {
          inventoryItemId: item.id,
          type: "OUTBOUND",
          quantity,
          jobId: job.id,
          note: `Job ${job.id.substring(0, 8)}... için kullanıldı`,
        },
      });

      transactionCount++;
    }
  }

  // Bazı inbound transactions (stok girişi)
  for (let i = 0; i < 5; i++) {
    const item = inventoryItems[i % inventoryItems.length];
    const quantity = 10 + (i * 5);

    await prisma.inventoryTransaction.create({
      data: {
        inventoryItemId: item.id,
        type: "INBOUND",
        quantity,
        note: `Stok girişi - ${item.name}`,
      },
    });

    transactionCount++;
  }

  console.log(`✅ Created ${transactionCount} inventory transactions`);
  return transactionCount;
}

async function seedLocationLogs(jobs: any[], personnel: any[]) {
  console.log("\n🔄 Seeding Location Logs...");
  let logCount = 0;

  const activeJobs = jobs.filter(j => j.status === "IN_PROGRESS" || j.status === "DELIVERED");

  for (const job of activeJobs.slice(0, 10)) {
    const jobPersonnel = await prisma.jobPersonnel.findMany({
      where: { jobId: job.id },
    });

    for (const assignment of jobPersonnel) {
      const location = job.location as any;
      const startedAt = assignment.startedAt || job.startedAt || new Date();

      await prisma.locationLog.create({
        data: {
          jobId: job.id,
          personnelId: assignment.personnelId,
          lat: (location.latitude || 39.9334) + (Math.random() - 0.5) * 0.01,
          lng: (location.longitude || 32.8597) + (Math.random() - 0.5) * 0.01,
          startedAt,
          endedAt: assignment.deliveredAt || undefined,
          consent: true,
        },
      });
      logCount++;
    }
  }

  console.log(`✅ Created ${logCount} location logs`);
  return logCount;
}

async function main() {
  console.log("🚀 Starting full database seed...\n");

  try {
    // 1. Admin kontrolü
    const adminId = await ensureAdmin();

    // 2. Personnel
    const personnel = await seedPersonnel(adminId);

    // 3. Customers
    const customers = await seedCustomers(adminId);

    // 4. Inventory
    const inventoryItems = await seedInventory(adminId);

    // 5. Jobs
    const jobs = await seedJobs(adminId, customers, personnel);

    // 6. Maintenance Reminders
    await seedMaintenanceReminders(adminId, jobs);

    // 7. Job Notes
    await seedJobNotes(adminId, jobs, personnel);

    // 8. Inventory Transactions
    await seedInventoryTransactions(adminId, jobs, inventoryItems);

    // 9. Location Logs
    await seedLocationLogs(jobs, personnel);

    console.log("\n✅ Full database seed completed successfully!");
    console.log("\n📊 Summary:");
    console.log(`  - Admin: 1`);
    console.log(`  - Personnel: ${personnel.length}`);
    console.log(`  - Customers: ${customers.length}`);
    console.log(`  - Inventory Items: ${inventoryItems.length}`);
    console.log(`  - Jobs: ${jobs.length}`);
  } catch (error) {
    console.error("\n❌ Seed failed:", error);
    throw error;
  }
}

main()
  .catch((error) => {
    console.error("Fatal error:", error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

