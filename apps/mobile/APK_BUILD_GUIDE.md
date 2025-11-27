# APK Build Rehberi

Android cihazınıza direkt APK olarak yüklemek için bu rehberi kullanın.

## APK Build

### Production APK (Railway Backend)

```bash
cd apps/mobile
flutter build apk --release \
  --dart-define=API_BASE_URL=https://su-aritma-crm-production.up.railway.app/api
```

### Local Backend APK (Geliştirme)

```bash
cd apps/mobile
flutter build apk --release \
  --dart-define=API_BASE_URL=http://localhost:4000/api
```

**Not:** Android emülatör için `localhost` yerine `10.0.2.2` kullanın:
```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=http://10.0.2.2:4000/api
```

## APK Dosyasının Konumu

Build tamamlandıktan sonra APK dosyası şu konumda olacak:

```
apps/mobile/build/app/outputs/flutter-apk/app-release.apk
```

## Android Cihaza Yükleme

### Yöntem 1: ADB ile (USB veya Emülatör)

```bash
# Emülatöre yükleme
adb install apps/mobile/build/app/outputs/flutter-apk/app-release.apk

# Fiziksel cihaza yükleme (USB ile bağlı)
adb devices  # Cihazın bağlı olduğunu kontrol edin
adb install apps/mobile/build/app/outputs/flutter-apk/app-release.apk
```

### Yöntem 2: Dosya Transferi

1. APK dosyasını cihazınıza kopyalayın (USB, email, cloud storage, vs.)
2. Android cihazınızda **Ayarlar > Güvenlik > Bilinmeyen Kaynaklardan Uygulama Yükleme** seçeneğini etkinleştirin
3. APK dosyasına dokunun ve yükleme talimatlarını takip edin

### Yöntem 3: QR Kod ile

1. APK dosyasını bir web sunucusuna yükleyin veya bir dosya paylaşım servisi kullanın
2. QR kod oluşturun (APK'nın URL'si ile)
3. Android cihazınızda QR kodu tarayın ve indirin

## APK vs AAB (App Bundle)

- **APK**: Direkt yükleme için kullanılır. Google Play Store dışında dağıtım için idealdir.
- **AAB**: Google Play Store'a yüklemek için kullanılır. Google Play Store otomatik olarak cihaza uygun APK'ları oluşturur.

## Sorun Giderme

### "Uygulama yüklenemedi" Hatası

1. **Bilinmeyen kaynaklar**: Ayarlar > Güvenlik > Bilinmeyen Kaynaklardan Uygulama Yükleme'yi etkinleştirin
2. **Depolama izni**: Dosya yöneticisinin depolama izni olduğundan emin olun
3. **APK bozuk**: Build'i tekrar çalıştırın: `flutter clean && flutter build apk --release`

### "Uygulama yüklenemedi: Paket çözümlenemedi"

- APK dosyası bozuk olabilir
- Build'i temizleyip tekrar deneyin: `flutter clean && flutter build apk --release`

### ADB "device not found"

- USB debugging'in açık olduğundan emin olun (Ayarlar > Geliştirici Seçenekleri)
- USB kablosunu kontrol edin
- `adb devices` komutu ile cihazın göründüğünü doğrulayın

## APK Boyutu

Release APK genellikle 30-50 MB arası olur. Split APK (per-ABI) oluşturmak için:

```bash
flutter build apk --split-per-abi --release \
  --dart-define=API_BASE_URL=https://su-aritma-crm-production.up.railway.app/api
```

Bu komut her mimari için ayrı APK oluşturur (daha küçük dosyalar):
- `app-armeabi-v7a-release.apk` (32-bit ARM)
- `app-arm64-v8a-release.apk` (64-bit ARM)
- `app-x86_64-release.apk` (64-bit x86)

