# Railway Deployment - Hızlı Başlangıç

Bu rehber, backend ve database'i Railway'e deploy etmek için adım adım talimatlar içerir.

## 🚀 Hızlı Başlangıç

### 1. Railway CLI Kurulumu

```bash
# macOS
brew install railway

# veya npm ile
npm install -g @railway/cli
```

### 2. Railway'a Giriş

```bash
railway login
```

### 3. Yeni Proje Oluştur

```bash
cd apps/backend
railway init
```

Bu komut:
- Yeni bir Railway projesi oluşturur
- Projeyi mevcut dizine bağlar
- `.railway` klasörü oluşturur

### 4. PostgreSQL Database Ekle

Railway Dashboard'dan:
1. Proje sayfasına gidin
2. **"New"** butonuna tıklayın
3. **"Database"** → **"Add PostgreSQL"** seçin
4. Database servisi otomatik oluşturulur

Veya Railway CLI ile:
```bash
railway add --database postgres
```

### 5. Environment Variables Ayarla

#### Zorunlu Variables

```bash
railway variables set NODE_ENV=production
railway variables set PORT=4000
```

#### Database URL (Otomatik)

Railway PostgreSQL servisi otomatik olarak `DATABASE_URL` ve `POSTGRES_URL` environment variable'larını ekler. Bu değerleri kullanın:

```bash
# Database URL'i al
railway variables

# Eğer DATABASE_URL yoksa, POSTGRES_URL'i kullan
railway variables set DATABASE_URL=$POSTGRES_URL
railway variables set DIRECT_URL=$POSTGRES_URL
```

**ÖNEMLİ**: Railway PostgreSQL için `DATABASE_URL` ve `DIRECT_URL` aynı değer olmalı (private/internal URL).

#### AWS S3 Variables (Medya yükleme için)

```bash
railway variables set AWS_REGION=eu-central-1
railway variables set AWS_ACCESS_KEY_ID=your-access-key-id
railway variables set AWS_SECRET_ACCESS_KEY=your-secret-access-key
railway variables set S3_MEDIA_BUCKET=your-bucket-name
```

#### Firebase Cloud Messaging

```bash
railway variables set FCM_SERVER_KEY=your-fcm-server-key
```

#### Redis (Opsiyonel)

Eğer Redis kullanmak istiyorsanız:
```bash
railway add --database redis
railway variables set REDIS_URL=$REDIS_URL
```

### 6. Root Directory Ayarla

Railway Dashboard'dan:
1. Backend servisine tıklayın
2. **"Settings"** → **"Source"** sekmesine gidin
3. **"Root Directory"** alanına `apps/backend` yazın
4. **"Save"** butonuna tıklayın

Veya `railway.json` dosyası zaten `rootDirectory: "apps/backend"` içeriyor, Railway otomatik algılayacaktır.

### 7. Deploy Et

```bash
cd apps/backend
railway up
```

Bu komut:
- Kodunuzu Railway'a yükler
- Build işlemini başlatır
- Migration'ları çalıştırır
- Uygulamayı başlatır

### 8. Public Domain Oluştur

Railway Dashboard'dan:
1. Backend servisine tıklayın
2. **"Settings"** → **"Networking"** sekmesine gidin
3. **"Generate Domain"** butonuna tıklayın
4. Domain formatı: `https://your-app-name.railway.app`

### 9. Health Check

Deploy tamamlandıktan sonra:

```bash
# Domain'i al
railway domain

# Health check
curl https://your-app.railway.app/api/health
```

Beklenen yanıt:
```json
{
  "success": true,
  "uptime": ...,
  "timestamp": "..."
}
```

## 📋 Kontrol Listesi

Deploy öncesi:
- [ ] Railway CLI kuruldu
- [ ] Railway'a giriş yapıldı
- [ ] Proje oluşturuldu ve bağlandı
- [ ] PostgreSQL database servisi eklendi
- [ ] `NODE_ENV=production` ayarlandı
- [ ] `DATABASE_URL` ve `DIRECT_URL` ayarlandı (aynı değer)
- [ ] AWS S3 variables ayarlandı (medya yükleme için)
- [ ] `FCM_SERVER_KEY` ayarlandı (push notification için)
- [ ] Root directory `apps/backend` olarak ayarlandı
- [ ] Public domain oluşturuldu
- [ ] Health check başarılı

## 🔍 Sorun Giderme

### Build Hataları

```bash
# Logs'u kontrol et
railway logs --tail 100

# Build'i tekrar dene
railway up
```

### Migration Hataları

```bash
# Database bağlantısını kontrol et
railway variables

# Migration'ları manuel çalıştır
railway run npx prisma migrate deploy
```

### Port Hataları

Railway otomatik olarak `PORT` environment variable'ını sağlar. Kodda `process.env.PORT` kullanıldığından emin olun.

### Database Bağlantı Hataları

1. `DATABASE_URL`'in doğru olduğundan emin olun
2. Railway PostgreSQL servisinin çalıştığından emin olun
3. Private/Internal URL kullandığınızdan emin olun (Public URL değil!)

## 📊 Monitoring

### Logs Görüntüleme

```bash
# Canlı logs
railway logs --tail 50

# Son 100 satır
railway logs --tail 100
```

### Metrics

Railway Dashboard → Backend servisi → **"Metrics"** sekmesinden CPU, Memory, Network kullanımını görüntüleyin.

## 🔄 Güncelleme

### Otomatik Deploy

GitHub'a push yaptığınızda Railway otomatik olarak deploy başlatır (eğer GitHub repo bağlıysa).

### Manuel Deploy

```bash
cd apps/backend
railway up
```

### Railway Dashboard'dan

1. Backend servisi → **"Deployments"** sekmesi
2. **"Redeploy"** butonuna tıklayın

## 🎯 Hızlı Komutlar

```bash
# Giriş yap
railway login

# Projeyi bağla
railway link

# Variables görüntüle
railway variables

# Variables ayarla
railway variables set KEY=value

# Deploy et
railway up

# Logs görüntüle
railway logs --tail 50

# Domain görüntüle
railway domain

# Servisleri listele
railway status
```

## 📝 Notlar

1. **İlk Deploy**: İlk deploy biraz uzun sürebilir (dependencies kurulumu)
2. **Migration'lar**: Migration'lar otomatik olarak çalışır (`npx prisma migrate deploy`)
3. **Variables**: Sensitive data için Railway'ın secret management özelliğini kullanın
4. **Monitoring**: Düzenli olarak logs ve metrics'i kontrol edin
5. **Backup**: Database için düzenli backup alın (Railway otomatik yapar)

Başarılar! 🚀

