# Railway Migration Hızlı Düzeltme

## Sorun
`20251118223050_name` migration failed durumda ve yeni migration'lar uygulanamıyor.

## Çözüm: PostgreSQL Query ile Manuel Düzeltme

### Adım 1: Railway PostgreSQL'e Bağlanın

1. Railway dashboard → **PostgreSQL servisinize** gidin
2. **"Query"** sekmesine tıklayın (veya **"Connect"** sekmesinden connection string'i alıp bir PostgreSQL client kullanın)

### Adım 2: Failed Migration'ı Silin

**Query sekmesinde şu SQL'i çalıştırın:**

```sql
-- Failed migration'ı _prisma_migrations tablosundan sil
DELETE FROM "_prisma_migrations" 
WHERE migration_name = '20251118223050_name';
```

### Adım 3: Deploy Tekrar Deneyin

1. Railway dashboard → `su-aritma-crm` servisi
2. **"Deployments"** sekmesinde **"Redeploy"** butonuna tıklayın
3. Veya yeni bir commit push edin

## Alternatif: Start Command ile Otomatik Düzeltme

Eğer Query çalışmazsa:

1. Railway dashboard → `su-aritma-crm` servisi → **Settings**
2. **"Custom Start Command"** bölümüne gidin
3. Şu komutu yapıştırın:

```bash
npx prisma migrate resolve --applied 20251118223050_name 2>&1 || npx prisma migrate resolve --rolled-back 20251118223050_name 2>&1 || true; npx prisma migrate deploy && npm start
```

4. **Save** butonuna tıklayın
5. Deploy başarılı olduktan sonra start command'ı eski haline döndürün:
   ```
   npx prisma migrate deploy && npm start
   ```

## Kontrol

Deploy tamamlandıktan sonra:

1. **"Deploy Logs"** sekmesinde migration'ların başarıyla uygulandığını görmelisiniz
2. **"HTTP Logs"** sekmesinde uygulamanın çalıştığını görmelisiniz
3. API test: `https://su-aritma-crm-production.up.railway.app/api/health`

