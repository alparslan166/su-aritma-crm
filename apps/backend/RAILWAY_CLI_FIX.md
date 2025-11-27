# Railway CLI Variables Düzeltme

## Sorun

`railway variables set` komutu çalışmıyor. Railway CLI'nin syntax'ı değişmiş olabilir.

## Çözüm: Railway Dashboard Kullanın

Railway CLI yerine Railway Dashboard kullanmak daha güvenilir:

### 1. Railway Dashboard'a Gidin

1. https://railway.app → Projeniz → `su-aritma-crm` servisi
2. **"Variables"** sekmesine tıklayın

### 2. Variables Ekle

**"New Variable"** butonuna tıklayın ve şunları ekleyin:

- **Name:** `DATABASE_URL`
- **Value:** `postgresql://postgres:ezxcbkKCcAsFbRpugzHZmOyOOUsaBKPb@switchback.proxy.rlwy.net:10192/railway`

- **Name:** `DIRECT_URL`
- **Value:** `postgresql://postgres:ezxcbkKCcAsFbRpugzHZmOyOOUsaBKPb@switchback.proxy.rlwy.net:10192/railway`

- **Name:** `NODE_ENV`
- **Value:** `production`

## Alternatif: Railway CLI Doğru Syntax

Railway CLI'nin yeni versiyonunda syntax farklı olabilir:

### Variables Görüntüle
```bash
railway variables
```

### Variable Ekle (Yeni Syntax)
```bash
# Railway CLI v2 syntax (eğer yeni versiyon kullanıyorsanız)
railway variables --set DATABASE_URL="postgresql://..."

# Veya
railway variables add DATABASE_URL "postgresql://..."
```

### Railway CLI Versiyonunu Kontrol Et
```bash
railway --version
```

## Önerilen Yöntem

**Railway Dashboard kullanın** - Daha güvenilir ve kolay:
1. Railway dashboard → `su-aritma-crm` servisi
2. **"Variables"** sekmesi
3. **"New Variable"** butonuna tıklayın
4. Variable'ları ekleyin

## Migration Sorunu İçin

İkinci migration'ı düzeltmek için:

1. **PostgreSQL'e bağlanın:**
   ```bash
   psql "postgresql://postgres:ezxcbkKCcAsFbRpugzHZmOyOOUsaBKPb@switchback.proxy.rlwy.net:10192/railway"
   ```

2. **Migration'ı silin:**
   ```sql
   DELETE FROM "_prisma_migrations" 
   WHERE migration_name = '20251119132546_add_admin_password';
   ```

3. **Railway'de deploy'u başlatın:**
   - Railway dashboard → `su-aritma-crm` → **"Deployments"** → **"Redeploy"**

