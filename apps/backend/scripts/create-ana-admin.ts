import { prisma } from "../src/lib/prisma";
import bcrypt from "bcryptjs";

async function createAnaAdmin() {
  const email = process.argv[2] || "ana@admin.com";
  const password = process.argv[3] || "admin123";
  const name = process.argv[4] || "Ana Admin";

  console.log("🔄 Creating ANA admin account...\n");
  console.log(`Email: ${email}`);
  console.log(`Password: ${password}`);
  console.log(`Name: ${name}\n`);

  // Check if admin already exists
  const existingAdmin = await prisma.admin.findUnique({
    where: { email },
  });

  if (existingAdmin) {
    if (existingAdmin.role === "ANA") {
      console.log("✅ ANA admin already exists with this email.");
      console.log("   If you want to update the password, delete the admin first.");
      return;
    } else {
      console.log("⚠️  Admin exists but role is not ANA. Updating role...");
      const passwordHash = await bcrypt.hash(password, 12);
      await prisma.admin.update({
        where: { email },
        data: {
          role: "ANA",
          passwordHash,
          name,
        },
      });
      console.log("✅ Admin role updated to ANA and password updated.");
      return;
    }
  }

  // Create new ANA admin
  const passwordHash = await bcrypt.hash(password, 12);
  const admin = await prisma.admin.create({
    data: {
      email,
      passwordHash,
      name,
      phone: "+90 555 000 00 00", // Default phone, can be updated later
      role: "ANA",
      status: "active",
      emailVerified: true,
    },
  });

  console.log("✅ ANA admin created successfully!");
  console.log(`   ID: ${admin.id}`);
  console.log(`   Email: ${admin.email}`);
  console.log(`   Role: ${admin.role}`);
  console.log("\n💡 You can now login to the web admin panel with these credentials.");
}

createAnaAdmin()
  .catch((error) => {
    console.error("❌ Error creating ANA admin:", error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

