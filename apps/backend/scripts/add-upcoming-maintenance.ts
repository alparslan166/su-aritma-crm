import { prisma } from "../src/lib/prisma";

const ADMIN_ID = "ALT-ADMIN-QA";

async function addUpcomingMaintenance() {
  console.log("🔄 Adding customers with upcoming maintenance...\n");

  try {
    // Mevcut personel listesini al
    const personnel = await prisma.personnel.findMany({
      where: { adminId: ADMIN_ID, status: "ACTIVE" },
      take: 3,
    });

    if (personnel.length === 0) {
      console.log("❌ No active personnel found. Please run seed-full.ts first.");
      return;
    }

    const now = new Date();
    const customerNames = [
      { name: "Yaklaşan Bakım Müşteri 1", city: "İstanbul", district: "Beşiktaş" },
      { name: "Yaklaşan Bakım Müşteri 2", city: "Ankara", district: "Çankaya" },
      { name: "Yaklaşan Bakım Müşteri 3", city: "İzmir", district: "Konak" },
      { name: "Yaklaşan Bakım Müşteri 4", city: "Bursa", district: "Nilüfer" },
      { name: "Yaklaşan Bakım Müşteri 5", city: "Antalya", district: "Muratpaşa" },
      { name: "Yaklaşan Bakım Müşteri 6", city: "Adana", district: "Seyhan" },
    ];

    const createdCustomers = [];

    for (let i = 0; i < customerNames.length; i++) {
      const customerData = customerNames[i];
      
      // Müşteri oluştur
      const customer = await prisma.customer.create({
        data: {
          adminId: ADMIN_ID,
          name: customerData.name,
          phone: `+90 555 ${100 + i} ${1000 + i}`,
          email: `bakim${i + 1}@example.com`,
          address: `${customerData.district}, ${customerData.city}`,
          location: {
            address: `${customerData.district}, ${customerData.city}`,
            latitude: 39.9334 + (Math.random() - 0.5) * 0.5,
            longitude: 32.8597 + (Math.random() - 0.5) * 0.5,
          },
          status: "ACTIVE",
        },
      });

      // Yaklaşan bakım tarihleri: 3-15 gün sonra
      const daysUntilMaintenance = 3 + (i * 2); // 3, 5, 7, 9, 11, 13 gün sonra
      const maintenanceDueAt = new Date(now);
      maintenanceDueAt.setDate(maintenanceDueAt.getDate() + daysUntilMaintenance);

      // Teslim edilmiş bir iş oluştur (bakım hatırlatıcısı için)
      const job = await prisma.job.create({
        data: {
          adminId: ADMIN_ID,
          customerId: customer.id,
          title: `Sistem Kurulumu - ${customer.name}`,
          status: "DELIVERED",
          location: customer.location as any,
          price: 2500 + (i * 200),
          paymentStatus: "PAID",
          notes: `Yaklaşan bakım: ${daysUntilMaintenance} gün sonra`,
          statusChangedAt: new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000), // 60 gün önce teslim edildi
          startedAt: new Date(now.getTime() - 62 * 24 * 60 * 60 * 1000),
          deliveredAt: new Date(now.getTime() - 60 * 24 * 60 * 60 * 1000),
          maintenanceDueAt,
          nextMaintenanceIntervalMonths: 6,
        },
      });

      // Personel ataması
      if (personnel.length > 0) {
        const assignedPersonnel = personnel[i % personnel.length];
        await prisma.jobPersonnel.create({
          data: {
            jobId: job.id,
            personnelId: assignedPersonnel.id,
            startedAt: job.startedAt || undefined,
            deliveredAt: job.deliveredAt || undefined,
          },
        });
      }

      // Job status history
      await prisma.jobStatusHistory.create({
        data: {
          jobId: job.id,
          status: "DELIVERED",
          note: "İş teslim edildi",
          changedByAdminId: ADMIN_ID,
        },
      });

      // Maintenance reminder oluştur
      let reminderStatus: "PENDING" | "SENT" = "PENDING";
      let sentAt: Date | null = null;
      let lastWindowNotified: "SEVEN_DAYS" | "THREE_DAYS" | "ONE_DAY" | null = null;
      let lastNotifiedAt: Date | null = null;

      if (daysUntilMaintenance <= 1) {
        reminderStatus = "SENT";
        sentAt = new Date(now.getTime() - 1 * 24 * 60 * 60 * 1000);
        lastNotifiedAt = sentAt;
        lastWindowNotified = "ONE_DAY";
      } else if (daysUntilMaintenance <= 3) {
        reminderStatus = "SENT";
        sentAt = new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000);
        lastNotifiedAt = sentAt;
        lastWindowNotified = "THREE_DAYS";
      } else if (daysUntilMaintenance <= 7) {
        reminderStatus = "SENT";
        sentAt = new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000);
        lastNotifiedAt = sentAt;
        lastWindowNotified = "SEVEN_DAYS";
      }

      await prisma.maintenanceReminder.create({
        data: {
          jobId: job.id,
          dueAt: maintenanceDueAt,
          status: reminderStatus,
          sentAt,
          lastWindowNotified,
          lastNotifiedAt,
        },
      });

      createdCustomers.push(customer);
      console.log(
        `  ✓ Created customer: ${customer.name} - Bakım ${daysUntilMaintenance} gün sonra (${maintenanceDueAt.toLocaleDateString("tr-TR")})`,
      );
    }

    console.log(`\n✅ Created ${createdCustomers.length} customers with upcoming maintenance`);
    return createdCustomers;
  } catch (error) {
    console.error("❌ Failed to add upcoming maintenance customers:", error);
    throw error;
  }
}

addUpcomingMaintenance()
  .catch((error) => {
    console.error("Fatal error:", error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

