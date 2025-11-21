import { prisma } from "../src/lib/prisma";

const ADMIN_ID = "ALT-ADMIN-QA";

const operations = [
  "filtre değişimi",
  "tank değişimi",
  "bakım",
  "servis",
  "arıza giderme",
  "membran değişimi",
  "sistem kurulumu",
  "periyodik bakım",
  "yerinde ölçüm / analiz",
  "cihaz taşınması",
];

async function main() {
  console.log("🔄 Adding operations to database...");

  // Check if admin exists
  const admin = await prisma.admin.findUnique({
    where: { id: ADMIN_ID },
  });

  if (!admin) {
    console.error(`❌ Admin with ID ${ADMIN_ID} not found`);
    process.exit(1);
  }

  console.log(`✅ Admin found: ${admin.name}`);

  // Check existing operations
  const existingOperations = await prisma.operation.findMany({
    where: { adminId: ADMIN_ID },
    select: { name: true },
  });

  const existingNames = new Set(existingOperations.map((op) => op.name.toLowerCase()));

  let added = 0;
  let skipped = 0;

  for (const operationName of operations) {
    if (existingNames.has(operationName.toLowerCase())) {
      console.log(`⏭️  Skipping "${operationName}" (already exists)`);
      skipped++;
      continue;
    }

    try {
      await prisma.operation.create({
        data: {
          adminId: ADMIN_ID,
          name: operationName,
          isActive: true,
        },
      });
      console.log(`✅ Added: "${operationName}"`);
      added++;
    } catch (error) {
      console.error(`❌ Error adding "${operationName}":`, error);
    }
  }

  console.log("\n📊 Summary:");
  console.log(`   ✅ Added: ${added}`);
  console.log(`   ⏭️  Skipped: ${skipped}`);
  console.log(`   📝 Total operations: ${operations.length}`);
}

main()
  .catch((error) => {
    console.error("❌ Error:", error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });


