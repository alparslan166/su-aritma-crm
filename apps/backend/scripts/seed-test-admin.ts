import bcrypt from "bcryptjs";

import { prisma } from "../src/lib/prisma";

async function main() {
  const adminId = "ALT-ADMIN-QA";
  const password = "1234";
  const hash = await bcrypt.hash(password, 12);

  await prisma.admin.upsert({
    where: { id: adminId },
    update: {
      name: "QA Alt Admin",
      phone: "+90 555 444 33 22",
      email: "qa.alt@suaritma.com",
      role: "ALT",
      status: "active",
      passwordHash: hash,
      updatedAt: new Date(),
    },
    create: {
      id: adminId,
      name: "QA Alt Admin",
      phone: "+90 555 444 33 22",
      email: "qa.alt@suaritma.com",
      role: "ALT",
      status: "active",
      passwordHash: hash,
    },
  });

  // eslint-disable-next-line no-console
  console.log(`Seeded admin ${adminId} with password ${password}`);
}

main()
  .catch((error) => {
    // eslint-disable-next-line no-console
    console.error("Failed to seed admin:", error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

