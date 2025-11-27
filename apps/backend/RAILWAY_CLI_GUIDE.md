# Railway CLI Kullanım Rehberi

Terminal'den Railway sunucusunu yönetmek için Railway CLI kullanabilirsiniz.

## Kurulum

### macOS (Homebrew)
```bash
brew install railway
```

### npm/yarn
```bash
npm install -g @railway/cli
# veya
yarn global add @railway/cli
```

### curl (Linux/macOS)
```bash
curl -fsSL https://railway.app/install.sh | sh
```

## Giriş

```bash
railway login
```

Tarayıcı açılacak ve Railway hesabınızla giriş yapmanız istenecek.

## Proje ve Servis Seçme

```bash
# Projeyi seç
railway link

# Veya direkt proje ID ile
railway link --project <project-id>
```

## Environment Variables Yönetimi

### Tüm Variables'ları Görüntüle
```bash
railway variables
```

### Variable Ekle
```bash
railway variables set DATABASE_URL="postgresql://..."
railway variables set DIRECT_URL="postgresql://..."
railway variables set NODE_ENV=production
```

### Variable Sil
```bash
railway variables unset VARIABLE_NAME
```

## Deploy

### Manuel Deploy
```bash
# Mevcut dizinden deploy et
railway up

# Veya belirli bir dizinden
cd apps/backend
railway up
```

### Deploy ve Logs
```bash
# Deploy et ve logları göster
railway up --detach
railway logs
```

## Logs Görüntüleme

### Canlı Logs
```bash
railway logs
```

### Son N Satır
```bash
railway logs --tail 100
```

### Belirli Bir Servis İçin
```bash
railway logs --service su-aritma-crm
```

## Status Kontrolü

### Servis Durumu
```bash
railway status
```

### Deployments Listesi
```bash
railway deployments
```

## Database Yönetimi

### PostgreSQL'e Bağlan
```bash
railway connect postgres
```

### SQL Query Çalıştır
```bash
railway connect postgres --command "SELECT * FROM _prisma_migrations;"
```

## Hızlı Komutlar

### Tüm Environment Variables'ları Görüntüle
```bash
railway variables
```

### Deploy Et
```bash
cd apps/backend
railway up
```

### Logs Görüntüle
```bash
railway logs --tail 50
```

### Database'e Bağlan
```bash
railway connect postgres
```

## Örnek Kullanım Senaryosu

### 1. Railway'e Giriş Yap
```bash
railway login
```

### 2. Projeyi Link Et
```bash
cd apps/backend
railway link
```

### 3. Environment Variables Ekle
```bash
railway variables set DATABASE_URL="postgresql://postgres:ezxcbkKCcAsFbRpugzHZmOyOOUsaBKPb@switchback.proxy.rlwy.net:10192/railway"
railway variables set DIRECT_URL="postgresql://postgres:ezxcbkKCcAsFbRpugzHZmOyOOUsaBKPb@switchback.proxy.rlwy.net:10192/railway"
railway variables set NODE_ENV=production
```

### 4. Deploy Et
```bash
railway up
```

### 5. Logs İzle
```bash
railway logs --tail 100
```

### 6. Database'e Bağlan ve Migration'ları Kontrol Et
```bash
railway connect postgres
# Sonra SQL:
# SELECT * FROM "_prisma_migrations" ORDER BY started_at DESC;
```

## Yardım

```bash
railway --help
railway <command> --help
```

## Notlar

- Railway CLI, Railway dashboard ile aynı işlemleri yapmanızı sağlar
- Terminal'den daha hızlı ve otomatikleştirilebilir
- CI/CD pipeline'larında kullanılabilir

