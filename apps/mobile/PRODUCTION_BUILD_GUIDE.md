# Production Build ve Google Play Yayın Rehberi

Bu rehber, uygulamayı Google Play Store'a yayınlamak için gerekli adımları açıklar.

## ⚠️ ÖNEMLİ: Application ID

**Application ID bir kez yayınlandıktan sonra değiştirilemez!**

Şu anki Application ID: `com.suaritma.app`

Eğer farklı bir ID istiyorsanız, **yayınlamadan önce** `android/app/build.gradle.kts` dosyasında değiştirin.

Örnekler:
- `com.yourcompany.suaritma`
- `com.suaritma.mobile`
- `app.suaritma`

## 1. Production Signing Key Oluşturma

### Adım 1: Keytool ile keystore oluştur

```bash
cd apps/mobile/android/app
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Sorular:
- **Keystore password**: Güçlü bir şifre (unutmayın!)
- **Key password**: Aynı şifre veya farklı (unutmayın!)
- **Name**: İsim (örn: Su Arıtma)
- **Organizational Unit**: Departman (opsiyonel)
- **Organization**: Şirket adı
- **City**: Şehir
- **State**: Eyalet/İl
- **Country**: Ülke kodu (TR, US, vb.)

### Adım 2: key.properties dosyası oluştur

```bash
cd apps/mobile/android
cp key.properties.example key.properties
```

`key.properties` dosyasını düzenleyin:

```properties
storePassword=your-keystore-password
keyPassword=your-key-password
keyAlias=upload
storeFile=../upload-keystore.jks
```

### Adım 3: Güvenlik

```bash
# .gitignore'a ekleyin
echo "android/key.properties" >> .gitignore
echo "android/app/upload-keystore.jks" >> .gitignore
```

**ÖNEMLİ**: `upload-keystore.jks` ve `key.properties` dosyalarını güvenli bir yerde yedekleyin! Kaybederseniz uygulamayı güncelleyemezsiniz!

## 2. Application ID Kontrolü

`android/app/build.gradle.kts` dosyasında Application ID'yi kontrol edin:

```kotlin
applicationId = "com.suaritma.app"  // Kendi ID'nizi kullanın
```

## 3. Railway Backend URL'i

Production build'de Railway backend URL'inizi kullanın:

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://your-railway-app.railway.app/api
```

## 4. Production Build

### App Bundle (Google Play için önerilen)

```bash
cd apps/mobile
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://your-railway-app.railway.app/api
```

Çıktı: `build/app/outputs/bundle/release/app-release.aab`

### APK (Test için)

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://your-railway-app.railway.app/api
```

Çıktı: `build/app/outputs/flutter-apk/app-release.apk`

## 5. Google Play Console'a Yükleme

1. [Google Play Console](https://play.google.com/console) giriş yapın
2. Yeni uygulama oluşturun
3. **Production** > **Create new release**
4. `app-release.aab` dosyasını yükleyin
5. Release notes ekleyin
6. Review'a gönderin

## 6. Google Play Console Gereksinimleri

### Zorunlu Bilgiler

- ✅ **App name**: "Su Arıtma" (AndroidManifest'te ayarlandı)
- ✅ **App icon**: 512x512 PNG
- ✅ **Feature graphic**: 1024x500 PNG
- ✅ **Screenshots**: En az 2 adet (phone)
- ✅ **Short description**: 80 karakter
- ✅ **Full description**: 4000 karakter
- ✅ **Privacy Policy URL**: Gerekli (veri toplama varsa)
- ✅ **Content Rating**: IARC rating alınmalı

### App Content

- **Data Safety**: Veri toplama ve kullanımı açıklanmalı
- **Target Audience**: Yaş grubu belirtilmeli
- **Content Rating**: Uygunsuz içerik kontrolü

## 7. Test Etme

### Internal Testing

1. Google Play Console > Testing > Internal testing
2. Release oluştur ve testçi ekle
3. Test link'i paylaş

### Closed Testing

1. Testing > Closed testing
2. Beta testçiler ekle
3. Feedback topla

## 8. Production Release

Tüm kontroller tamamlandıktan sonra:

1. Production > Create new release
2. App bundle yükle
3. Release notes ekle
4. Review'a gönder

## Troubleshooting

### Signing Hatası

```
FAILURE: Build failed with an exception.
* What went wrong:
Execution failed for task ':app:signReleaseBundle'.
```

**Çözüm**: `key.properties` dosyasının doğru yolda olduğundan ve keystore dosyasının var olduğundan emin olun.

### API Connection Hatası

**Çözüm**: Build komutunda `--dart-define=API_BASE_URL=...` parametresinin doğru olduğundan emin olun.

### Version Code Hatası

```
Version code 1 has already been used
```

**Çözüm**: `pubspec.yaml`'da version code'u artırın:
```yaml
version: 1.0.1+2  # +2 version code
```

## Checklist

- [ ] Application ID belirlendi ve değiştirildi
- [ ] Production signing key oluşturuldu
- [ ] `key.properties` dosyası oluşturuldu
- [ ] Keystore dosyası güvenli yerde yedeklendi
- [ ] Railway backend URL production'a ayarlandı
- [ ] App bundle başarıyla build edildi
- [ ] Google Play Console'da uygulama oluşturuldu
- [ ] Store listing bilgileri tamamlandı
- [ ] Privacy policy hazırlandı
- [ ] Content rating alındı
- [ ] Screenshots eklendi
- [ ] Internal testing yapıldı
- [ ] Production release gönderildi

## Önemli Notlar

1. **Application ID değiştirilemez** - Yayınlamadan önce kesinleştirin
2. **Keystore kaybedilirse** - Uygulama güncellenemez, yeni uygulama oluşturulmalı
3. **Version code** - Her yayında artırılmalı
4. **API URL** - Production build'de mutlaka Railway URL kullanılmalı
5. **Privacy Policy** - Veri toplama varsa zorunlu

