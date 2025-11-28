# Railway Backend Bağlantı Kontrolü

## 🔍 Mevcut Durum

### Backend URL
Dosyalarda görünen örnek URL:
- `https://su-aritma-crm-production-5d49.up.railway.app`

### Mobile App API URL Konfigürasyonu
- Default: `http://localhost:4000/api` (local development)
- Railway için: `--dart-define=API_BASE_URL=https://your-railway-url.railway.app/api`

## ✅ Backend Bağlantısını Test Etme

### 1. Health Check

```bash
curl https://su-aritma-crm-production-5d49.up.railway.app/api/health
```

Başarılı yanıt:
```json
{
  "success": true,
  "uptime": ...,
  "timestamp": "..."
}
```

### 2. Railway Dashboard'dan Kontrol

1. [Railway.app](https://railway.app) → Projeniz
2. Backend servisine tıklayın
3. **Settings** → **Networking** → Public Domain'i kontrol edin
4. **Deployments** → En son deployment'ın başarılı olduğunu kontrol edin

## 🚀 Emulator'de Railway Backend ile Çalıştırma

### Mevcut Durum
Emulator'de uygulama çalışıyor ama muhtemelen `localhost:4000` kullanıyor.

### Railway Backend ile Çalıştırmak İçin

1. **Mevcut uygulamayı durdurun** (emulator'de)

2. **Railway URL'i ile yeniden başlatın:**

```bash
cd apps/mobile
flutter run -d emulator-5554 \
  --dart-define=API_BASE_URL=https://su-aritma-crm-production-5d49.up.railway.app/api
```

**ÖNEMLİ**: 
- Railway URL'inizi yukarıdaki komutta değiştirin
- URL'in sonuna `/api` ekleyin
- `https://` ile başlamalı

### Railway URL'inizi Bulma

Railway Dashboard'dan:
1. Backend servisi → **Settings** → **Networking**
2. **Public Domain** veya **Generate Domain** bölümünde URL'inizi bulun

## 🔧 Sorun Giderme

### Backend'e Bağlanamıyor

1. **Railway Dashboard Kontrolü:**
   - Backend servisi çalışıyor mu?
   - Son deployment başarılı mı?
   - Logs'da hata var mı?

2. **URL Kontrolü:**
   - URL doğru mu? (`https://...`)
   - Sonuna `/api` eklendi mi?
   - Health check çalışıyor mu?

3. **Network Kontrolü:**
   ```bash
   # Health check
   curl https://your-railway-url.railway.app/api/health
   
   # Login endpoint test
   curl -X POST https://your-railway-url.railway.app/api/auth/login \
     -H "Content-Type: application/json" \
     -d '{"identifier":"test@example.com","password":"test123","role":"admin"}'
   ```

### Mobile App'te "Connection Error"

1. **API URL Kontrolü:**
   - Flutter run komutunda `--dart-define=API_BASE_URL=...` var mı?
   - URL doğru mu?

2. **Debug Logs:**
   - Emulator'de Flutter logs'ları kontrol edin
   - Network isteklerini kontrol edin

3. **CORS:**
   - Backend'de CORS `*` olarak ayarlı (mobile app için gerekli)

## 📝 Hızlı Komutlar

```bash
# Railway backend health check
curl https://su-aritma-crm-production-5d49.up.railway.app/api/health

# Railway URL ile uygulamayı çalıştır
cd apps/mobile
flutter run -d emulator-5554 \
  --dart-define=API_BASE_URL=https://su-aritma-crm-production-5d49.up.railway.app/api

# Railway domain'i bul
cd apps/backend
railway domain
```

## ⚠️ Önemli Notlar

1. **Default URL**: Eğer `--dart-define=API_BASE_URL` belirtmezseniz, app `localhost:4000` kullanır (emulator'de çalışmaz)

2. **Railway URL**: Her zaman `https://` ile başlamalı ve sonuna `/api` eklenmeli

3. **Database**: Database bağlantısı backend tarafında Railway'da otomatik yapılır (DATABASE_URL environment variable)

4. **Deploy**: Backend Railway'da deploy edildiğinde otomatik olarak database'e bağlanır

