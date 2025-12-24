/**
 * Migration Script: Create Missing Subscriptions
 *
 * This script creates 30-day trial subscriptions for existing admins
 * who don't have a subscription record.
 *
 * Run with:
 *   npx ts-node -r tsconfig-paths/register scripts/create-missing-subscriptions.ts
 *
 * Or if you have script configured in package.json:
 *   npm run script:create-subscriptions
 */

import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  console.log("🔍 Finding admins without subscriptions...\n");

  // Find all admins
  const admins = await prisma.admin.findMany({
    select: {
      id: true,
      name: true,
      email: true,
      role: true,
      createdAt: true,
      subscription: true,
    },
  });

  const adminsWithoutSubscription = admins.filter((admin) => !admin.subscription);

  if (adminsWithoutSubscription.length === 0) {
    console.log("✅ All admins already have subscriptions. Nothing to do.\n");
    return;
  }

  console.log(`📋 Found ${adminsWithoutSubscription.length} admin(s) without subscription:\n`);

  for (const admin of adminsWithoutSubscription) {
    console.log(`  - ${admin.name} (${admin.email}) - Role: ${admin.role}`);
  }

  console.log("\n🚀 Creating 30-day trial subscriptions...\n");

  const now = new Date();

  for (const admin of adminsWithoutSubscription) {
    const trialEnds = new Date(now);
    trialEnds.setDate(trialEnds.getDate() + 30); // 30 days from now

    try {
      await prisma.subscription.create({
        data: {
          adminId: admin.id,
          planType: "monthly",
          status: "trial",
          startDate: now,
          endDate: trialEnds,
          trialEnds,
        },
      });

      console.log(`  ✅ Created trial for: ${admin.name} (${admin.email})`);
      console.log(`     Trial ends: ${trialEnds.toISOString().split("T")[0]}`);
    } catch (error) {
      console.error(`  ❌ Failed to create subscription for ${admin.name}:`, error);
    }
  }

  console.log("\n🎉 Done! All missing subscriptions have been created.\n");
}

main()
  .catch((e) => {
    console.error("❌ Script failed:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
