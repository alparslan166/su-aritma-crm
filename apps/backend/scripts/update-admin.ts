/* eslint-disable @typescript-eslint/no-unsafe-assignment, @typescript-eslint/no-unsafe-member-access, @typescript-eslint/no-unsafe-call */
import bcrypt from "bcryptjs";

import { prisma } from "../src/lib/prisma";

// TypeScript için process tanımı
declare const process: {
  argv: string[];
  exit: (code: number) => never;
};

async function main() {
  // Komut satırı argümanlarını al
  const args = process.argv.slice(2);
  const emailArg = args.find((arg) => arg.startsWith("--email="));
  const email = emailArg ? emailArg.split("=")[1] : null;

  // Eğer email verilmediyse, tüm adminleri listele
  if (!email) {
    console.log("📋 Mevcut Adminler:\n");
    const admins = await prisma.admin.findMany({
      select: {
        id: true,
        name: true,
        email: true,
        phone: true,
        role: true,
        status: true,
        companyName: true,
      },
      orderBy: { createdAt: "desc" },
    });

    if (admins.length === 0) {
      console.log("   Henüz admin bulunmuyor.\n");
      console.log("💡 Yeni admin eklemek için:");
      console.log("   npm run seed:add-admin\n");
      return;
    }

    admins.forEach((admin, index) => {
      console.log(`   ${index + 1}. ${admin.name}`);
      console.log(`      Email: ${admin.email}`);
      console.log(`      Telefon: ${admin.phone}`);
      console.log(`      Rol: ${admin.role}`);
      console.log(`      Durum: ${admin.status}`);
      console.log(`      Firma: ${admin.companyName || "Belirtilmemiş"}`);
      console.log("");
    });

    console.log("💡 Admin güncellemek için:");
    console.log("   npm run seed:update-admin -- --email=admin@example.com\n");
    console.log("📝 Güncellenecek alanlar:");
    console.log('   --name="Yeni Ad"');
    console.log('   --phone="+90 555 123 45 67"');
    console.log('   --password="yenişifre"');
    console.log('   --companyName="Firma Adı"');
    console.log('   --companyAddress="Adres"');
    console.log('   --taxOffice="Vergi Dairesi"');
    console.log('   --taxNumber="Vergi No"\n');
    return;
  }

  // Email ile admini bul
  const existingAdmin = await prisma.admin.findFirst({
    where: { email },
  });

  if (!existingAdmin) {
    console.error(`❌ Email '${email}' ile admin bulunamadı!`);
    console.log("\n💡 Mevcut adminleri görmek için:");
    console.log("   npm run seed:update-admin\n");
    // eslint-disable-next-line no-process-exit
    process.exit(1);
    return; // TypeScript için unreachable code
  }

  console.log(`\n📝 Admin bulundu: ${existingAdmin.name} (${existingAdmin.email})\n`);

  // Güncellenecek verileri komut satırından al
  const nameArg = args.find((arg) => arg.startsWith("--name="));
  const phoneArg = args.find((arg) => arg.startsWith("--phone="));
  const passwordArg = args.find((arg) => arg.startsWith("--password="));
  const companyNameArg = args.find((arg) => arg.startsWith("--companyName="));
  const companyAddressArg = args.find((arg) => arg.startsWith("--companyAddress="));
  const companyPhoneArg = args.find((arg) => arg.startsWith("--companyPhone="));
  const companyEmailArg = args.find((arg) => arg.startsWith("--companyEmail="));
  const taxOfficeArg = args.find((arg) => arg.startsWith("--taxOffice="));
  const taxNumberArg = args.find((arg) => arg.startsWith("--taxNumber="));
  const roleArg = args.find((arg) => arg.startsWith("--role="));

  // Güncelleme verilerini hazırla
  const updateData: any = {};

  if (nameArg) {
    updateData.name = nameArg.split("=")[1].replace(/^"|"$/g, "");
    console.log(`   ✓ Ad: ${updateData.name}`);
  }

  if (phoneArg) {
    updateData.phone = phoneArg.split("=")[1].replace(/^"|"$/g, "");
    console.log(`   ✓ Telefon: ${updateData.phone}`);
  }

  if (passwordArg) {
    const password = passwordArg.split("=")[1].replace(/^"|"$/g, "");
    updateData.passwordHash = await bcrypt.hash(password, 12);
    console.log(`   ✓ Şifre: Güncellendi`);
  }

  if (roleArg) {
    const role = roleArg.split("=")[1].replace(/^"|"$/g, "");
    if (role === "ANA" || role === "ALT") {
      updateData.role = role;
      console.log(`   ✓ Rol: ${role}`);
    } else {
      console.log(`   ⚠️  Geçersiz rol: ${role} (ANA veya ALT olmalı)`);
    }
  }

  if (companyNameArg) {
    updateData.companyName = companyNameArg.split("=")[1].replace(/^"|"$/g, "");
    console.log(`   ✓ Firma Adı: ${updateData.companyName}`);
  }

  if (companyAddressArg) {
    updateData.companyAddress = companyAddressArg.split("=")[1].replace(/^"|"$/g, "");
    console.log(`   ✓ Firma Adresi: ${updateData.companyAddress}`);
  }

  if (companyPhoneArg) {
    updateData.companyPhone = companyPhoneArg.split("=")[1].replace(/^"|"$/g, "");
    console.log(`   ✓ Firma Telefonu: ${updateData.companyPhone}`);
  }

  if (companyEmailArg) {
    updateData.companyEmail = companyEmailArg.split("=")[1].replace(/^"|"$/g, "");
    console.log(`   ✓ Firma Email: ${updateData.companyEmail}`);
  }

  if (taxOfficeArg) {
    updateData.taxOffice = taxOfficeArg.split("=")[1].replace(/^"|"$/g, "");
    console.log(`   ✓ Vergi Dairesi: ${updateData.taxOffice}`);
  }

  if (taxNumberArg) {
    updateData.taxNumber = taxNumberArg.split("=")[1].replace(/^"|"$/g, "");
    console.log(`   ✓ Vergi No: ${updateData.taxNumber}`);
  }

  // Eğer güncellenecek bir şey yoksa
  if (Object.keys(updateData).length === 0) {
    console.log("\n⚠️  Güncellenecek veri belirtilmedi!");
    console.log("\n💡 Örnek kullanım:");
    console.log(
      `   npm run seed:update-admin -- --email=${email} --name="Yeni Ad" --password="yenişifre"\n`,
    );
    return;
  }

  // Admini güncelle
  const updatedAdmin = await prisma.admin.update({
    where: { id: existingAdmin.id },
    data: updateData,
  });

  console.log("\n✅ Admin başarıyla güncellendi!");
  console.log("\n📋 Güncel Admin Bilgileri:");
  console.log(`   ID: ${updatedAdmin.id}`);
  console.log(`   Ad: ${updatedAdmin.name}`);
  console.log(`   Email: ${updatedAdmin.email}`);
  console.log(`   Telefon: ${updatedAdmin.phone}`);
  console.log(`   Rol: ${updatedAdmin.role}`);
  console.log(`   Firma Adı: ${updatedAdmin.companyName || "Belirtilmemiş"}`);
  console.log(`   Firma Adresi: ${updatedAdmin.companyAddress || "Belirtilmemiş"}`);
  console.log(`   Vergi Dairesi: ${updatedAdmin.taxOffice || "Belirtilmemiş"}`);
  console.log(`   Vergi No: ${updatedAdmin.taxNumber || "Belirtilmemiş"}`);
  if (passwordArg) {
    console.log(`\n🔐 Yeni Şifre: ${passwordArg.split("=")[1].replace(/^"|"$/g, "")}`);
  }
}

main()
  .catch((error) => {
    console.error("❌ Admin güncellenirken hata oluştu:", error);
    // eslint-disable-next-line no-process-exit
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
