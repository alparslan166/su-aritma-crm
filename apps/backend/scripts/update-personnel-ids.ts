import { PrismaClient } from "@prisma/client";
import { generatePersonnelId } from "../src/lib/generators";

const prisma = new PrismaClient();

async function updatePersonnelIds() {
  console.log("🔄 Updating personnel IDs...");

  const personnels = await prisma.personnel.findMany({
    where: {
      personnelId: null,
    },
  });

  console.log(`📋 Found ${personnels.length} personnels without ID`);

  for (const personnel of personnels) {
    try {
      const personnelId = await generatePersonnelId();
      await prisma.personnel.update({
        where: { id: personnel.id },
        data: { personnelId },
      });
      console.log(`✅ Updated ${personnel.name} with ID: ${personnelId}`);
    } catch (error) {
      console.error(`❌ Failed to update ${personnel.name}:`, error);
    }
  }

  console.log("✅ All personnel IDs updated!");
}

updatePersonnelIds()
  .catch((error) => {
    console.error("Error:", error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

