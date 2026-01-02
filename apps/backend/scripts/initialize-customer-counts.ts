import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  console.log("🔄 Initializing customerCount for all admins...\n");

  // Get all admins
  const admins = await prisma.admin.findMany({
    select: { id: true, email: true },
  });

  console.log(`Found ${admins.length} admins\n`);

  for (const admin of admins) {
    // Count unique customers for this admin (by name+phone combination)
    const customers = await prisma.customer.findMany({
      where: { adminId: admin.id },
      select: { id: true, name: true, phone: true },
    });

    // Deduplicate by name+phone combination
    const seenNamePhone = new Set<string>();
    let uniqueCount = 0;

    for (const customer of customers) {
      const key = `${customer.name.toLowerCase().trim()}_${customer.phone.replace(/\s+/g, "")}`;
      if (!seenNamePhone.has(key)) {
        seenNamePhone.add(key);
        uniqueCount++;
      }
    }

    // Update admin's customerCount
    await prisma.admin.update({
      where: { id: admin.id },
      data: { customerCount: uniqueCount },
    });

    console.log(`✅ Admin: ${admin.email} - customerCount: ${uniqueCount}`);
  }

  console.log("\n🎉 Done! All admin customerCounts have been initialized.");
}

main()
  .catch((e) => {
    console.error("❌ Error:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
