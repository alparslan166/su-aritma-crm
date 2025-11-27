#!/usr/bin/env node

/**
 * Failed migration'ı resolve eder
 *
 * Kullanım:
 *   npm run resolve:migration
 *   veya
 *   ts-node scripts/resolve-failed-migration.ts
 */

import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function resolveFailedMigration() {
  try {
    console.log("🔄 Failed migration'ı resolve ediliyor...");

    // Failed migration'ı rolled_back olarak işaretle
    // Prisma migrate resolve komutunu kullanmak için exec kullanıyoruz
    const { execSync } = require("child_process");

    const migrationName = "20251118223050_name";

    console.log(`📝 Migration '${migrationName}' rolled_back olarak işaretleniyor...`);

    try {
      execSync(`npx prisma migrate resolve --rolled-back ${migrationName}`, {
        stdio: "inherit",
        env: process.env,
      });
      console.log("✅ Migration başarıyla resolve edildi!");
    } catch (error: any) {
      if (error.message.includes("not found")) {
        console.log("⚠️  Migration bulunamadı, manuel olarak database'den siliniyor...");

        // Manuel olarak _prisma_migrations tablosundan sil
        await prisma.$executeRawUnsafe(`
          DELETE FROM "_prisma_migrations" 
          WHERE migration_name = '${migrationName}';
        `);

        console.log("✅ Migration database'den silindi!");
      } else {
        throw error;
      }
    }

    console.log("\n✅ Failed migration resolve edildi!");
    console.log("💡 Şimdi Railway'de deploy tekrar deneyebilirsiniz.");
  } catch (error) {
    console.error("❌ Hata oluştu:", error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

resolveFailedMigration();
