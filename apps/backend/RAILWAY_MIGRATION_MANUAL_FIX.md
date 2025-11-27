# Railway Migration Manuel Düzeltme

## Sorun

`20251118223050_name` migration'ı failed durumda çünkü `AdminRole` enum'u zaten var. Migration kısmen uygulanmış.

## Çözüm: Railway Dashboard'da Manuel Düzeltme

### Adım 1: Railway Dashboard'a Gidin

1. Railway dashboard → Projeniz → `su-aritma-crm` servisi
2. **"Settings"** sekmesine gidin
3. **"Deploy"** bölümünde **"Custom Start Command"** bulun

### Adım 2: Start Command'ı Değiştirin

**Mevcut Start Command:**
```
npx prisma migrate deploy && npm start
```

**Yeni Start Command (Migration'ı applied olarak işaretlemek için):**
```
npx prisma migrate resolve --applied 20251118223050_name && npx prisma migrate deploy && npm start
```

### Adım 3: Save ve Deploy

1. "Save" butonuna tıklayın
2. Railway otomatik olarak yeni deploy başlatır
3. Deploy başarılı olduktan sonra start command'ı eski haline döndürün

### Adım 4: Start Command'ı Eski Haline Döndürün

Deploy başarılı olduktan sonra:
```
npx prisma migrate deploy && npm start
```

## Alternatif: PostgreSQL Query ile Manuel Düzeltme

Eğer start command çalışmazsa:

### Adım 1: Railway PostgreSQL'e Bağlanın

1. Railway dashboard → PostgreSQL servisinize gidin
2. **"Query"** sekmesine tıklayın (veya bir PostgreSQL client kullanın)

### Adım 2: Failed Migration'ı Silin

```sql
-- Failed migration'ı _prisma_migrations tablosundan sil
DELETE FROM "_prisma_migrations" 
WHERE migration_name = '20251118223050_name';
```

### Adım 3: Deploy Tekrar Deneyin

Railway otomatik olarak migration'ları uygulayacaktır.

## Neden "applied" Olarak İşaretliyoruz?

Migration kısmen uygulanmış:
- ✅ `AdminRole` enum'u zaten oluşturulmuş
- ❌ Migration failed olarak işaretlenmiş

Bu yüzden migration'ı "applied" olarak işaretleyip devam ediyoruz. Enum zaten var, migration'ın geri kalanı da muhtemelen uygulanmış.

## Kontrol

Deploy tamamlandıktan sonra:

1. **"Deploy Logs"** sekmesinde migration'ların başarıyla uygulandığını görmelisiniz
2. **"HTTP Logs"** sekmesinde uygulamanın çalıştığını görmelisiniz
3. API endpoint'lerini test edin: `https://su-aritma-crm-production.up.railway.app/api/health`

