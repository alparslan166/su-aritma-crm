# Railway Environment Variables

Bu dosya Railway'a eklemeniz gereken environment variables'ları içerir.

## Railway Dashboard'da Eklenecek Variables

Railway dashboard'unda backend servisinize gidin → "Variables" sekmesi → "New Variable" ile ekleyin.

### Database Variables

```
DATABASE_URL=postgresql://postgres:ezxcbkKCcAsFbRpugzHZmOyOOUsaBKPb@switchback.proxy.rlwy.net:10192/railway
```

```
DIRECT_URL=postgresql://postgres:ezxcbkKCcAsFbRpugzHZmOyOOUsaBKPb@switchback.proxy.rlwy.net:10192/railway
```

**ÖNEMLİ:** `DIRECT_URL` ve `DATABASE_URL` aynı değere sahip olmalıdır (Railway PostgreSQL için).

### Application Variables

```
NODE_ENV=production
```

```
PORT=4000
```

**Not:** Railway genellikle `PORT` variable'ını otomatik sağlar, ancak manuel olarak da ayarlayabilirsiniz.

### AWS S3 Variables (Medya yükleme için)

Local `.env` dosyanızdaki değerleri kullanın:

```
AWS_REGION=eu-central-1
```

```
AWS_ACCESS_KEY_ID=your-aws-access-key-id
```

```
AWS_SECRET_ACCESS_KEY=your-aws-secret-access-key
```

```
S3_MEDIA_BUCKET=your-s3-bucket-name
```

### Firebase Cloud Messaging

```
FCM_SERVER_KEY=your-fcm-server-key
```

### Opsiyonel Variables

#### Redis (Queue için - eğer kullanıyorsanız)

```
REDIS_URL=redis://your-redis-url
```

**Not:** Railway Redis servisi eklerseniz, Railway otomatik olarak `REDIS_URL` oluşturur.

#### Maintenance Cron

```
MAINTENANCE_CRON=0 * * * *
```

## Railway'da Nasıl Eklenir?

1. Railway dashboard'unda backend servisinize gidin
2. Üst menüden **"Variables"** sekmesine tıklayın
3. **"New Variable"** butonuna tıklayın
4. Variable name ve value'yu girin
5. **"Add"** butonuna tıklayın
6. Tüm variables'ları ekledikten sonra servis otomatik olarak yeniden deploy olur

## Kontrol Listesi

- [ ] `DATABASE_URL` eklendi
- [ ] `DIRECT_URL` eklendi (DATABASE_URL ile aynı)
- [ ] `NODE_ENV=production` eklendi
- [ ] `AWS_REGION` eklendi
- [ ] `AWS_ACCESS_KEY_ID` eklendi
- [ ] `AWS_SECRET_ACCESS_KEY` eklendi
- [ ] `S3_MEDIA_BUCKET` eklendi
- [ ] `FCM_SERVER_KEY` eklendi
- [ ] `REDIS_URL` eklendi (opsiyonel)
- [ ] `MAINTENANCE_CRON` eklendi (opsiyonel)

## Deploy Sonrası Kontrol

Deploy tamamlandıktan sonra:

1. Railway dashboard'unda **"Deploy Logs"** kontrol edin
2. Migration'ların başarıyla çalıştığını doğrulayın
3. Health check endpoint'ini test edin: `https://your-app.railway.app/api/health`

