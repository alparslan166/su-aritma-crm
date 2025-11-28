# Google Play Store Deployment Rehberi

Bu rehber, uygulamayı Google Play Store'a yayınlamak için backend'in hazır olması ve gerekli adımları içerir.

## ✅ Backend Hazırlığı

Backend Google Play Store yayını için optimize edilmiştir:

- ✅ Production logging optimizasyonu
- ✅ Güvenlik iyileştirmeleri
- ✅ CORS yapılandırması
- ✅ Environment validation
- ✅ API-only endpoint (APK download endpoint'leri kaldırıldı)

## 📱 Mobile App Build (AAB Format)

Google Play Store için **AAB (Android App Bundle)** formatında build yapmanız gerekiyor:

```bash
cd apps/mobile
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://your-railway-app.railway.app/api
```

**ÖNEMLİ**: 
- Railway backend URL'inizi kullanın
- URL'in sonuna `/api` ekleyin
- `appbundle` komutu kullanın (APK değil!)

## 📦 AAB Dosyasının Konumu

Build tamamlandıktan sonra AAB dosyası şu konumda olacak:

```
apps/mobile/build/app/outputs/bundle/release/app-release.aab
```

## 🚀 Google Play Console'a Yükleme

### 1. Google Play Console'a Giriş

1. [Google Play Console](https://play.google.com/console) adresine gidin
2. Google hesabınızla giriş yapın
3. Developer hesabı oluşturmanız gerekebilir (ilk kez kullanıyorsanız $25 ücret)

### 2. Yeni Uygulama Oluşturma

1. Sol menüden **"Tüm uygulamalar"** veya **"Uygulamalar"** sekmesine tıklayın
2. **"Uygulama oluştur"** veya **"Create app"** butonuna tıklayın

**Uygulama Bilgileri:**
- **Uygulama adı**: "Su Arıtma" (veya istediğiniz isim)
- **Varsayılan dil**: Türkçe
- **Uygulama türü**: Uygulama
- **Ücretsiz mi, ücretli mi?**: Ücretsiz (veya istediğiniz seçenek)

### 3. Store Listing (Mağaza Listesi)

Sol menüden **"Store listing"** sekmesine gidin:

**Kısa açıklama (80 karakter):**
```
Su arıtma cihazları için yönetim ve takip uygulaması
```

**Tam açıklama (4000 karakter):**
```
Su Arıtma CRM uygulaması ile müşterilerinizi, işlerinizi ve stoklarınızı kolayca yönetin.

Özellikler:
- Müşteri yönetimi ve takibi
- İş (job) yönetimi ve durum takibi
- Personel yönetimi ve atama
- Stok takibi ve uyarıları
- Bakım hatırlatıcıları
- Borç ve taksit takibi
- Fatura oluşturma
- Konum takibi
- Bildirimler

Admin ve personel için ayrı arayüzler.
```

**Görseller (Zorunlu):**
- Uygulama simgesi: 512x512 PNG
- Özellik grafiği: 1024x500 PNG
- Ekran görüntüleri: En az 2 adet (telefon için)

### 4. İçerik Derecelendirmesi (Content Rating)

1. **"İçerik derecelendirmesi"** sekmesine gidin
2. **"Başlat"** butonuna tıklayın
3. Soruları yanıtlayın (genellikle "Everyone" veya "3+" alırsınız)

### 5. Veri Güvenliği (Data Safety)

1. **"Veri güvenliği"** sekmesine gidin
2. Uygulamanızın topladığı verileri belirtin:
   - Konum verileri: Evet (iş takibi için)
   - Kişisel bilgiler: Evet (müşteri/personel bilgileri)
   - Fotoğraflar: Evet (opsiyonel)

### 6. Gizlilik Politikası (Privacy Policy) - ZORUNLU

**ÖNEMLİ**: Veri topluyorsanız gizlilik politikası URL'i zorunludur.

1. **"Store listing"** > **"Gizlilik politikası"** bölümüne gidin
2. Gizlilik politikası URL'inizi ekleyin
   - Örnek: `https://yourwebsite.com/privacy-policy`
   - Veya GitHub Pages, Notion, vb. kullanabilirsiniz

### 7. AAB Dosyasını Yükleme

1. Sol menüden **"Production"** sekmesine gidin
2. **"Yeni sürüm oluştur"** butonuna tıklayın
3. **"Uygulama paketleri"** bölümünde **"Yükle"** butonuna tıklayın
4. Şu dosyayı seçin:
   ```
   apps/mobile/build/app/outputs/bundle/release/app-release.aab
   ```
5. Yükleme tamamlanana kadar bekleyin

### 8. Sürüm Notları

**"Sürüm notları"** bölümüne Türkçe sürüm notları ekleyin:

```
İlk sürüm
- Müşteri yönetimi
- İş takibi
- Personel yönetimi
- Stok takibi
- Bakım hatırlatıcıları
```

### 9. Kaydet ve İncelemeye Gönder

1. **"Kaydet"** butonuna tıklayın
2. **"İncelemeye gönder"** butonuna tıklayın
3. Onay mesajını okuyun ve onaylayın

## ⏱️ İnceleme Süreci

- Google Play incelemesi genellikle **1-3 gün** sürer
- İnceleme sırasında uygulama "İncelemede" durumunda olacak
- Onaylandıktan sonra uygulama yayınlanacak

## 📋 Kontrol Listesi

### Backend Kontrolleri

- [x] Backend production için optimize edildi
- [x] APK download endpoint'leri kaldırıldı
- [x] API-only endpoint yapılandırıldı
- [ ] Railway'da environment variables ayarlandı
- [ ] Database migration'ları çalıştırıldı
- [ ] Health check başarılı: `/api/health`

### Mobile App Kontrolleri

- [ ] Application ID doğru: `com.suaritma.app`
- [ ] App ismi doğru: "Su Arıtma"
- [ ] Production signing key oluşturuldu
- [ ] Permissions eklendi
- [ ] Logger production'da kapatıldı
- [ ] API URL production'a ayarlandı
- [ ] AAB build başarılı

### Google Play Console Kontrolleri

- [ ] Uygulama oluşturuldu
- [ ] Store listing bilgileri dolduruldu
- [ ] İçerik derecelendirmesi tamamlandı
- [ ] Veri güvenliği formu dolduruldu
- [ ] Gizlilik politikası URL'i eklendi
- [ ] AAB dosyası yüklendi
- [ ] Sürüm notları eklendi
- [ ] İncelemeye gönderildi

## 🔧 Sorun Giderme

### "Gizlilik politikası gerekli" Hatası

- Gizlilik politikası URL'i ekleyin
- Basit bir sayfa oluşturup yükleyin (GitHub Pages, Notion, vb.)

### "Ekran görüntüleri eksik" Hatası

- En az 2 ekran görüntüsü ekleyin
- Telefon formatında olmalı

### "İçerik derecelendirmesi gerekli" Hatası

- Content rating anketini tamamlayın

### AAB Yükleme Hatası

- AAB dosyasının doğru konumda olduğundan emin olun
- Build'in başarılı olduğunu kontrol edin
- Signing key'in doğru olduğundan emin olun

## 📝 Notlar

1. **AAB vs APK**: Google Play Store AAB formatını tercih eder (daha küçük dosya boyutu)
2. **Version Code**: Her yeni sürümde versionCode artırılmalı (`pubspec.yaml`'da `version: 1.0.1+2` gibi)
3. **Signing Key**: Production signing key'i güvenli bir yerde saklayın (kaybederseniz uygulamayı güncelleyemezsiniz)
4. **Backend URL**: Mobile app build'de mutlaka production Railway URL kullanın

## 🔗 İlgili Dokümantasyon

- [Google Play Checklist](../../mobile/GOOGLE_PLAY_CHECKLIST.md)
- [Google Play Upload Guide](../../mobile/GOOGLE_PLAY_UPLOAD_GUIDE.md)
- [Production Ready Guide](./PRODUCTION_READY.md)
- [Keystore Setup](../../mobile/KEYSTORE_SETUP.md)

Başarılar! 🚀

