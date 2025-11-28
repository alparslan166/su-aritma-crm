# APK Dağıtım Rehberi - Google Play Dışı

## 📦 APK Build Yapma

### 1. Release APK Build

```bash
cd apps/mobile

flutter build apk --release \
  --dart-define=API_BASE_URL=https://su-aritma-crm-production-5d49.up.railway.app/api
```

### 2. APK Dosyası Konumu

Build tamamlandıktan sonra APK dosyası şurada olacak:

```
apps/mobile/build/app/outputs/flutter-apk/app-release.apk
```

## 🚀 Dağıtım Yöntemleri

### Yöntem 1: Direkt APK Paylaşımı

#### A. Cloud Storage (Google Drive, Dropbox, iCloud)

1. **APK dosyasını cloud storage'a yükleyin**
2. **Paylaşım link'i oluşturun**
3. **Link'i kullanıcılara gönderin**
4. **Kullanıcılar link'ten indirip yükleyebilir**

**Avantajlar:**
- ✅ Ücretsiz
- ✅ Kolay paylaşım
- ✅ Sınırsız indirme

**Dezavantajlar:**
- ❌ Her güncellemede yeni link
- ❌ Versiyon yönetimi zor

#### B. Kendi Web Sunucunuz

1. **APK dosyasını web sunucunuza yükleyin**
2. **Download sayfası oluşturun**
3. **QR kod oluşturun** (kolay erişim için)

**Örnek HTML Sayfası:**
```html
<!DOCTYPE html>
<html>
<head>
    <title>Su Arıtma CRM - İndir</title>
</head>
<body>
    <h1>Su Arıtma CRM</h1>
    <p>Versiyon: 1.0.3</p>
    <a href="app-release.apk" download>APK'yı İndir</a>
    <p>Not: Android ayarlarından "Bilinmeyen kaynaklardan uygulama yükleme" iznini açın.</p>
</body>
</html>
```

### Yöntem 2: Firebase App Distribution

#### Kurulum

1. **Firebase Console'a gidin** (https://console.firebase.google.com)
2. **Proje oluşturun** veya mevcut projeyi seçin
3. **App Distribution'ı etkinleştirin**

#### APK Yükleme

```bash
# Firebase CLI kurulumu (ilk kez)
npm install -g firebase-tools

# Firebase'e giriş
firebase login

# APK'yı yükle
firebase appdistribution:distribute \
  apps/mobile/build/app/outputs/flutter-apk/app-release.apk \
  --app YOUR_APP_ID \
  --groups "testers" \
  --release-notes "Version 1.0.3 - İlk release"
```

**Avantajlar:**
- ✅ Otomatik bildirim
- ✅ Versiyon yönetimi
- ✅ Test grubu yönetimi
- ✅ Crash raporları

### Yöntem 3: TestFlight Alternatifi (Android için)

#### A. AppCenter (Microsoft)

1. **AppCenter'a kaydolun** (https://appcenter.ms)
2. **Android app oluşturun**
3. **APK'yı yükleyin**
4. **Test edicileri ekleyin**
5. **Dağıtım link'i alın**

#### B. TestFairy

1. **TestFairy'a kaydolun** (https://www.testfairy.com)
2. **APK'yı yükleyin**
3. **Test edicilere link gönderin**

### Yöntem 4: Kendi APK İndirme Sayfası

#### Basit PHP/Node.js Endpoint

**Backend'e endpoint ekleyin:**

```typescript
// apps/backend/src/routes/index.ts veya media routes
app.get('/download/apk', (req, res) => {
  const apkPath = path.join(__dirname, '../../public/apk/app-release.apk');
  res.download(apkPath, 'su-aritma-crm.apk');
});
```

**APK'yı backend'e kopyalayın:**

```bash
# APK build yap
cd apps/mobile
flutter build apk --release --dart-define=API_BASE_URL=...

# Backend'e kopyala
cp build/app/outputs/flutter-apk/app-release.apk ../backend/public/apk/
```

**Kullanım:**
- URL: `https://su-aritma-crm-production-5d49.up.railway.app/download/apk`
- Kullanıcılar bu link'ten direkt indirebilir

## 📱 Kullanıcı Tarafında Yükleme

### Android Ayarları

Kullanıcıların yapması gerekenler:

1. **"Bilinmeyen kaynaklardan uygulama yükleme" iznini açın:**
   - Ayarlar → Güvenlik → Bilinmeyen kaynaklar ✅
   - Veya: Ayarlar → Uygulamalar → Özel erişim → Bu kaynaktan yükle ✅

2. **APK dosyasını indirin**

3. **APK dosyasına tıklayın ve yükleyin**

4. **İzinleri onaylayın**

## 🔐 Güvenlik ve İmzalama

### Release APK İmzalama

APK zaten release keystore ile imzalanmış olmalı:

```bash
# İmzalama kontrolü
jarsigner -verify -verbose -certs \
  apps/mobile/build/app/outputs/flutter-apk/app-release.apk
```

### APK İmza Doğrulama

```bash
# APK imza bilgilerini görüntüle
apksigner verify --print-certs \
  apps/mobile/build/app/outputs/flutter-apk/app-release.apk
```

## 📋 APK Build Komutları

### Release APK (Tek APK)

```bash
cd apps/mobile
flutter build apk --release \
  --dart-define=API_BASE_URL=https://su-aritma-crm-production-5d49.up.railway.app/api
```

### Split APKs (Boyut Optimizasyonu)

```bash
# Her ABI için ayrı APK (daha küçük dosyalar)
flutter build apk --split-per-abi --release \
  --dart-define=API_BASE_URL=https://su-aritma-crm-production-5d49.up.railway.app/api
```

**Çıktı:**
- `app-armeabi-v7a-release.apk` (32-bit)
- `app-arm64-v8a-release.apk` (64-bit)
- `app-x86_64-release.apk` (x86_64)

## 🎯 Önerilen Yöntem

### Küçük Ölçek (1-10 kullanıcı)
- ✅ **Google Drive / Dropbox** - En kolay ve ücretsiz

### Orta Ölçek (10-100 kullanıcı)
- ✅ **Firebase App Distribution** - Profesyonel ve ücretsiz
- ✅ **Kendi web sunucunuz** - Tam kontrol

### Büyük Ölçek (100+ kullanıcı)
- ✅ **Firebase App Distribution**
- ✅ **AppCenter / TestFairy**
- ✅ **Enterprise MDM çözümü**

## 📝 QR Kod Oluşturma

APK indirme link'iniz için QR kod oluşturun:

**Online QR Kod Oluşturucular:**
- https://www.qr-code-generator.com
- https://qr-code-generator.com

**QR kod ile kullanıcılar:**
1. QR kodu tarar
2. Link'e yönlendirilir
3. APK'yı indirir
4. Yükler

## ⚠️ Önemli Notlar

1. **Her güncellemede yeni APK build yapın**
2. **Version code'u artırın** (`pubspec.yaml`)
3. **APK dosyasını yedekleyin** (her versiyon için)
4. **Kullanıcılara güncelleme bildirimi gönderin**
5. **Güvenlik:** Sadece güvendiğiniz kaynaklardan APK paylaşın

## 🔄 Güncelleme Süreci

1. **Yeni APK build yapın**
2. **Version code'u artırın**
3. **APK'yı dağıtım platformuna yükleyin**
4. **Kullanıcılara bildirim gönderin**
5. **Eski APK'yı arşivleyin**

## 📊 Versiyon Yönetimi

APK dosyalarını versiyon numarası ile saklayın:

```
apk/
  ├── app-release-v1.0.1.apk
  ├── app-release-v1.0.2.apk
  └── app-release-v1.0.3.apk
```

