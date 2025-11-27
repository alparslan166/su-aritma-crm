# Railway PostgreSQL Query Nasıl Bulunur?

## Adım Adım Rehber

### 1. Railway Dashboard'a Gidin
- https://railway.app adresine gidin
- Giriş yapın

### 2. Projenizi Seçin
- Ana sayfada projenize tıklayın (örn: `su-aritma-crm` veya `empowering-mindfulness`)

### 3. PostgreSQL Servisini Bulun
- Proje sayfasında **PostgreSQL** servisini bulun
- PostgreSQL servisine tıklayın (genellikle "PostgreSQL" veya "Database" olarak görünür)

### 4. Query Sekmesine Gidin
- PostgreSQL servisinin sayfasında üstte sekmeler göreceksiniz:
  - **Variables** (Environment variables)
  - **Connect** (Connection string)
  - **Query** ← **BURAYA TIKLAYIN**
  - **Metrics**
  - **Settings**

### 5. SQL Query Çalıştırın
- **Query** sekmesinde bir SQL editör göreceksiniz
- Şu SQL'i yapıştırın:

```sql
DELETE FROM "_prisma_migrations" 
WHERE migration_name = '20251118223050_name';
```

- **"Run Query"** veya **"Execute"** butonuna tıklayın

### 6. Sonucu Kontrol Edin
- Query başarılı olduğunda "1 row deleted" gibi bir mesaj göreceksiniz

### 7. Deploy Tekrar Deneyin
- Railway dashboard → `su-aritma-crm` servisi
- **"Deployments"** sekmesinde **"Redeploy"** butonuna tıklayın
- Veya yeni bir commit push edin

## Alternatif: Connect Sekmesinden Bağlanma

Eğer Query sekmesi yoksa:

1. **Connect** sekmesine gidin
2. Connection string'i kopyalayın
3. Bir PostgreSQL client kullanın (örn: pgAdmin, DBeaver, veya terminal'den `psql`)
4. Aynı SQL'i çalıştırın

## Görsel Yol Haritası

```
Railway Dashboard
  └── Projeniz (su-aritma-crm)
      └── PostgreSQL Servisi
          └── Query Sekmesi ← BURAYA TIKLAYIN
              └── SQL Editor
                  └── SQL'i yapıştırın ve çalıştırın
```

## Sorun Giderme

### Query Sekmesi Görünmüyor
- PostgreSQL servisinin aktif olduğundan emin olun
- Farklı bir tarayıcı deneyin
- Railway dashboard'u yenileyin (F5)

### SQL Çalışmıyor
- SQL syntax'ını kontrol edin
- Tırnak işaretlerinin doğru olduğundan emin (`'20251118223050_name'`)
- Connection string'in doğru olduğundan emin

### Hala Hata Alıyorum
- Query'yi çalıştırdıktan sonra birkaç saniye bekleyin
- Railway'de yeni bir deploy başlatın
- Deploy logs'ları kontrol edin

