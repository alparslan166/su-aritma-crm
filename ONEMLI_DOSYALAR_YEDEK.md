# 🔐 Saklanması Gereken Önemli Dosyalar

## ⚠️ KRİTİK: Kaybedilirse Uygulama Güncellenemez!

### 1. Keystore Dosyası (.jks) - EN ÖNEMLİSİ

**Dosya:** `apps/mobile/android/upload-keystore.jks`

**Neden Önemli:**
- Google Play Store'da uygulama güncellemeleri için **ZORUNLU**
- Kaybedilirse uygulama **ASLA** güncellenemez
- Yeni uygulama oluşturmak gerekir (tüm kullanıcılar kaybolur)

**Yedekleme:**
```bash
# Keystore dosyasını güvenli bir yere kopyalayın
cp apps/mobile/android/upload-keystore.jks ~/BACKUP/upload-keystore.jks
```

**Saklama Yerleri:**
- ✅ Cloud storage (Google Drive, Dropbox, iCloud) - **ŞİFRELEME İLE**
- ✅ USB sürücü (şifreli)
- ✅ Yedek bilgisayar
- ✅ Güvenli not servisi (1Password, LastPass, vb.)

### 2. Keystore Şifreleri ve Bilgileri

**Dosya:** `apps/mobile/android/key.properties`

**İçerik:**
```
storePassword=asdfgh
keyPassword=asdfgh
keyAlias=upload
storeFile=upload-keystore.jks
```

**Neden Önemli:**
- Keystore'u kullanmak için şifreler gerekli
- Şifreler kaybolursa keystore kullanılamaz

**Saklama:**
- ✅ Şifre yöneticisi (1Password, LastPass, Bitwarden)
- ✅ Güvenli not dosyası (şifreli)
- ✅ Cloud storage (şifreli)

### 3. Keystore SHA-256 Parmak İzi

**Değer:**
```
SHA-256: 8C:BD:C4:01:A8:EA:A5:38:D7:54:37:4B:6A:C4:27:C3:B9:19:E1:9E:60:FD:8E:32:95:4A:71:68:B7:A3:48:A6
```

**Neden Önemli:**
- Google Play Console'da upload key doğrulama için
- Keystore kaybolursa Google'a ispat için kullanılabilir

**Saklama:**
- ✅ Not dosyasına kaydedin
- ✅ Şifre yöneticisine ekleyin

## 📦 Uygulama Dosyaları

### 4. AAB Dosyası (Yedek)

**Dosya:** `apps/mobile/build/app/outputs/bundle/release/app-release.aab`

**Neden Önemli:**
- Yayınlanan sürümün yedeği
- Sorun durumunda geri dönüş için

**Saklama:**
- ✅ Her yayında yedek alın
- ✅ Cloud storage'da versiyon numarası ile saklayın
- ✅ Örnek: `app-release-v1.0.3.aab`

### 5. Version Bilgileri

**Dosya:** `apps/mobile/pubspec.yaml` (version satırı)

**Mevcut:**
```yaml
version: 1.0.3+2
```

**Neden Önemli:**
- Her yayında version code artırılmalı
- Geçmiş versiyonları takip etmek için

## 🔧 Backend Bilgileri

### 6. Railway Environment Variables

**Önemli Variables:**
```
DATABASE_URL=postgresql://...
DIRECT_URL=postgresql://...
NODE_ENV=production
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
S3_MEDIA_BUCKET=...
FCM_SERVER_KEY=...
```

**Neden Önemli:**
- Backend yeniden kurulum için gerekli
- Production ayarları

**Saklama:**
- ✅ Şifreli dosya
- ✅ Şifre yöneticisi
- ✅ Railway dashboard'dan export edin

### 7. Railway Backend URL

**URL:**
```
https://su-aritma-crm-production-5d49.up.railway.app
```

**Neden Önemli:**
- Mobile app build için gerekli
- API endpoint

## 📱 Google Play Console Bilgileri

### 8. Google Play Console Hesap Bilgileri

**Önemli Bilgiler:**
- Developer hesap e-postası
- Developer hesap şifresi (2FA aktif)
- Application ID: `com.suaritma.app`
- Upload key SHA-256 (yukarıda)

**Saklama:**
- ✅ Şifre yöneticisi
- ✅ Güvenli not

### 9. Google Play Console Upload Key Bilgileri

**Beklenen Upload Key (Eski):**
```
SHA-256: D2:5E:F5:21:63:83:B0:43:32:67:D3:90:37:9A:64:51:6A:B2:F4:A9:7B:01:7D:65:27:22:75:AC:D0:FE:91:AD
```

**Yeni Upload Key:**
```
SHA-256: 8C:BD:C4:01:A8:EA:A5:38:D7:54:37:4B:6A:C4:27:C3:B9:19:E1:9E:60:FD:8E:32:95:4A:71:68:B7:A3:48:A6
```

## 📋 Yedekleme Checklist

### Hemen Yapılacaklar:

- [ ] **Keystore dosyasını yedekle** (EN ÖNEMLİSİ!)
  ```bash
  cp apps/mobile/android/upload-keystore.jks ~/BACKUP/
  ```

- [ ] **Keystore şifrelerini güvenli yere kaydet**
  - Store Password: `asdfgh`
  - Key Password: `asdfgh`
  - Alias: `upload`

- [ ] **SHA-256 parmak izini kaydet**
  - Yeni: `8C:BD:C4:01:A8:EA:A5:38:D7:54:37:4B:6A:C4:27:C3:B9:19:E1:9E:60:FD:8E:32:95:4A:71:68:B7:A3:48:A6`

- [ ] **key.properties dosyasını yedekle**
  ```bash
  cp apps/mobile/android/key.properties ~/BACKUP/
  ```

- [ ] **AAB dosyasını yedekle**
  ```bash
  cp apps/mobile/build/app/outputs/bundle/release/app-release.aab ~/BACKUP/app-release-v1.0.3.aab
  ```

- [ ] **Railway environment variables'ları export et**
  - Railway dashboard → Variables → Export

- [ ] **Google Play Console bilgilerini kaydet**
  - Application ID
  - Upload key bilgileri

## 🔒 Güvenlik Önerileri

1. **Keystore'u ŞİFRELEME ile saklayın**
   - macOS: Disk Utility ile şifreli disk image
   - Windows: BitLocker veya VeraCrypt
   - Cloud: Şifreli zip dosyası

2. **Şifreleri ŞİFRE YÖNETİCİSİNDE saklayın**
   - 1Password, LastPass, Bitwarden, vb.

3. **Çoklu yedekleme yapın**
   - Cloud storage (Google Drive, Dropbox)
   - USB sürücü
   - Yedek bilgisayar

4. **Düzenli yedekleme**
   - Her yayında keystore yedeği alın
   - AAB dosyalarını versiyon numarası ile saklayın

## ⚠️ UYARI

**Keystore kaybedilirse:**
- ❌ Uygulama **ASLA** güncellenemez
- ❌ Yeni uygulama oluşturmak gerekir
- ❌ Tüm kullanıcılar kaybolur
- ❌ Yeni uygulama yeni Application ID ile olur
- ❌ Eski uygulama kaldırılamaz

**Bu yüzden keystore'u MUTLAKA yedekleyin!**

