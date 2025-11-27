# Railway Deployment Setup

Bu dosya Railway'a deploy için gerekli konfigürasyonları açıklar.

## Railway Konfigürasyonu

Proje Railway'a deploy edilmek için hazırlanmıştır. `railway.json` dosyası Railway'ın build ve deploy süreçlerini yönetir.

## İlk Kurulum

1. Railway dashboard'unda yeni bir proje oluşturun
2. GitHub repository'nizi bağlayın
3. **ÖNEMLİ**: Service Settings > Root Directory'yi `apps/backend` olarak ayarlayın (monorepo yapısı nedeniyle)
4. PostgreSQL database servisi ekleyin
5. Environment variables'ları ayarlayın (aşağıya bakın)

## Environment Variables

Railway dashboard'unda aşağıdaki environment variables'ları ayarlamanız gerekmektedir:

### Zorunlu Variables

- `NODE_ENV`: `production`
- `PORT`: Railway otomatik olarak `PORT` environment variable'ını sağlar, ancak manuel olarak da ayarlayabilirsiniz
- `DATABASE_URL`: Railway PostgreSQL connection string
  - Örnek: `postgresql://postgres:password@switchback.proxy.rlwy.net:10192/railway`
  - Railway PostgreSQL servisi eklediğinizde otomatik olarak oluşturulur, ancak manuel olarak da ekleyebilirsiniz
- `DIRECT_URL`: Prisma migration'ları için gerekli. `DATABASE_URL` ile **aynı değeri** kullanın
  - Örnek: `postgresql://postgres:password@switchback.proxy.rlwy.net:10192/railway`
  - **ÖNEMLİ**: Railway PostgreSQL için `DATABASE_URL` ve `DIRECT_URL` aynı olmalıdır

### AWS S3 Variables (Medya yükleme için)

- `AWS_REGION`: AWS bölgeniz (örn: `eu-central-1`)
- `AWS_ACCESS_KEY_ID`: AWS access key
- `AWS_SECRET_ACCESS_KEY`: AWS secret key
- `S3_MEDIA_BUCKET`: S3 bucket adı

### Firebase Cloud Messaging

- `FCM_SERVER_KEY`: Firebase Cloud Messaging server key (push notification'lar için)

### Redis (Opsiyonel - Queue için)

- `REDIS_URL`: Redis connection string (BullMQ için). Railway Redis servisi eklediğinizde otomatik oluşturulur

### Maintenance Cron (Opsiyonel)

- `MAINTENANCE_CRON`: Cron expression (varsayılan: `0 * * * *` - her saat başı)

## Railway'da Servis Ekleme

1. **PostgreSQL Database**: Railway dashboard'unda "New" > "Database" > "PostgreSQL" seçin
   - Railway otomatik olarak `DATABASE_URL` ve `PGDATABASE`, `PGHOST`, `PGPASSWORD`, `PGPORT`, `PGUSER` variable'larını oluşturur
   - Eğer manuel olarak ekliyorsanız, PostgreSQL servisinin "Variables" sekmesinden `DATABASE_URL` değerini kopyalayın
   - **`DIRECT_URL` için `DATABASE_URL` ile aynı değeri kullanın** (Railway PostgreSQL için aynı connection string kullanılır)
   - Örnek URL formatı: `postgresql://postgres:password@switchback.proxy.rlwy.net:10192/railway`

2. **Redis (Opsiyonel)**: Queue'lar için Redis eklemek isterseniz "New" > "Database" > "Redis" seçin
   - Railway otomatik olarak `REDIS_URL` oluşturur

## Migration'lar

Railway deploy sırasında otomatik olarak `prisma migrate deploy` komutunu çalıştırır. Bu, production database'inizi migration'larla senkronize eder.

## Build ve Deploy Süreci

1. **Build**: `npm install && npm run build && npx prisma generate`
2. **Deploy**: `npx prisma migrate deploy && npm start`

## Notlar

- Railway otomatik olarak `PORT` environment variable'ını sağlar
- Database migration'ları her deploy'da otomatik çalışır
- Prisma Client her build'de otomatik generate edilir (`postinstall` script ile)
- Production'da `NODE_ENV=production` olarak ayarlayın

## Troubleshooting

### Migration Hataları

Eğer migration hataları alırsanız:
1. Railway dashboard'unda "Deploy Logs" kontrol edin
2. `DIRECT_URL` variable'ının doğru ayarlandığından emin olun
3. Database'in migration'ları kabul edecek durumda olduğundan emin olun

### Build Hataları

Eğer build hataları alırsanız:
1. Local'de `npm run build` komutunun çalıştığından emin olun
2. TypeScript hatalarını kontrol edin: `npm run typecheck`
3. Railway build logs'ları kontrol edin

