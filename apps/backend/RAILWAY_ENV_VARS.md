# Railway Environment Variables

Backend'in Railway'de çalışması için gerekli environment variable'lar:

## Otomatik Set Edilenler (Railway tarafından)

- `PORT` - Railway otomatik set eder
- `DATABASE_URL` - PostgreSQL servisi eklendiğinde otomatik set edilir
- `NODE_ENV` - Production olarak set edilir

## Manuel Ayarlanması Gerekenler

### 1. Database (PostgreSQL)
Railway Dashboard'dan PostgreSQL servisi ekleyin, `DATABASE_URL` otomatik set edilir.

### 2. AWS S3 (Medya Yükleme)
```bash
railway variables set AWS_REGION=eu-central-1
railway variables set AWS_ACCESS_KEY_ID=your-access-key-id
railway variables set AWS_SECRET_ACCESS_KEY=your-secret-access-key
railway variables set S3_MEDIA_BUCKET=your-bucket-name
```

### 3. Firebase Cloud Messaging
```bash
railway variables set FCM_SERVER_KEY=your-fcm-server-key
```

### 4. Redis (Opsiyonel - Maintenance Queue için)
```bash
railway add --database redis
# REDIS_URL otomatik set edilir
```

### 5. Email Service (Opsiyonel - Resend)
```bash
railway variables set RESEND_API_KEY=re_xxxxxxxx
railway variables set EMAIL_FROM=onboarding@resend.dev
```

**Not:** Email servisi API key olmadan da çalışır (sadece email gönderemez, log'a yazar).

### 6. CORS (Opsiyonel)
```bash
# Tüm origin'lere izin vermek için (mobile app için):
railway variables set ALLOWED_ORIGINS=

# Veya belirli domain'ler için:
railway variables set ALLOWED_ORIGINS=https://example.com,https://app.example.com
```

## Railway CLI ile Kontrol

```bash
# Tüm environment variables'ları göster
railway variables

# Belirli bir variable'ı göster
railway variables get DATABASE_URL
```

## Mobile App Bağlantısı

Mobile app'in Railway backend'e bağlanması için:

1. Railway Dashboard'dan backend servisine public domain oluşturun
2. Mobile app'te `API_BASE_URL` environment variable'ını Railway domain'ine set edin:
   ```bash
   flutter run --dart-define=API_BASE_URL=https://your-app.railway.app/api
   ```

Veya `apps/mobile/lib/core/constants/app_config.dart` dosyasında default URL'i güncelleyin.

