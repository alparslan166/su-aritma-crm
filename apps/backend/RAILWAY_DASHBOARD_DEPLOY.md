# Railway Dashboard Deployment Rehberi

Railway projesi oluşturuldu: **su-aritma-backend**
Proje URL: https://railway.com/project/ab8c19a4-e652-4a51-af71-cffc0c2cf5c3

## 🚀 Adım Adım Deployment

### 1. Railway Dashboard'a Giriş

1. [Railway Dashboard](https://railway.app) adresine gidin
2. Giriş yapın (alp84202@gmail.com)
3. **su-aritma-backend** projesine tıklayın

### 2. PostgreSQL Database Ekleme

1. Proje sayfasında **"New"** butonuna tıklayın
2. **"Database"** → **"Add PostgreSQL"** seçin
3. Database servisi otomatik olarak oluşturulacak
4. Database servisine tıklayın
5. **"Variables"** sekmesine gidin
6. `DATABASE_URL` veya `POSTGRES_URL` değerini kopyalayın (Private/Internal URL kullanın)

### 3. Backend Servisi Oluşturma

1. Proje sayfasında **"New"** butonuna tıklayın
2. **"GitHub Repo"** seçeneğini seçin
3. Repository'nizi seçin: `su-aritma-crm`
4. Servis adı otomatik olarak oluşturulacak

### 4. Root Directory Ayarlama

1. Backend servisine tıklayın
2. **"Settings"** sekmesine gidin
3. **"Source"** veya **"General"** sekmesinde
4. **"Root Directory"** alanını bulun
5. `apps/backend` yazın
6. **"Save"** butonuna tıklayın

### 5. Environment Variables Ayarlama

Backend servisi → **"Variables"** sekmesi → Aşağıdaki variables'ları ekleyin:

#### Zorunlu Variables

```env
NODE_ENV=production
PORT=4000
```

#### Database Variables

PostgreSQL servisinden kopyaladığınız URL'i kullanın:

```env
DATABASE_URL=postgresql://postgres:password@switchback.proxy.rlwy.net:port/railway
DIRECT_URL=postgresql://postgres:password@switchback.proxy.rlwy.net:port/railway
```

**ÖNEMLİ**: 
- `DATABASE_URL` ve `DIRECT_URL` **aynı değer** olmalı
- **Private/Internal URL** kullanın (Public URL değil!)
- Private URL genellikle `switchback.proxy.rlwy.net` içerir

#### AWS S3 Variables (Medya yükleme için)

```env
AWS_REGION=eu-central-1
AWS_ACCESS_KEY_ID=your-access-key-id
AWS_SECRET_ACCESS_KEY=your-secret-access-key
S3_MEDIA_BUCKET=your-bucket-name
```

#### Firebase Cloud Messaging

```env
FCM_SERVER_KEY=your-fcm-server-key
```

#### Redis (Opsiyonel - Maintenance reminders için)

Eğer Redis kullanmak istiyorsanız:
1. Proje sayfasında **"New"** → **"Database"** → **"Add Redis"**
2. Redis servisinden `REDIS_URL`'i kopyalayın
3. Backend servisine `REDIS_URL` variable'ını ekleyin

### 6. Public Domain Oluşturma

1. Backend servisine tıklayın
2. **"Settings"** → **"Networking"** sekmesine gidin
3. **"Generate Domain"** butonuna tıklayın
4. Domain formatı: `https://your-app-name.railway.app`
5. Bu domain'i mobile app'te kullanacaksınız

### 7. Deploy

1. Railway otomatik olarak deploy başlatacak (GitHub'a push sonrası)
2. Veya manuel olarak **"Deployments"** sekmesinden **"Redeploy"** butonuna tıklayın
3. **"Deployments"** sekmesinden deploy durumunu takip edin
4. Deploy tamamlandıktan sonra logları kontrol edin

### 8. Health Check

Deploy tamamlandıktan sonra:

```bash
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

- [ ] PostgreSQL database servisi eklendi
- [ ] Backend servisi oluşturuldu (GitHub repo bağlandı)
- [ ] Root directory `apps/backend` olarak ayarlandı
- [ ] `NODE_ENV=production` ayarlandı
- [ ] `PORT=4000` ayarlandı
- [ ] `DATABASE_URL` ve `DIRECT_URL` ayarlandı (aynı değer, private URL)
- [ ] AWS S3 variables ayarlandı (medya yükleme için)
- [ ] `FCM_SERVER_KEY` ayarlandı (push notification için)
- [ ] Public domain oluşturuldu
- [ ] Deploy başarılı
- [ ] Health check başarılı

## 🔍 Sorun Giderme

### Build Hataları

1. **Deployments** sekmesinden logları kontrol edin
2. Root directory'nin `apps/backend` olduğundan emin olun
3. `package.json` dosyasının doğru olduğundan emin olun

### Migration Hataları

1. `DATABASE_URL` ve `DIRECT_URL`'in aynı olduğundan emin olun
2. Database'in erişilebilir olduğunu kontrol edin
3. Migration dosyalarının mevcut olduğundan emin olun

### Database Bağlantı Hataları

1. `DATABASE_URL`'in doğru olduğundan emin olun
2. **Private/Internal URL kullandığınızdan emin olun** (Public URL değil!)
3. PostgreSQL servisinin çalıştığından emin olun

## 📊 Monitoring

### Logs Görüntüleme

1. Backend servisi → **"Deployments"** sekmesi
2. En son deployment'a tıklayın
3. **"View Logs"** butonuna tıklayın

### Metrics

1. Backend servisi → **"Metrics"** sekmesi
2. CPU, Memory, Network kullanımını görüntüleyin

## 🔄 Güncelleme

### Otomatik Deploy

Railway, GitHub'a push yaptığınızda otomatik olarak deploy başlatır.

### Manuel Deploy

1. Backend servisi → **"Deployments"** sekmesi
2. **"Redeploy"** butonuna tıklayın

## 🎯 Sonraki Adımlar

1. ✅ Railway projesi oluşturuldu
2. ⏳ PostgreSQL database ekle (Dashboard'dan)
3. ⏳ Backend servisi oluştur (GitHub repo bağla)
4. ⏳ Root directory ayarla (`apps/backend`)
5. ⏳ Environment variables ayarla
6. ⏳ Public domain oluştur
7. ⏳ Deploy et ve test et

Başarılar! 🚀

