# Google Play Store Yayın Checklist

Bu dokümantasyon, uygulamanın Google Play Store'a yayınlanması için yapılması gerekenleri listeler.

## ❌ Kritik Eksikler (Yapılması Zorunlu)

### 1. Application ID Değiştirilmeli
- **Mevcut**: `com.example.mobile`
- **Değişmeli**: `com.yourcompany.suaritma` (veya benzeri)
- **Dosya**: `android/app/build.gradle.kts`
- **Not**: Application ID bir kez yayınlandıktan sonra değiştirilemez!

### 2. App İsmi Değiştirilmeli
- **Mevcut**: "mobile"
- **Değişmeli**: "Su Arıtma" veya uygun bir isim
- **Dosya**: `android/app/src/main/AndroidManifest.xml`

### 3. Production Signing Config
- **Mevcut**: Debug keys kullanılıyor
- **Gerekli**: Production signing key oluşturulmalı
- **Dosya**: `android/app/build.gradle.kts`

### 4. Android Permissions Eksik
- **Eksik**: INTERNET, LOCATION, CAMERA, STORAGE permissions
- **Dosya**: `android/app/src/main/AndroidManifest.xml`

### 5. Production API URL
- **Mevcut**: `http://localhost:4000/api` (default)
- **Gerekli**: Railway production URL
- **Dosya**: Build komutunda `--dart-define` ile

### 6. Logger Production'da Kapatılmalı
- **Mevcut**: PrettyDioLogger her zaman aktif
- **Gerekli**: Production'da kapatılmalı
- **Dosya**: `lib/core/network/api_client.dart`

## ⚠️ Önemli Kontroller

### 7. Version Code/Name
- **Mevcut**: `1.0.0+1` ✅ (Uygun)
- **Not**: Her yayında versionCode artırılmalı

### 8. Min/Target SDK
- Kontrol edilmeli: Min SDK 21+ olmalı
- Target SDK en güncel olmalı

### 9. ProGuard/R8 Rules
- Release build için obfuscation kuralları kontrol edilmeli

### 10. App Icons
- Tüm density'ler için icon'lar mevcut mu kontrol edilmeli

## 📋 Google Play Console Gereksinimleri

### 11. Privacy Policy
- Privacy policy URL'i gerekli
- Veri toplama ve kullanımı açıklanmalı

### 12. Content Rating
- IARC veya benzeri rating alınmalı

### 13. App Screenshots
- Phone (en az 2)
- Tablet (opsiyonel)
- Feature graphic (1024x500)

### 14. App Description
- Kısa açıklama (80 karakter)
- Uzun açıklama (4000 karakter)

### 15. Store Listing
- App icon (512x512)
- Feature graphic (1024x500)

## 🔧 Yapılacak Değişiklikler

Aşağıdaki dosyalarda değişiklikler yapılacak:

1. `android/app/build.gradle.kts` - Application ID, signing config
2. `android/app/src/main/AndroidManifest.xml` - App name, permissions
3. `lib/core/network/api_client.dart` - Logger production kontrolü
4. Build script - Production API URL

## 🚀 Production Build Komutu

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://your-railway-app.railway.app/api
```

## ⚡ Hızlı Düzeltme Öncelikleri

1. **Application ID değiştir** (en kritik - değiştirilemez!)
2. **Signing config ekle** (production key)
3. **Permissions ekle** (uygulama çalışmaz)
4. **API URL production'a ayarla**
5. **Logger production'da kapat**

