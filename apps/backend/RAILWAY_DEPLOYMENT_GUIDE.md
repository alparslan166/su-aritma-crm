# Railway Deployment - Kapsamlı Rehber

Bu rehber, backend'i Railway üzerinden sorunsuz bir şekilde deploy etmek için tüm adımları içerir.

## 📋 Ön Hazırlık Kontrol Listesi

Deploy etmeden önce aşağıdakilerin hazır olduğundan emin olun:

- [ ] Railway hesabı oluşturuldu
- [ ] GitHub repository'si Railway'a bağlandı
- [ ] PostgreSQL database servisi eklendi
- [ ] Environment variables hazır
- [ ] Root directory ayarlandı (`apps/backend`)

## 🚀 Adım 1: Railway Projesi Oluşturma

### 1.1 Railway Dashboard'a Giriş

1. [Railway.app](https://railway.app) adresine gidin
2. GitHub hesabınızla giriş yapın

### 1.2 Yeni Proje Oluşturma

1. **"New Project"** butonuna tıklayın
2. **"Deploy from GitHub repo"** seçeneğini seçin
3. Repository'nizi seçin: `su-aritma-crm`
4. Projeyi oluşturun

### 1.3 Backend Servisi Ekleme

1. Proje oluşturulduktan sonra **"New"** butonuna tıklayın
2. **"GitHub Repo"** seçeneğini seçin
3. Repository'nizi tekrar seçin
4. Servis adını **"backend"** olarak ayarlayın

## ⚙️ Adım 2: Root Directory Ayarlama

**KRİTİK**: Monorepo yapısı nedeniyle root directory ayarlanmalı!

### 2.1 Railway Dashboard'dan

1. Backend servisine tıklayın
2. **"Settings"** sekmesine gidin
3. **"Source"** veya **"General"** sekmesinde
4. **"Root Directory"** alanını bulun
5. `apps/backend` yazın
6. **"Save"** butonuna tıklayın

### 2.2 Otomatik (railway.json)

`railway.json` dosyası zaten mevcut ve `rootDirectory: "apps/backend"` ayarlı. Railway otomatik olarak algılayacaktır.

## 🗄️ Adım 3: PostgreSQL Database Ekleme

### 3.1 Database Servisi Ekleme

1. Proje sayfasında **"New"** butonuna tıklayın
2. **"Database"** → **"Add PostgreSQL"** seçin
3. Database servisi otomatik olarak oluşturulacak

### 3.2 Database URL'i Alma

1. PostgreSQL servisine tıklayın
2. **"Variables"** sekmesine gidin
3. `DATABASE_URL` değişkenini bulun
4. **ÖNEMLİ**: 
   - **Private/Internal URL** kullanın (backend aynı projede olduğu için)
   - Railway genellikle sadece bir URL gösterir, bu private URL'dir
   - Eğer hem "Private" hem "Public" URL görüyorsanız, **Private URL**'i kullanın
   - Private URL formatı: `postgresql://postgres:password@switchback.proxy.rlwy.net:port/railway`
   - Public URL formatı: `postgresql://postgres:password@containers-us-west-xxx.railway.app:port/railway`
5. `DATABASE_URL` değerini kopyalayın

## 🔐 Adım 4: Environment Variables Ayarlama

### 4.1 Backend Servisinde Variables

Backend servisine gidin → **"Variables"** sekmesi → Aşağıdaki variables'ları ekleyin:

#### Zorunlu Variables

```env
NODE_ENV=production
PORT=4000
NODE_VERSION=22.12.0
DATABASE_URL=postgresql://postgres:password@host:port/railway
DIRECT_URL=postgresql://postgres:password@host:port/railway
```

**ÖNEMLİ**: 
- `NODE_VERSION=22.12.0` ekleyin (Prisma 7.0.1 için gerekli - 22.12+)
- Railway bu environment variable'ı kullanarak doğru Node.js versiyonunu kurar

**ÖNEMLİ**: 
- `DATABASE_URL` ve `DIRECT_URL` **aynı değer** olmalı (Railway PostgreSQL için)
- Railway PostgreSQL servisinden **Private/Internal URL**'i kopyalayın (Public URL değil!)
- Backend servisi aynı Railway projesinde olduğu için private URL kullanılır
- `DIRECT_URL` için aynı değeri kullanın
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

```env
REDIS_URL=redis://host:port
```

Eğer Redis kullanmak istiyorsanız:
1. Proje sayfasında **"New"** → **"Database"** → **"Add Redis"**
2. Redis servisinden `REDIS_URL`'i kopyalayın

#### Maintenance Cron (Opsiyonel)

```env
MAINTENANCE_CRON=0 * * * *
```

### 4.2 Variables Ekleme Yöntemleri

**Yöntem 1: Railway Dashboard**
1. Backend servisi → **"Variables"** sekmesi
2. **"New Variable"** butonuna tıklayın
3. Key ve Value'yu girin
4. **"Add"** butonuna tıklayın

**Yöntem 2: Railway CLI**
```bash
railway variables set NODE_ENV=production
railway variables set DATABASE_URL="postgresql://..."
```

## 🔧 Adım 5: Build ve Deploy Yapılandırması

### 5.1 Mevcut Yapılandırma

`railway.json` dosyası zaten mevcut ve doğru yapılandırılmış:

```json
{
  "rootDirectory": "apps/backend",
  "build": {
    "builder": "NIXPACKS",
    "buildCommand": "npm install && npm run build && npx prisma generate"
  },
  "deploy": {
    "startCommand": "npx prisma migrate resolve --applied 20251118223050_name 2>/dev/null || true; npx prisma migrate resolve --applied 20251119132546_add_admin_password 2>/dev/null || true; npx prisma migrate deploy && npm start",
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
```

### 5.2 Build Süreci

Railway şu adımları otomatik olarak yapacak:

1. **Setup**: Node.js 24 ve npm 10 kurulumu (Prisma 7.0.1 uyumluluğu için)
2. **Install**: `npm ci` (dependencies kurulumu)
3. **Build**: `npm run build` (TypeScript derleme)
4. **Prisma Generate**: `npx prisma generate` (Prisma client oluşturma)
5. **Deploy**: Migration'ları çalıştır ve uygulamayı başlat

## 🌐 Adım 6: Public URL Oluşturma

### 6.1 Domain Oluşturma

1. Backend servisine gidin
2. **"Settings"** → **"Networking"** sekmesine gidin
3. **"Generate Domain"** butonuna tıklayın
4. Railway otomatik olarak bir domain oluşturacak
5. Domain formatı: `https://your-app-name.railway.app`

### 6.2 Custom Domain (Opsiyonel)

1. **"Networking"** sekmesinde **"Custom Domain"** bölümüne gidin
2. Domain'inizi ekleyin
3. DNS ayarlarını yapın

## ✅ Adım 7: Deploy ve Test

### 7.1 İlk Deploy

1. Railway otomatik olarak deploy başlatacak (git push sonrası)
2. Veya manuel olarak **"Deploy"** butonuna tıklayın
3. **"Deployments"** sekmesinden deploy durumunu takip edin

### 7.2 Deploy Loglarını Kontrol Etme

1. **"Deployments"** sekmesine gidin
2. En son deployment'a tıklayın
3. **"View Logs"** butonuna tıklayın
4. Build ve deploy loglarını kontrol edin

### 7.3 Health Check

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

## 🔍 Adım 8: Sorun Giderme

### 8.1 Build Hataları

**Sorun**: Build başarısız oluyor

**Çözüm**:
1. Deploy loglarını kontrol edin
2. `package.json` dosyasının doğru olduğundan emin olun
3. Node.js versiyonunu kontrol edin (20+ gerekli)
4. Root directory'nin `apps/backend` olduğundan emin olun

### 8.2 Migration Hataları

**Sorun**: Migration'lar çalışmıyor

**Çözüm**:
1. `DATABASE_URL` ve `DIRECT_URL`'in aynı olduğundan emin olun
2. Database'in erişilebilir olduğunu kontrol edin
3. Migration dosyalarının mevcut olduğundan emin olun

### 8.3 Port Hataları

**Sorun**: Port hatası alıyorsunuz

**Çözüm**:
1. Railway otomatik olarak `PORT` environment variable'ını sağlar
2. Kodda `process.env.PORT` kullanıldığından emin olun
3. Varsayılan port 4000, Railway'ın sağladığı port'u kullanın

### 8.4 Database Bağlantı Hataları

**Sorun**: Database'e bağlanamıyor

**Çözüm**:
1. `DATABASE_URL`'in doğru olduğundan emin olun
2. **Private/Internal URL kullandığınızdan emin olun** (Public URL değil!)
3. PostgreSQL servisinin çalıştığından emin olun
4. Backend servisi aynı Railway projesinde olduğu için private URL kullanılmalı
5. Eğer public URL kullanıyorsanız, private URL'e geçin

### 8.5 Environment Variable Hataları

**Sorun**: Environment variable bulunamıyor

**Çözüm**:
1. Variables sekmesinde tüm gerekli variables'ların olduğundan emin olun
2. Variable isimlerinin doğru olduğundan emin olun (büyük/küçük harf duyarlı)
3. Deploy sonrası variables'ların yüklendiğinden emin olun

## 📊 Adım 9: Monitoring ve Logs

### 9.1 Logs Görüntüleme

**Railway Dashboard**:
1. Backend servisi → **"Deployments"** sekmesi
2. En son deployment'a tıklayın
3. **"View Logs"** butonuna tıklayın

**Railway CLI**:
```bash
railway logs --tail 100
```

### 9.2 Metrics

1. Backend servisi → **"Metrics"** sekmesi
2. CPU, Memory, Network kullanımını görüntüleyin

## 🔄 Adım 10: Güncelleme ve Yeniden Deploy

### 10.1 Otomatik Deploy

Railway, GitHub'a push yaptığınızda otomatik olarak deploy başlatır.

### 10.2 Manuel Deploy

1. Railway Dashboard → Backend servisi
2. **"Deployments"** sekmesi
3. **"Redeploy"** butonuna tıklayın

### 10.3 Railway CLI ile Deploy

```bash
cd apps/backend
railway up
```

## 📝 Kontrol Listesi

Deploy öncesi kontrol:

- [ ] Root directory `apps/backend` olarak ayarlandı
- [ ] PostgreSQL database servisi eklendi
- [ ] `NODE_ENV=production` ayarlandı
- [ ] `DATABASE_URL` ve `DIRECT_URL` aynı değer ve doğru
- [ ] AWS S3 variables ayarlandı (medya yükleme için)
- [ ] `FCM_SERVER_KEY` ayarlandı (push notification için)
- [ ] `REDIS_URL` ayarlandı (opsiyonel, maintenance için)
- [ ] Public domain oluşturuldu
- [ ] Health check başarılı
- [ ] Logs temiz (hata yok)

## 🎯 Hızlı Başlangıç Komutları

### Railway CLI Kurulumu

```bash
# macOS
brew install railway

# veya npm
npm install -g @railway/cli
```

### Railway CLI ile Variables Ayarlama

```bash
# Giriş yap
railway login

# Projeyi bağla
railway link

# Variables ayarla
railway variables set NODE_ENV=production
railway variables set DATABASE_URL="postgresql://..."
railway variables set DIRECT_URL="postgresql://..."

# Deploy et
cd apps/backend
railway up

# Logs görüntüle
railway logs --tail 50
```

## 🔗 İlgili Dokümantasyon

- [Production Ready Guide](./PRODUCTION_READY.md)
- [Google Play Deployment](./GOOGLE_PLAY_DEPLOYMENT.md)
- [Railway Setup](./RAILWAY_SETUP.md)
- [Environment Variables](./RAILWAY_ENV_VARS.md)

## 💡 İpuçları

1. **İlk Deploy**: İlk deploy biraz uzun sürebilir (dependencies kurulumu)
2. **Migration'lar**: Migration'lar otomatik olarak çalışır, hata durumunda logları kontrol edin
3. **Variables**: Sensitive data için Railway'ın secret management özelliğini kullanın
4. **Monitoring**: Düzenli olarak logs ve metrics'i kontrol edin
5. **Backup**: Database için düzenli backup alın (Railway otomatik yapar)

Başarılar! 🚀

