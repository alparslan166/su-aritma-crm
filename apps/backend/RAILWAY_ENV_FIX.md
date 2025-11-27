# Railway Environment Variables Düzeltme Rehberi

Railway deploy hatası: `DATABASE_URL` environment variable bulunamıyor.

## Hızlı Çözüm

Railway dashboard'unda environment variables'ları ekleyin:

### 1. Railway Dashboard'a Gidin

1. https://railway.app adresine gidin
2. Projenize tıklayın: `su-aritma-crm`
3. Service'e tıklayın: `su-aritma-crm`
4. **"Variables"** sekmesine tıklayın

### 2. Zorunlu Environment Variables Ekleme

Aşağıdaki variable'ları ekleyin:

#### `DATABASE_URL`
```
postgresql://postgres:ezxcbkKCcAsFbRpugzHZmOyOOUsaBKPb@switchback.proxy.rlwy.net:10192/railway
```

**Nasıl Bulunur:**
- Railway dashboard'unda PostgreSQL servisinize gidin
- "Variables" sekmesinde `DATABASE_URL` değerini kopyalayın
- Veya PostgreSQL servisinin "Connect" sekmesinden connection string'i alın

#### `DIRECT_URL`
```
postgresql://postgres:ezxcbkKCcAsFbRpugzHZmOyOOUsaBKPb@switchback.proxy.rlwy.net:10192/railway
```

**ÖNEMLİ:** Railway PostgreSQL için `DIRECT_URL` ve `DATABASE_URL` **aynı değeri** kullanmalıdır.

#### `NODE_ENV`
```
production
```

### 3. Diğer Environment Variables (Opsiyonel ama Önerilen)

#### AWS S3 (Medya yükleme için)
```
AWS_REGION=eu-central-1
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
S3_MEDIA_BUCKET=your-bucket-name
```

#### Firebase Cloud Messaging
```
FCM_SERVER_KEY=your-fcm-server-key
```

#### Redis (Opsiyonel - Queue için)
```
REDIS_URL=redis://default:password@host:port
```

#### Maintenance Cron (Opsiyonel)
```
MAINTENANCE_CRON=0 * * * *
```

## Railway'de Variable Ekleme Adımları

1. **Variables Sekmesine Gidin**
   - Service sayfasında "Variables" sekmesine tıklayın

2. **"New Variable" Butonuna Tıklayın**

3. **Variable Adı ve Değerini Girin**
   - Örnek:
     - Name: `DATABASE_URL`
     - Value: `postgresql://postgres:ezxcbkKCcAsFbRpugzHZmOyOOUsaBKPb@switchback.proxy.rlwy.net:10192/railway`

4. **"Add" Butonuna Tıklayın**

5. **Deploy Otomatik Başlar**
   - Variable eklendikten sonra Railway otomatik olarak yeni bir deploy başlatır

## PostgreSQL Database URL'ini Bulma

Eğer `DATABASE_URL` değerini bilmiyorsanız:

1. Railway dashboard'unda PostgreSQL servisinize gidin
2. "Variables" sekmesine tıklayın
3. `DATABASE_URL` veya `PGDATABASE`, `PGHOST`, `PGPASSWORD`, `PGPORT`, `PGUSER` variable'larını bulun
4. Manuel olarak oluşturun:
   ```
   postgresql://PGUSER:PGPASSWORD@PGHOST:PGPORT/PGDATABASE
   ```

## Kontrol

Variable'ları ekledikten sonra:

1. Railway otomatik olarak deploy başlatır
2. "Deployments" sekmesinde yeni deploy'u görebilirsiniz
3. "Deploy Logs" sekmesinde hataların düzelip düzelmediğini kontrol edin
4. Deploy başarılı olduğunda uygulama çalışır

## Sorun Giderme

### Hala "DATABASE_URL not found" Hatası Alıyorum

1. Variable'ın doğru service'e eklendiğinden emin olun
2. Variable adının tam olarak `DATABASE_URL` olduğundan emin olun (büyük/küçük harf duyarlı)
3. Deploy'un tamamlanmasını bekleyin (birkaç dakika sürebilir)
4. "Deploy Logs" sekmesinde hata mesajlarını kontrol edin

### PostgreSQL Bağlantı Hatası

1. PostgreSQL servisinin çalıştığından emin olun
2. `DATABASE_URL` değerinin doğru olduğundan emin olun
3. Password'un doğru olduğundan emin olun

## Örnek Variable Listesi

Railway'de şu variable'lar olmalı:

```
NODE_ENV=production
DATABASE_URL=postgresql://postgres:ezxcbkKCcAsFbRpugzHZmOyOOUsaBKPb@switchback.proxy.rlwy.net:10192/railway
DIRECT_URL=postgresql://postgres:ezxcbkKCcAsFbRpugzHZmOyOOUsaBKPb@switchback.proxy.rlwy.net:10192/railway
AWS_REGION=eu-central-1
AWS_ACCESS_KEY_ID=your-key
AWS_SECRET_ACCESS_KEY=your-secret
S3_MEDIA_BUCKET=your-bucket
FCM_SERVER_KEY=your-key
```

