#!/usr/bin/env node

/**
 * APK dosyasını backend/public/apk/ klasörüne kopyalar
 *
 * Kullanım:
 *   npm run copy:apk
 *   veya
 *   ts-node scripts/copy-apk.ts [apk-path]
 */

import * as fs from "fs";
import * as path from "path";

const APK_SOURCE =
  process.argv[2] ||
  path.join(__dirname, "../../../mobile/build/app/outputs/flutter-apk/app-release.apk");
const APK_DEST = path.join(__dirname, "../../public/apk/app-release.apk");

async function copyApk() {
  try {
    // Source dosyasının varlığını kontrol et
    if (!fs.existsSync(APK_SOURCE)) {
      console.error(`❌ APK dosyası bulunamadı: ${APK_SOURCE}`);
      console.log("\n💡 Önce APK build yapın:");
      console.log("   cd apps/mobile");
      console.log(
        "   flutter build apk --release --dart-define=API_BASE_URL=https://su-aritma-crm-production.up.railway.app/api",
      );
      process.exit(1);
    }

    // Destination klasörünü oluştur
    const destDir = path.dirname(APK_DEST);
    if (!fs.existsSync(destDir)) {
      fs.mkdirSync(destDir, { recursive: true });
    }

    // Dosyayı kopyala
    fs.copyFileSync(APK_SOURCE, APK_DEST);

    const stats = fs.statSync(APK_DEST);
    const sizeInMB = (stats.size / (1024 * 1024)).toFixed(2);

    console.log("✅ APK başarıyla kopyalandı!");
    console.log(`   Kaynak: ${APK_SOURCE}`);
    console.log(`   Hedef:  ${APK_DEST}`);
    console.log(`   Boyut:  ${sizeInMB} MB`);
    console.log("\n🌐 APK artık şu adresten indirilebilir:");
    console.log("   https://su-aritma-crm-production.up.railway.app/download/apk/app-release.apk");
    console.log("\n📱 Ana sayfa:");
    console.log("   https://su-aritma-crm-production.up.railway.app/");
  } catch (error) {
    console.error("❌ APK kopyalanırken hata oluştu:", error);
    process.exit(1);
  }
}

copyApk();
