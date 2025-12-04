import { prisma } from "../src/lib/prisma";
import { SubscriptionService } from "../src/modules/subscriptions/subscription.service";

const subscriptionService = new SubscriptionService();

async function createSubscriptionsForAdmins() {
  console.log("🔄 Creating subscriptions for ALT admins without subscription...\n");

  // Find all ALT admins without subscription
  const admins = await prisma.admin.findMany({
    where: {
      role: "ALT",
      subscription: null,
    },
    select: {
      id: true,
      name: true,
      email: true,
      createdAt: true,
    },
  });

  if (admins.length === 0) {
    console.log("✅ All ALT admins already have subscriptions!");
    return;
  }

  console.log(`📋 Found ${admins.length} ALT admin(s) without subscription:\n`);

  let successCount = 0;
  let errorCount = 0;

  for (const admin of admins) {
    try {
      await subscriptionService.startTrial(admin.id);
      console.log(`✅ Created trial subscription for: ${admin.name} (${admin.email})`);
      successCount++;
    } catch (error: any) {
      console.error(
        `❌ Failed to create subscription for ${admin.name}: ${error.message}`,
      );
      errorCount++;
    }
  }

  console.log("\n📊 Summary:");
  console.log(`   ✅ Success: ${successCount}`);
  console.log(`   ❌ Errors: ${errorCount}`);
  console.log(`   📝 Total: ${admins.length}`);
}

createSubscriptionsForAdmins()
  .catch((error) => {
    console.error("❌ Fatal error:", error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

