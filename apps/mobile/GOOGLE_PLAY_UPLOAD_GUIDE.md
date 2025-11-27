# Google Play Console - App Yükleme Rehberi

Bu rehber, `app-release.aab` dosyasını Google Play Console'a yüklemek için adım adım talimatları içerir.

## 1. Google Play Console'a Giriş

1. [Google Play Console](https://play.google.com/console) adresine gidin
2. Google hesabınızla giriş yapın
3. Developer hesabı oluşturmanız gerekebilir (ilk kez kullanıyorsanız)
   - **Önemli**: Developer hesabı için **$25 tek seferlik ücret** ödemeniz gerekir

## 2. Yeni Uygulama Oluşturma

1. Sol menüden **"Tüm uygulamalar"** veya **"Uygulamalar"** sekmesine tıklayın
2. **"Uygulama oluştur"** veya **"Create app"** butonuna tıklayın

### Uygulama Bilgileri

- **Uygulama adı**: "Su Arıtma" (veya istediğiniz isim)
- **Varsayılan dil**: Türkçe
- **Uygulama türü**: Uygulama
- **Ücretsiz mi, ücretli mi?**: Ücretsiz (veya istediğiniz seçenek)
- **Dağıtım bildirimi**: Evet (kabul edin)

## 3. Store Listing (Mağaza Listesi) - Zorunlu Bilgiler

Sol menüden **"Store listing"** veya **"Mağaza listesi"** sekmesine gidin:

### Kısa açıklama (80 karakter)
```
Su arıtma cihazları için yönetim ve takip uygulaması
```

### Tam açıklama (4000 karakter)
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

### Görseller (Zorunlu)

1. **Uygulama simgesi**: 512x512 PNG
   - Şu anki: `apps/mobile/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
   - Gerekirse özel bir icon oluşturun

2. **Özellik grafiği**: 1024x500 PNG
   - Uygulamanın tanıtım görseli
   - Oluşturmanız gerekecek

3. **Ekran görüntüleri**: En az 2 adet (telefon için)
   - Uygulamadan ekran görüntüsü alın
   - Minimum: 320px, Maksimum: 3840px
   - En boy oranı: 16:9 veya 9:16

### Kategori

- **Uygulama kategorisi**: İş (Business) veya Verimlilik (Productivity)
- **Etiketler**: İş, CRM, Yönetim

## 4. İçerik Derecelendirme (Content Rating)

1. **"İçerik derecelendirmesi"** veya **"Content rating"** sekmesine gidin
2. **"Başlat"** veya **"Start questionnaire"** butonuna tıklayın
3. Soruları yanıtlayın:
   - Şiddet içerik: Hayır
   - Cinsel içerik: Hayır
   - Küfür: Hayır
   - Uyuşturucu: Hayır
   - Korku: Hayır
   - vb.
4. Derecelendirmeyi alın (genellikle "Everyone" veya "3+")

## 5. Veri Güvenliği (Data Safety)

1. **"Veri güvenliği"** veya **"Data safety"** sekmesine gidin
2. Uygulamanızın topladığı verileri belirtin:
   - Konum verileri: Evet (iş takibi için)
   - Kişisel bilgiler: Evet (müşteri/personel bilgileri)
   - Fotoğraflar: Evet (opsiyonel)
3. Veri kullanım amaçlarını belirtin

## 6. Gizlilik Politikası (Privacy Policy) - Zorunlu

**ÖNEMLİ**: Veri topluyorsanız gizlilik politikası URL'i zorunludur.

1. **"Store listing"** > **"Gizlilik politikası"** bölümüne gidin
2. Gizlilik politikası URL'inizi ekleyin
   - Örnek: `https://yourwebsite.com/privacy-policy`
   - Veya GitHub Pages, Notion, vb. kullanabilirsiniz

**Hızlı çözüm**: Basit bir gizlilik politikası oluşturun ve bir yere yükleyin.

## 7. App Bundle Yükleme

### Production Release Oluşturma

1. Sol menüden **"Production"** veya **"Üretim"** sekmesine gidin
2. **"Yeni sürüm oluştur"** veya **"Create new release"** butonuna tıklayın

### App Bundle Yükleme

1. **"Uygulama paketleri"** veya **"App bundles and APKs"** bölümünde **"Yükle"** veya **"Upload"** butonuna tıklayın
2. Dosya seçici açılacak
3. Şu dosyayı seçin:
   ```
   /Users/alparslan166/development/su-aritma/apps/mobile/build/app/outputs/bundle/release/app-release.aab
   ```
   **Veya Finder'da:**
   - `apps/mobile/build/app/outputs/bundle/release/` klasörüne gidin
   - `app-release.aab` dosyasını bulun ve seçin
4. Yükleme tamamlanana kadar bekleyin (birkaç dakika sürebilir)
5. Yükleme tamamlandığında dosya listede görünecek

### Sürüm Notları

1. **"Sürüm notları"** veya **"Release notes"** bölümüne gidin
2. Türkçe sürüm notları ekleyin:
   ```
   İlk sürüm
   - Müşteri yönetimi
   - İş takibi
   - Personel yönetimi
   - Stok takibi
   - Bakım hatırlatıcıları
   ```

### Kaydet ve İncelemeye Gönder

1. **"Kaydet"** veya **"Save"** butonuna tıklayın
2. **"İncelemeye gönder"** veya **"Send for review"** butonuna tıklayın
3. Onay mesajını okuyun ve onaylayın

## 8. İnceleme Süreci

- Google Play incelemesi genellikle **1-3 gün** sürer
- İnceleme sırasında uygulama "İncelemede" durumunda olacak
- Onaylandıktan sonra uygulama yayınlanacak

## 9. İnceleme Sonrası

- Uygulama onaylandığında otomatik olarak yayınlanır
- Kullanıcılar Google Play Store'dan indirebilir

## Kontrol Listesi

### Zorunlu Bilgiler
- [ ] Uygulama adı
- [ ] Kısa açıklama (80 karakter)
- [ ] Tam açıklama (4000 karakter)
- [ ] Uygulama simgesi (512x512)
- [ ] Özellik grafiği (1024x500)
- [ ] Ekran görüntüleri (en az 2)
- [ ] İçerik derecelendirmesi
- [ ] Veri güvenliği formu
- [ ] Gizlilik politikası URL'i (veri topluyorsanız)
- [ ] App bundle yüklendi
- [ ] Sürüm notları eklendi

### Opsiyonel Ama Önerilen
- [ ] Tablet ekran görüntüleri
- [ ] Promo video
- [ ] Uygulama kategorisi
- [ ] Etiketler

## Önemli Notlar

1. **Developer hesabı**: İlk kez kullanıyorsanız $25 ödemeniz gerekir
2. **Gizlilik politikası**: Veri topluyorsanız zorunludur
3. **İnceleme süresi**: 1-3 gün sürebilir
4. **Version code**: Her yeni sürümde artırılmalı (`pubspec.yaml`'da `version: 1.0.1+2` gibi)

## Sorun Giderme

### "Gizlilik politikası gerekli" Hatası
- Gizlilik politikası URL'i ekleyin
- Basit bir sayfa oluşturup yükleyin

### "Ekran görüntüleri eksik" Hatası
- En az 2 ekran görüntüsü ekleyin
- Telefon formatında olmalı

### "İçerik derecelendirmesi gerekli" Hatası
- Content rating anketini tamamlayın

## Hızlı Başlangıç

1. ✅ App bundle hazır: `app-release.aab`
2. ⏳ Google Play Console'a giriş yap
3. ⏳ Yeni uygulama oluştur
4. ⏳ Store listing bilgilerini doldur
5. ⏳ App bundle'ı yükle
6. ⏳ İncelemeye gönder

Başarılar! 🚀

