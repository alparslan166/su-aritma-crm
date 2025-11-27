# Railway Backend URL Rehberi

## ⚠️ ÖNEMLİ: Database URL ≠ Backend HTTP URL

Paylaştığınız URL bir **database connection string**'dir:
```
postgresql://postgres:password@switchback.proxy.rlwy.net:10192/railway
```

Bu URL:
- ✅ Backend'in database'e bağlanması için kullanılır
- ❌ Mobile app'in backend'e bağlanması için kullanılmaz

## Mobile App İçin Gereken URL

Mobile app'in ihtiyacı olan URL, backend servisinizin **HTTP/HTTPS public URL**'idir:

```
https://your-backend-service.railway.app
```

## Railway Dashboard'da Backend URL'ini Bulma

### Adım 1: Railway Dashboard

1. [Railway.app](https://railway.app) → Giriş yapın
2. Projenizi seçin

### Adım 2: Backend Servisini Bulun

Proje içinde backend servisinizi bulun (örnek isimler: "backend", "api", "su-aritma-backend")

### Adım 3: Public URL'i Bulun

**Yöntem 1: Settings > Networking (En Kolay)**

1. Backend servisine tıklayın
2. Üst menüden **"Settings"** sekmesine tıklayın
3. **"Networking"** bölümüne gidin
4. **"Public Domain"** veya **"Generate Domain"** bölümünde URL'inizi göreceksiniz

**Yöntem 2: Deployments**

1. Backend servisinde **"Deployments"** sekmesine tıklayın
2. En son deployment'ın yanında **"View"** veya **"Open"** butonuna tıklayın
3. URL'i görebilirsiniz

**Yöntem 3: Service Overview**

1. Backend servisinin ana sayfasında
2. Sağ üstte veya servis kartında **"Open"** veya **"View"** butonuna tıklayın
3. URL'i görebilirsiniz

## URL Formatı

Railway public URL'leri genellikle şu formatta olur:

```
https://your-service-name.railway.app
```

veya

```
https://your-app-name-production.up.railway.app
```

## URL'i Test Etme

Backend URL'inizi bulduktan sonra test edin:

### Tarayıcıdan

```
https://your-backend-service.railway.app/api/health
```

### Terminal'den

```bash
curl https://your-backend-service.railway.app/api/health
```

**Başarılı yanıt:**
```json
{
  "success": true,
  "uptime": ...,
  "timestamp": "..."
}
```

## Mobile Build'de Kullanım

URL'i bulduktan sonra build komutunda kullanın:

```bash
cd apps/mobile
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://your-backend-service.railway.app/api
```

**ÖNEMLİ**: 
- URL'in sonuna `/api` ekleyin
- `https://` ile başlamalı (http değil)

## Eğer Public URL Göremiyorsanız

1. Backend servisinde **Settings > Networking**'e gidin
2. **"Generate Domain"** veya **"Create Public URL"** butonuna tıklayın
3. Railway otomatik olarak bir domain oluşturacaktır

## Database URL vs Backend URL

| Özellik | Database URL | Backend HTTP URL |
|---------|-------------|------------------|
| Format | `postgresql://...` | `https://...` |
| Kullanım | Backend → Database | Mobile App → Backend |
| Nerede | Railway Variables | Railway Networking |
| Örnek | `postgresql://postgres:pass@host:port/db` | `https://backend.railway.app` |

## Troubleshooting

### "Connection refused" veya "Cannot connect"

- Backend servisinin çalıştığından emin olun
- Railway dashboard'unda service'in **"Active"** durumunda olduğunu kontrol edin
- Deploy logs'larını kontrol edin

### "404 Not Found"

- URL'in sonuna `/api` eklediğinizden emin olun
- Health check endpoint'ini deneyin: `/api/health`

### URL Bulunamıyor

- Settings > Networking'de "Generate Domain" butonuna tıklayın
- Railway otomatik olarak bir domain oluşturacaktır

