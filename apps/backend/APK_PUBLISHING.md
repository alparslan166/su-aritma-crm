# APK Yayınlama Rehberi

Bu rehber, APK dosyasını backend üzerinden yayınlamak ve kullanıcıların indirmesini sağlamak için adım adım talimatları içerir.

## 🚀 Hızlı Başlangıç

### 1. APK Build

```bash
cd apps/mobile
flutter build apk --release \
  --dart-define=API_BASE_URL=https://your-railway-app.railway.app/api
```

**ÖNEMLİ**: Railway backend URL'inizi kullanın ve sonuna `/api` ekleyin!

### 2. APK'yı Backend'e Kopyala

```bash
cd apps/backend
npm run copy:apk
```

Bu komut APK dosyasını `apps/backend/public/apk/app-release.apk` konumuna kopyalar.

### 3. Git'e Commit ve Push

```bash
git add apps/backend/public/apk/app-release.apk
git commit -m "Add APK for download"
git push
```

Railway otomatik olarak deploy edecektir.

## 📱 Erişim URL'leri

Deploy tamamlandıktan sonra:

### Ana Sayfa (İndirme Sayfası)
```
https://your-railway-app.railway.app/
```

Bu sayfada:
- Güzel bir indirme butonu
- Kurulum talimatları
- Uyarı mesajları

### Direkt APK İndirme Linki
```
https://your-railway-app.railway.app/download/apk/app-release.apk
```

## ✅ Backend Özellikleri

Backend şu özelliklerle optimize edilmiştir:

1. **Doğru MIME Type**: APK dosyaları için `application/vnd.android.package-archive` MIME type kullanılır
2. **Download Headers**: APK indirme için doğru `Content-Disposition` header'ı
3. **Cache Control**: 1 saatlik cache ile performans optimizasyonu
4. **Error Handling**: APK bulunamadığında kullanıcı dostu hata mesajı
5. **CORS Support**: Tüm origin'lerden APK indirme desteği
6. **Security Headers**: Helmet ile güvenlik header'ları

## 🔄 APK Güncelleme

Yeni bir APK build ettiğinizde:

1. **APK Build**:
   ```bash
   cd apps/mobile
   flutter build apk --release \
     --dart-define=API_BASE_URL=https://your-railway-app.railway.app/api
   ```

2. **APK'yı Kopyala**:
   ```bash
   cd apps/backend
   npm run copy:apk
   ```

3. **Git'e Commit ve Push**:
   ```bash
   git add apps/backend/public/apk/app-release.apk
   git commit -m "Update APK to version X.X.X"
   git push
   ```

## 📋 Kontrol Listesi

APK yayınlamadan önce:

- [ ] APK build başarılı
- [ ] APK dosyası `apps/backend/public/apk/app-release.apk` konumunda
- [ ] API URL doğru (Railway production URL)
- [ ] Git commit yapıldı
- [ ] Railway deploy başarılı
- [ ] Ana sayfa çalışıyor: `https://your-app.railway.app/`
- [ ] APK indirme çalışıyor: `https://your-app.railway.app/download/apk/app-release.apk`

## 🧪 Test

### Tarayıcıdan Test

1. Ana sayfayı açın: `https://your-app.railway.app/`
2. "APK İndir" butonuna tıklayın
3. APK dosyasının indirildiğini kontrol edin

### Direkt Link Test

```bash
curl -I https://your-app.railway.app/download/apk/app-release.apk
```

Beklenen response headers:
```
Content-Type: application/vnd.android.package-archive
Content-Disposition: attachment; filename="app-release.apk"
Cache-Control: public, max-age=3600
```

### Android Cihazdan Test

1. Android cihazınızda tarayıcıyı açın
2. `https://your-app.railway.app/` adresine gidin
3. "APK İndir" butonuna tıklayın
4. İndirme tamamlandıktan sonra APK'yı yükleyin

## 🔧 Sorun Giderme

### APK dosyası bulunamadı hatası

**Sorun**: `404 - APK dosyası bulunamadı`

**Çözüm**:
1. APK build'in tamamlandığından emin olun:
   ```bash
   ls -lh apps/mobile/build/app/outputs/flutter-apk/app-release.apk
   ```

2. APK'nın kopyalandığını kontrol edin:
   ```bash
   ls -lh apps/backend/public/apk/app-release.apk
   ```

3. Git'e commit edildiğinden emin olun:
   ```bash
   git status
   ```

4. Railway deploy loglarını kontrol edin

### APK indirme çalışmıyor

**Sorun**: APK indirme başlamıyor veya hata veriyor

**Çözüm**:
1. Railway servisinin çalıştığını kontrol edin
2. Health check endpoint'ini test edin:
   ```bash
   curl https://your-app.railway.app/api/health
   ```

3. CORS ayarlarını kontrol edin (backend'de `ALLOWED_ORIGINS` boş olmalı veya tüm origin'lere izin verilmeli)

### MIME type yanlış

**Sorun**: APK dosyası tarayıcıda açılıyor, indirilmiyor

**Çözüm**: Backend'de MIME type doğru ayarlanmış olmalı. Kod kontrol edildi ve doğru.

### Cache sorunu

**Sorun**: Eski APK indiriliyor

**Çözüm**: 
1. Tarayıcı cache'ini temizleyin
2. Veya direkt link kullanın: `https://your-app.railway.app/download/apk/app-release.apk?v=2`

## 📝 Notlar

- APK dosyası genellikle 30-50 MB arası olur
- Railway'de dosya boyutu limiti yoktur (ancak deploy süresi artabilir)
- APK dosyası git repository'sine commit edilir (`.gitignore`'a eklenmemiştir)
- Her APK güncellemesinde version numarasını artırmayı unutmayın (`pubspec.yaml`)

## 🔗 İlgili Dokümantasyon

- [APK Build Guide](../../mobile/APK_BUILD_GUIDE.md)
- [Production Ready Guide](./PRODUCTION_READY.md)
- [Railway Setup](./RAILWAY_SETUP.md)

Başarılar! 🚀

