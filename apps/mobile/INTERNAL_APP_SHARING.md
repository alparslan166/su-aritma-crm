# Internal App Sharing - Yükleme Rehberi

## 📱 Ne Yüklenmeli?

**Internal app sharing** sayfasına **Production AAB dosyasını** yükleyin.

## 📦 Yüklenecek Dosya

**Dosya:** `apps/mobile/build/app/outputs/bundle/release/app-release.aab`
**Boyut:** 46 MB
**Versiyon:** 1.0.3+2

## 🎯 Internal App Sharing Nedir?

- ✅ **Test için kullanılır** - Production'a yayınlamadan önce test
- ✅ **Hızlı paylaşım** - Link ile test edicilere gönderilir
- ✅ **Production'dan bağımsız** - Production yayını etkilemez
- ✅ **APK veya AAB** kabul eder

## 📋 Yükleme Adımları

### 1. Mevcut Dosyayı Kaldırın (Opsiyonel)

- "Remove" butonuna tıklayarak `app-debug.apk` dosyasını kaldırabilirsiniz
- Veya "Replace" ile değiştirebilirsiniz

### 2. AAB Dosyasını Yükleyin

1. **"Replace"** veya **"Upload"** butonuna tıklayın
2. Şu dosyayı seçin:
   ```
   apps/mobile/build/app/outputs/bundle/release/app-release.aab
   ```
3. Dosya yüklenecek (birkaç dakika sürebilir)

### 3. Download Link'i Alın

- Yükleme tamamlandıktan sonra bir **download link** oluşturulacak
- Bu linki test edicilere gönderebilirsiniz
- Link ile direkt APK/AAB indirilebilir

## ⚠️ Önemli Notlar

### Debug APK vs Production AAB

- **app-debug.apk** (şu an yüklü): Debug build, test için
- **app-release.aab** (yüklenecek): Production build, gerçek kullanım için

### Internal App Sharing vs Production

- **Internal App Sharing:** Test için, link ile paylaşım
- **Production:** Gerçek yayın, Google Play Store'da görünür

### 30 Kasım Bekleme Süresi

- Internal app sharing'e **şimdi** yükleyebilirsiniz (test için)
- Production'a yüklemek için **30 Kasım 15:15 UTC** beklemelisiniz

## 🚀 Sonraki Adımlar

1. ✅ **Internal app sharing'e AAB yükleyin** (test için - şimdi yapılabilir)
2. ⏳ **30 Kasım sonrası Production'a yükleyin** (gerçek yayın)

## 📝 Test Senaryosu

1. AAB'yi internal app sharing'e yükleyin
2. Download link'ini alın
3. Test edicilere link'i gönderin
4. Test ediciler link ile uygulamayı indirip test eder
5. Sorun yoksa 30 Kasım sonrası Production'a yükleyin

## 🔗 Dosya Konumu

```
apps/mobile/build/app/outputs/bundle/release/app-release.aab
```

Bu dosyayı Google Play Console → Internal app sharing sayfasına yükleyin!

