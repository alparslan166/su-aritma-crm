# AAB Build Rehberi - Google Play için

## ✅ Ön Hazırlık Kontrolü

- [x] Version: `1.0.3+2` (version code: 2)
- [x] Keystore: `apps/mobile/android/app/upload-keystore.jks`
- [x] Key Properties: `apps/mobile/android/key.properties`
- [ ] Railway Backend URL: Kontrol edin

## 📋 AAB Build Adımları

### 1. Railway Backend URL'ini Bulun

Railway dashboard'unda backend servisinizin public URL'ini bulun:
- **Settings** → **Networking** → **Public Domain**
- URL formatı: `https://your-service-name.railway.app`

**Örnek:** `https://su-aritma-crm-production-5d49.up.railway.app`

### 2. Flutter Dependencies Güncelle

```bash
cd apps/mobile
flutter pub get
```

### 3. AAB Build Komutu

```bash
cd apps/mobile

flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://su-aritma-crm-production-5d49.up.railway.app/api
```

**ÖNEMLİ:** Railway URL'inizi yukarıdaki komutta değiştirin!

### 4. AAB Dosyası Konumu

Build tamamlandıktan sonra AAB dosyası şurada olacak:

```
apps/mobile/build/app/outputs/bundle/release/app-release.aab
```

## 🔐 Keystore Bilgileri

- **Keystore:** `apps/mobile/android/app/upload-keystore.jks`
- **Alias:** `upload`
- **Store Password:** `asdfgh`
- **Key Password:** `asdfgh`

## ⚠️ Önemli Notlar

1. **30 Kasım 15:15 UTC'ye kadar bekleyin** (Upload key reset onayı sonrası)
2. **Version code her yayında artırılmalı** (şu an: 2)
3. **Railway URL'ini doğru girin** (sonuna `/api` ekleyin)
4. **Keystore dosyasını güvenli saklayın!**

## 🚀 Google Play Console'a Yükleme

1. **Google Play Console** → **Test edin ve yayınlayın** → **Üretim**
2. **"Yeni sürüm oluştur"** (Create new release)
3. **AAB dosyasını yükleyin**: `app-release.aab`
4. **Sürüm notları** ekleyin (örn: "İlk production release")
5. **Yayınla** (Release)

## 🐛 Hata Çözümleri

### Keystore Bulunamadı
```bash
# Keystore'un doğru yerde olduğundan emin olun
ls -la apps/mobile/android/app/upload-keystore.jks
```

### Version Code Hatası
```yaml
# pubspec.yaml'da version code'u artırın
version: 1.0.3+3  # +3, +4, +5...
```

### Build Hatası
```bash
# Flutter clean yapın
flutter clean
flutter pub get
flutter build appbundle --release --dart-define=API_BASE_URL=...
```

## 📝 Build Log Kontrolü

Build sırasında şu mesajları görmelisiniz:
- ✅ `Running Gradle task 'bundleRelease'...`
- ✅ `Built build/app/outputs/bundle/release/app-release.aab`

