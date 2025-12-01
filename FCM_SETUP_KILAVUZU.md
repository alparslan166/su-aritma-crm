# 🔥 Firebase Cloud Messaging (FCM) Kurulum Kılavuzu

## 📋 FCM Kurulumu (Firebase Admin SDK)

> ⚠️ **ÖNEMLİ:** Firebase Cloud Messaging API (Legacy) artık deprecated! 
> Modern Firebase Admin SDK kullanıyoruz.

### ⚠️ ÖNEMLİ: Doğru Key'i Bulma
- ❌ **YANLIŞ:** "Web Push certificates" bölümündeki key pair'ler
- ❌ **YANLIŞ:** "Cloud Messaging API (Legacy)" → "Server key" (deprecated)
- ✅ **DOĞRU:** Firebase Admin SDK → Service Account Key

### Adım 1: Firebase Console'a Giriş
1. [Firebase Console](https://console.firebase.google.com/) adresine git
2. Google hesabınla giriş yap

### Adım 2: Proje Oluştur veya Mevcut Projeyi Seç
1. Eğer yeni proje oluşturacaksan:
   - "Add project" butonuna tıkla
   - Proje adını gir (örn: "su-aritma-crm")
   - Google Analytics'i isteğe bağlı olarak etkinleştir
   - "Create project" butonuna tıkla

2. Eğer mevcut bir projen varsa:
   - Proje listesinden projeni seç

### Adım 3: Service Account Key Oluştur (ÖNERİLEN - Modern Yöntem)

> ✅ **Firebase Admin SDK kullanıyoruz** - Legacy API deprecated olduğu için

1. Sol menüden **⚙️ Project Settings** (Proje Ayarları) tıkla
2. Üstteki **Service accounts** sekmesine git
3. **Generate new private key** butonuna tıkla
4. Açılan popup'ta **Generate key** butonuna tıkla
5. JSON dosyası otomatik indirilecek (örn: `su-aritma-crm-firebase-adminsdk-xxxxx.json`)

> 💡 **Alternatif:** Eğer Legacy API'yi enable edebilirsen, o da çalışır (fallback mekanizması var)

### Adım 4: Service Account Key'i Backend'e Ekle

**Local Development için:**
1. İndirdiğin JSON dosyasını `apps/backend/` klasörüne kopyala
2. Dosya adını `firebase-service-account.json` olarak değiştir
3. `.gitignore` dosyasına ekle (güvenlik için):
   ```
   firebase-service-account.json
   ```

**Railway (Production) için:**
1. İndirdiğin JSON dosyasını aç
2. İçeriğini kopyala (tüm JSON - tek satır olarak)
3. Railway dashboard → Project → Variables
4. Yeni variable ekle:
   - Name: `FIREBASE_SERVICE_ACCOUNT`
   - Value: JSON içeriğini yapıştır (tek satır olarak, tırnak işaretleri olmadan)
5. **ÖNEMLİ:** Variable ekledikten sonra Railway'de backend service'i restart et
   - Railway Dashboard → Backend Service → Settings → Restart

### Adım 5: Environment Variable (Opsiyonel)
Eğer JSON dosyası yerine environment variable kullanmak istersen:
1. JSON dosyasındaki değerleri `.env` dosyasına ekle:
   ```env
   FIREBASE_PROJECT_ID=su-aritma-crm
   FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
   FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@su-aritma-crm.iam.gserviceaccount.com
   ```

## 📱 Mobile App için Firebase Yapılandırması

### Android
1. Firebase Console → Project Settings → **Your apps** bölümüne git
2. **Add app** → **Android** seç
3. **Android package name** gir: `com.suaritma.app`
   - ⚠️ **ÖNEMLİ:** Bu değer `android/app/build.gradle.kts` dosyasındaki `applicationId` ile tam olarak aynı olmalı
   - Mevcut değer: `com.suaritma.app`
4. **google-services.json** dosyasını indir
5. İndirilen dosyayı `apps/mobile/android/app/` klasörüne kopyala

### iOS
1. Firebase Console → Project Settings → **Your apps** bölümüne git
2. **Add app** → **iOS** seç
3. **iOS bundle ID** gir: `com.alparslan.turan.suaritma`
   - ⚠️ **ÖNEMLİ:** Bu değer `ios/Runner.xcodeproj` içindeki `PRODUCT_BUNDLE_IDENTIFIER` ile tam olarak aynı olmalı
   - Mevcut değer: `com.alparslan.turan.suaritma`
4. **GoogleService-Info.plist** dosyasını indir
5. İndirilen dosyayı `apps/mobile/ios/Runner/` klasörüne kopyala
6. Xcode'da projeyi aç ve dosyayı projeye ekle

## 🔍 Kontrol Listesi

### Backend
- [ ] Firebase projesi oluşturuldu
- [ ] Service Account Key oluşturuldu ve indirildi
- [ ] Backend'e `firebase-service-account.json` eklendi (local) veya `FIREBASE_SERVICE_ACCOUNT` environment variable eklendi (Railway)
- [ ] Railway production environment'a `FIREBASE_SERVICE_ACCOUNT` eklendi
- [ ] Database migration çalıştırıldı (`npx prisma migrate deploy`)

### Mobile App
- [ ] Android için Firebase app eklendi (`com.suaritma.app`)
- [ ] iOS için Firebase app eklendi (`com.alparslan.turan.suaritma`)
- [ ] Android için `google-services.json` eklendi (`apps/mobile/android/app/`)
- [ ] iOS için `GoogleService-Info.plist` eklendi (`apps/mobile/ios/Runner/`)
- [ ] Xcode'da `GoogleService-Info.plist` dosyası projeye eklendi

## ⚠️ Önemli Notlar

1. **Firebase Service Account Key:**
   - Service Account Key'i asla public repository'ye commit etme
   - `.gitignore` dosyasına `firebase-service-account.json` eklendi
   - Railway'de environment variable olarak sakla (`FIREBASE_SERVICE_ACCOUNT`)

2. **404 Hatası Alıyorsan:**
   - Firebase Service Account Key eklenmemiş olabilir
   - Railway'de `FIREBASE_SERVICE_ACCOUNT` variable'ını kontrol et
   - Backend loglarını kontrol et: "Firebase Admin SDK initialized" mesajını ara
   - Eğer "Firebase Admin SDK not initialized" görüyorsan, Service Account Key eksik

3. **Test:**
   - Service Account Key ekledikten sonra Railway'de backend'i restart et
   - Mobile app'te bildirim izni ver
   - Test bildirimi gönder

## 🧪 Test Etme

### Backend'de Test Bildirimi Gönderme

**Production API için:**
```bash
curl -X POST https://su-aritma-crm-production-5d49.up.railway.app/api/notifications/send \
  -H "Content-Type: application/json" \
  -H "x-admin-id: YOUR_ADMIN_ID" \
  -d '{
    "role": "admin",
    "title": "Test Bildirimi",
    "body": "Bu bir test bildirimidir"
  }'
```

**Local Development için:**
```bash
curl -X POST http://localhost:4000/api/notifications/send \
  -H "Content-Type: application/json" \
  -H "x-admin-id: YOUR_ADMIN_ID" \
  -d '{
    "role": "admin",
    "title": "Test Bildirimi",
    "body": "Bu bir test bildirimidir"
  }'
```

> ⚠️ **Not:** `YOUR_ADMIN_ID` yerine gerçek admin ID'ni kullan. Admin ID'ni login sonrası session'dan alabilirsin.

### Mobile App'te Test

1. Uygulamayı aç ve giriş yap
2. FCM token'ın backend'e kaydedildiğini kontrol et (loglarda görünür)
3. Backend'den test bildirimi gönder
4. Bildirimin telefonuna gelip gelmediğini kontrol et

## 🔍 Troubleshooting

### ❌ 404 Hatası: "FCM request failed: Not Found"

**Sorun:** Firebase Service Account Key eksik veya yanlış yapılandırılmış

**Çözüm Adımları:**
1. Railway Dashboard → Backend Service → Variables
2. `FIREBASE_SERVICE_ACCOUNT` variable'ını kontrol et
3. Eğer yoksa veya yanlışsa:
   - Firebase Console → Project Settings → Service accounts
   - "Generate new private key" → JSON dosyasını indir
   - JSON içeriğini kopyala (tek satır, tırnak işaretleri olmadan)
   - Railway'de `FIREBASE_SERVICE_ACCOUNT` variable'ına yapıştır
4. **Backend service'i restart et:**
   - Railway Dashboard → Backend Service → Settings → Restart
5. Backend loglarında kontrol et:
   - ✅ `Firebase Admin SDK initialized` → Başarılı
   - ❌ `Firebase Admin SDK not initialized` → Service Account Key hala eksik

### Bildirimler gelmiyor
1. Firebase Service Account Key doğru mu kontrol et
2. Device token kayıtlı mı kontrol et (backend loglarında "Device token registered")
3. Token aktif mi kontrol et (`isActive = true`)
4. Backend loglarını kontrol et

### Invalid Token Hatası
- Invalid token'lar otomatik olarak `isActive = false` yapılır
- Token refresh olduğunda yeni token kaydedilir

## 📚 Daha Fazla Bilgi

- [Firebase Console](https://console.firebase.google.com/)
- [FCM Documentation](https://firebase.google.com/docs/cloud-messaging)
- [Flutter Firebase Setup](https://firebase.flutter.dev/docs/overview)

