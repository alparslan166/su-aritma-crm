import { prisma } from "../src/lib/prisma";

async function getPersonnelLogin() {
  try {
    // İlk aktif personeli bul
    const personnel = await prisma.personnel.findFirst({
      where: { status: "ACTIVE" },
      select: {
        id: true,
        name: true,
        loginCode: true,
        phone: true,
        status: true,
      },
      orderBy: { createdAt: "desc" },
    });

    if (!personnel) {
      console.log("❌ Aktif personel bulunamadı.");
      return;
    }

    console.log("\n✅ Personel Giriş Bilgileri:");
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log(`👤 İsim: ${personnel.name}`);
    console.log(`📱 Telefon: ${personnel.phone}`);
    console.log(`🆔 Personel ID: ${personnel.id}`);
    console.log(`🔑 Giriş Kodu: ${personnel.loginCode}`);
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("\n📝 Giriş için kullanın:");
    console.log(`   ID: ${personnel.id}`);
    console.log(`   Şifre: ${personnel.loginCode}`);
    console.log("\n");
  } catch (error) {
    console.error("❌ Hata:", error);
  } finally {
    await prisma.$disconnect();
  }
}

getPersonnelLogin();

