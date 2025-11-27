# Railway Migration Hatası Çözümü

## Sorun

`20251118223050_name` migration'ı failed durumda ve yeni migration'lar uygulanamıyor.

## Çözüm 1: Railway'de Start Command Geçici Değiştirme (Önerilen)

### Adım 1: Railway Dashboard'a Gidin

1. Railway dashboard → Projeniz → `su-aritma-crm` servisi
2. **"Settings"** sekmesine gidin
3. **"Deploy"** bölümünde **"Custom Start Command"** bulun

### Adım 2: Start Command'ı Geçici Olarak Değiştirin

**Mevcut Start Command:**
```
npx prisma migrate deploy && npm start
```

**Geçici Start Command (Failed migration'ı resolve etmek için):**
```
npx prisma migrate resolve --rolled-back 20251118223050_name && npx prisma migrate deploy && npm start
```

### Adım 3: Deploy Edin

1. "Save" butonuna tıklayın
2. Railway otomatik olarak yeni deploy başlatır
3. Deploy tamamlandıktan sonra start command'ı eski haline döndürün

### Adım 4: Start Command'ı Eski Haline Döndürün

Deploy başarılı olduktan sonra:
```
npx prisma migrate deploy && npm start
```

## Çözüm 2: Railway'de SQL ile Manuel Düzeltme

Eğer Çözüm 1 çalışmazsa:

### Adım 1: Railway PostgreSQL'e Bağlanın

1. Railway dashboard → PostgreSQL servisinize gidin
2. **"Connect"** sekmesine tıklayın
3. Connection string'i kopyalayın

### Adım 2: SQL Çalıştırın

Railway'de **"Query"** sekmesine gidin veya bir PostgreSQL client kullanın:

```sql
-- Failed migration'ı sil
DELETE FROM "_prisma_migrations" 
WHERE migration_name = '20251118223050_name';
```

### Adım 3: Deploy Tekrar Deneyin

Railway otomatik olarak migration'ları uygulayacaktır.

## Çözüm 3: Database'i Sıfırlama (Son Çare)

⚠️ **UYARI:** Bu işlem tüm verileri siler!

Eğer production'da veri yoksa veya test ortamındaysanız:

1. Railway dashboard → PostgreSQL servisi
2. **"Settings"** → **"Delete Database"**
3. Database'i silin ve yeniden oluşturun
4. Railway otomatik olarak migration'ları uygulayacaktır

## Kontrol

Deploy tamamlandıktan sonra:

1. **"Deploy Logs"** sekmesinde hata olmadığından emin olun
2. **"HTTP Logs"** sekmesinde uygulamanın çalıştığını kontrol edin
3. API endpoint'lerini test edin: `https://su-aritma-crm-production.up.railway.app/api/health`

## Önleme

Gelecekte bu sorunu önlemek için:

1. Migration'ları test etmeden production'a push etmeyin
2. Migration'ları silmeden önce database'den kaldırın
3. Migration'ları geri almak için `prisma migrate resolve` kullanın

