# APK Oluşturma Rehberi

## 🚀 Hızlı Başlangıç

### Production APK Oluşturma

```bash
cd apps/mobile
flutter build apk --release \
  --dart-define=API_BASE_URL=https://su-aritma-crm-production-5d49.up.railway.app/api
```

## 📍 APK Dosya Konumu

Build tamamlandıktan sonra APK dosyası şu konumda olacak:

```
apps/mobile/build/app/outputs/flutter-apk/app-release.apk
```

## 📱 Cihaza Yükleme

### Yöntem 1: ADB ile (USB/Emülatör)

```bash
adb install apps/mobile/build/app/outputs/flutter-apk/app-release.apk
```

### Yöntem 2: Dosya Transferi

1. APK dosyasını cihaza kopyalayın (USB, email, cloud storage)
2. Android'de: **Ayarlar > Güvenlik > Bilinmeyen Kaynaklardan Yükleme** → Açın
3. APK dosyasına dokunun ve yükleyin

## ⚙️ Diğer Seçenekler

### Split APK (Daha Küçük Dosyalar)

```bash
flutter build apk --split-per-abi --release \
  --dart-define=API_BASE_URL=https://su-aritma-crm-production-5d49.up.railway.app/api
```

Her mimari için ayrı APK oluşturur:
- `app-armeabi-v7a-release.apk` (32-bit)
- `app-arm64-v8a-release.apk` (64-bit)
- `app-x86_64-release.apk` (x86)

### Temiz Build

```bash
flutter clean
flutter build apk --release \
  --dart-define=API_BASE_URL=https://su-aritma-crm-production-5d49.up.railway.app/api
```

## 📝 Notlar

- **APK Boyutu**: Genellikle 30-50 MB
- **Backend URL**: Railway production URL kullanılıyor
- **Signing**: Release APK otomatik olarak imzalanır (keystore ile)

## ⚠️ Önemli: Backend vs Frontend Değişiklikleri

**Backend Deploy:**
- ✅ Mevcut APK'lar otomatik olarak yeni backend'i kullanır
- ✅ Yeni APK build etmeye gerek yok

**Frontend Değişiklikleri:**
- ❌ Yeni APK build edilmeli
- ❌ Kullanıcılar yeni APK'yı yüklemeli

Detaylı bilgi için: `DEPLOY_VE_APK_DEGISIKLIKLERI.md`

