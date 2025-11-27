# Keystore Sonraki Adımlar

## ✅ Tamamlananlar

1. ✅ Keystore başarıyla oluşturuldu: `apps/mobile/android/app/upload-keystore.jks`
2. ✅ `key.properties` dosyası oluşturuldu
3. ✅ `.gitignore` zaten doğru ayarlanmış (keystore ve key.properties ignore edilmiş)

## 🔧 Yapılması Gerekenler

### 1. key.properties Dosyasını Düzenleyin

`apps/mobile/android/key.properties` dosyasını açın ve şifrelerinizi girin:

```properties
storePassword=YOUR_KEYSTORE_PASSWORD_HERE
keyPassword=YOUR_KEYSTORE_PASSWORD_HERE
keyAlias=upload
storeFile=upload-keystore.jks
```

**ÖNEMLİ**: 
- `YOUR_KEYSTORE_PASSWORD_HERE` yerine keytool komutunda girdiğiniz şifreyi yazın
- `storePassword` ve `keyPassword` genellikle aynıdır (eğer farklı girdiyseniz, key password'u yazın)

### 2. Keystore Dosyasını Yedekleyin

**KRİTİK**: Keystore dosyasını kaybederseniz, uygulamayı Google Play'de güncelleyemezsiniz!

```bash
# Güvenli bir yere yedekleyin (örn: cloud storage, USB drive)
cp apps/mobile/android/app/upload-keystore.jks ~/backups/
# veya
cp apps/mobile/android/app/upload-keystore.jks /path/to/secure/backup/
```

**Yedekleme Listesi:**
- ✅ `upload-keystore.jks` dosyası
- ✅ Keystore password'u (güvenli bir yerde saklayın)
- ✅ Key password'u (eğer farklıysa)

### 3. Build.gradle.kts Kontrolü

`apps/mobile/android/app/build.gradle.kts` dosyasında `storeFile` path'ini kontrol edin. Şu anki ayar:

```kotlin
storeFile = file(keystoreProperties["storeFile"] as String)
```

`key.properties` dosyasında `storeFile=upload-keystore.jks` olarak ayarlanmış, bu doğru.

## 🚀 Production Build

key.properties dosyasını düzenledikten sonra production build alabilirsiniz:

```bash
cd apps/mobile

# Railway backend URL'inizi kullanın
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://your-railway-app.railway.app/api
```

## ✅ Kontrol Listesi

- [ ] `key.properties` dosyası düzenlendi (şifreler girildi)
- [ ] Keystore dosyası yedeklendi
- [ ] Keystore password güvenli bir yerde saklandı
- [ ] Railway backend URL'i hazır
- [ ] Production build komutu hazır

## 🔒 Güvenlik Notları

1. **key.properties** ve **upload-keystore.jks** dosyaları `.gitignore`'da
2. Bu dosyaları **asla** Git'e commit etmeyin
3. Keystore dosyasını ve şifrelerini **güvenli bir yerde** saklayın
4. Ekip üyeleriyle paylaşırken **güvenli kanallar** kullanın

## 🆘 Sorun Giderme

### "key.properties not found" Hatası

- `key.properties` dosyasının `apps/mobile/android/` klasöründe olduğundan emin olun
- Dosya adının tam olarak `key.properties` olduğundan emin olun

### "Keystore file not found" Hatası

- `upload-keystore.jks` dosyasının `apps/mobile/android/app/` klasöründe olduğundan emin olun
- `key.properties` dosyasındaki `storeFile` path'ini kontrol edin

### "Password incorrect" Hatası

- `key.properties` dosyasındaki şifrelerin doğru olduğundan emin olun
- Şifrelerde özel karakterler varsa escape edilmeli

