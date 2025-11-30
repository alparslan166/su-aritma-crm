import { PrismaClient } from "@prisma/client";
import { generateAdminId } from "../src/lib/generators";

const prisma = new PrismaClient();

async function generateAdminIds() {
  console.log("🔄 Generating admin IDs for existing admins...");

  const admins = await prisma.admin.findMany({
    where: {
      adminId: null,
    },
  });

  console.log(`📋 Found ${admins.length} admins without adminId`);

  for (const admin of admins) {
    try {
      const newAdminId = await generateAdminId();
      await prisma.admin.update({
        where: { id: admin.id },
        data: { adminId: newAdminId },
      });
      console.log(`✅ Updated ${admin.name} (${admin.email}) with adminId: ${newAdminId}`);
    } catch (error) {
      console.error(`❌ Failed to update ${admin.name}:`, error);
    }
  }

  console.log("✅ All admin IDs generated!");
}

generateAdminIds()
  .catch((error) => {
    console.error("Error:", error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

