# APK Deployment Rehberi

Bu rehber, APK dosyasını Railway backend'e yükleyip uzaktaki kullanıcıların test edebilmesi için hazırlanmıştır.

## Adımlar

### 1. APK Build

```bash
cd apps/mobile
flutter build apk --release \
  --dart-define=API_BASE_URL=https://su-aritma-crm-production.up.railway.app/api
```

### 2. APK'yı Backend'e Kopyala

```bash
cd apps/backend
npm run copy:apk
```

Bu komut APK dosyasını `apps/backend/public/apk/app-release.apk` konumuna kopyalar.

### 3. Railway'e Deploy Et

```bash
cd apps/backend
git add .
git commit -m "Add APK download endpoint"
git push
```

Railway otomatik olarak deploy edecektir.

## Erişim URL'leri

Deploy tamamlandıktan sonra:

- **Ana Sayfa (İndirme Sayfası):**
  ```
  https://su-aritma-crm-production.up.railway.app/
  ```

- **Direkt APK İndirme Linki:**
  ```
  https://su-aritma-crm-production.up.railway.app/download/apk/app-release.apk
  ```

## Test Kullanıcılarına Paylaşım

Test kullanıcılarına şu linki paylaşabilirsiniz:

```
https://su-aritma-crm-production.up.railway.app/
```

Bu sayfada:
- Güzel bir indirme butonu
- Kurulum talimatları
- Uyarı mesajları

bulunmaktadır.

## APK Güncelleme

Yeni bir APK build ettiğinizde:

1. APK build yapın
2. `npm run copy:apk` komutunu çalıştırın
3. Railway'e deploy edin (git push)

## Notlar

- APK dosyası `apps/backend/public/apk/` klasöründe saklanır
- Bu klasör `.gitignore`'a eklenmemiştir (APK'yı git'e commit edebilirsiniz)
- APK dosyası genellikle 30-50 MB arası olur
- Railway'de dosya boyutu limiti yoktur (ancak deploy süresi artabilir)

## Sorun Giderme

### APK dosyası bulunamadı hatası

APK build'in tamamlandığından emin olun:
```bash
ls -lh apps/mobile/build/app/outputs/flutter-apk/app-release.apk
```

### Railway'de dosya görünmüyor

1. `public` klasörünün git'e commit edildiğinden emin olun
2. Railway deploy loglarını kontrol edin
3. `public` klasörünün `dist` klasörüne kopyalandığını kontrol edin

### Static file serving çalışmıyor

`apps/backend/src/app.ts` dosyasında static file serving'in doğru yapılandırıldığından emin olun.

