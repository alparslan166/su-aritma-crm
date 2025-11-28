/* eslint-disable @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-member-access, @typescript-eslint/no-unsafe-call */
import bcrypt from "bcryptjs";

import { prisma } from "../src/lib/prisma";

// TypeScript için process tanımı
declare const process: {
  exit: (code: number) => never;
};

async function main() {
  // Yeni admin bilgileri
  const adminData = {
    name: "Test Admin",
    phone: "+90 555 123 45 67",
    email: "test@suaritma.com",
    role: "ALT" as const,
    password: "1234",
    companyName: "Test Su Arıtma Ltd.",
    companyAddress: "İstanbul, Türkiye",
    companyPhone: "+90 212 555 00 00",
    companyEmail: "info@testsuaritma.com",
    taxOffice: "Kadıköy",
    taxNumber: "1234567890",
  };

  // Şifreyi hash'le
  const passwordHash = await bcrypt.hash(adminData.password, 12);

  // Önce email ile kontrol et
  const existingAdmin = await prisma.admin.findFirst({
    where: { email: adminData.email },
  });

  let admin;
  if (existingAdmin) {
    // Varsa güncelle
    admin = await prisma.admin.update({
      where: { id: existingAdmin.id },
      data: {
        name: adminData.name,
        phone: adminData.phone,
        role: adminData.role,
        passwordHash: passwordHash,
        companyName: adminData.companyName,
        companyAddress: adminData.companyAddress,
        companyPhone: adminData.companyPhone,
        companyEmail: adminData.companyEmail,
        taxOffice: adminData.taxOffice,
        taxNumber: adminData.taxNumber,
        updatedAt: new Date(),
      },
    });
    console.log("📝 Mevcut admin güncellendi!");
  } else {
    // Yoksa oluştur
    admin = await prisma.admin.create({
      data: {
        name: adminData.name,
        phone: adminData.phone,
        email: adminData.email,
        role: adminData.role,
        status: "active",
        passwordHash: passwordHash,
        companyName: adminData.companyName,
        companyAddress: adminData.companyAddress,
        companyPhone: adminData.companyPhone,
        companyEmail: adminData.companyEmail,
        taxOffice: adminData.taxOffice,
        taxNumber: adminData.taxNumber,
      },
    });
    console.log("✨ Yeni admin oluşturuldu!");
  }

  console.log("\n✅ Admin başarıyla oluşturuldu/güncellendi!");
  console.log("📋 Admin Bilgileri:");
  console.log(`   ID: ${admin.id}`);
  console.log(`   Ad: ${admin.name}`);
  console.log(`   Email: ${admin.email}`);
  console.log(`   Telefon: ${admin.phone}`);
  console.log(`   Rol: ${admin.role}`);
  console.log(`   Şifre: ${adminData.password}`);
  console.log(`   Firma Adı: ${admin.companyName}`);
  console.log(`   Firma Adresi: ${admin.companyAddress}`);
  console.log(`   Vergi Dairesi: ${admin.taxOffice}`);
  console.log(`   Vergi No: ${admin.taxNumber}`);
  console.log("\n🔐 Giriş bilgileri:");
  console.log(`   Email: ${admin.email}`);
  console.log(`   Şifre: ${adminData.password}`);
}

main()
  .catch((error) => {
    console.error("❌ Admin eklenirken hata oluştu:", error);
    // eslint-disable-next-line no-process-exit
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
