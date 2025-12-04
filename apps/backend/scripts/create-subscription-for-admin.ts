import { prisma } from "../src/lib/prisma";
import { SubscriptionService } from "../src/modules/subscriptions/subscription.service";

const subscriptionService = new SubscriptionService();

// Admin ID'yi komut satırından al veya buraya yaz
const ADMIN_ID = process.argv[2];

if (!ADMIN_ID) {
  console.error("❌ Please provide admin ID as argument:");
  console.error("   npm run create:subscription <admin-id>");
  process.exit(1);
}

async function createSubscriptionForAdmin() {
  console.log(`🔄 Creating subscription for admin: ${ADMIN_ID}\n`);

  try {
    // Check if admin exists
    const admin = await prisma.admin.findUnique({
      where: { id: ADMIN_ID },
      select: {
        id: true,
        name: true,
        email: true,
        role: true,
        subscription: {
          select: { id: true },
        },
      },
    });

    if (!admin) {
      console.error(`❌ Admin with ID ${ADMIN_ID} not found!`);
      process.exit(1);
    }

    if (admin.role !== "ALT") {
      console.error(`❌ Admin ${admin.name} is not an ALT admin (role: ${admin.role})`);
      console.log("ℹ️  Only ALT admins need subscriptions");
      process.exit(1);
    }

    if (admin.subscription) {
      console.log(`⚠️  Admin ${admin.name} already has a subscription!`);
      process.exit(0);
    }

    // Create trial subscription
    await subscriptionService.startTrial(admin.id);
    console.log(`✅ Created 30-day trial subscription for: ${admin.name} (${admin.email})`);
  } catch (error: any) {
    console.error(`❌ Error: ${error.message}`);
    process.exit(1);
  }
}

createSubscriptionForAdmin()
  .catch((error) => {
    console.error("❌ Fatal error:", error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

