# Production Hazırlık Kontrol Listesi

Bu dokümantasyon, backend'in Google Play Store yayını için production'a hazır olup olmadığını kontrol etmenize yardımcı olur.

## ✅ Tamamlanan İyileştirmeler

### 1. Logging Optimizasyonu
- ✅ **Morgan Logger**: Production'da sadece 4xx ve 5xx hata logları gösterilir
- ✅ **Debug Logs**: Sadece development modunda aktif
- ✅ **Warn Logs**: Production'da da aktif (önemli uyarılar için)
- ✅ **Error Logs**: Her zaman aktif (kritik hatalar için)

### 2. Güvenlik İyileştirmeleri
- ✅ **Error Handler**: Production'da hassas bilgiler (request body, headers) loglanmaz
- ✅ **Stack Traces**: Production'da sadece hata stack trace'i gösterilir
- ✅ **CORS**: Yapılandırılabilir origin desteği eklendi
- ✅ **Environment Validation**: Production'da localhost database kontrolü eklendi

### 3. CORS Yapılandırması
- ✅ **Esnek Origin**: `ALLOWED_ORIGINS` environment variable ile kontrol edilebilir
- ✅ **Mobile App Desteği**: Varsayılan olarak tüm origin'lere izin verilir (mobile app için gerekli)
- ✅ **Method & Header Kontrolü**: Sadece gerekli HTTP method'ları ve header'lar izin verilir

## 📋 Production Environment Variables

,3
Railway veya deployment platformunuzda aşağıdaki environment variable'ları ayarlayın:

```env
NODE_ENV=production
PORT=4000

# Database (ZORUNLU - localhost olamaz)
DATABASE_URL=postgresql://user:password@host:port/database?sslmode=require

# AWS S3 (Media storage için)
AWS_REGION=eu-central-1
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
S3_MEDIA_BUCKET=your-bucket-name

# Firebase Cloud Messaging (Push notifications için)
FCM_SERVER_KEY=your-fcm-server-key

# Redis (Opsiyonel - Maintenance reminders için)
REDIS_URL=redis://host:port

# Maintenance Cron (Opsiyonel)
MAINTENANCE_CRON=0 * * * *

# CORS (Opsiyonel - Mobile app için genelde boş bırakılır)
ALLOWED_ORIGINS=
```

## 🔍 Kontrol Listesi

### Backend Kontrolleri

- [ ] `NODE_ENV=production` ayarlı
- [ ] `DATABASE_URL` production database'e işaret ediyor (localhost değil)
- [ ] AWS credentials doğru ve geçerli
- [ ] S3 bucket mevcut ve erişilebilir
- [ ] FCM server key doğru
- [ ] Railway/public URL çalışıyor
- [ ] Health check endpoint çalışıyor: `/api/health`

### Logging Kontrolleri

- [ ] Production'da sadece hata logları görünüyor
- [ ] Debug logları görünmüyor
- [ ] Request body/headers production'da loglanmıyor
- [ ] Stack traces sadece error handler'da görünüyor

### Güvenlik Kontrolleri

- [ ] CORS ayarları doğru
- [ ] Helmet security headers aktif
- [ ] Hassas bilgiler loglanmıyor
- [ ] Error responses'da stack trace sadece development'ta

### API Kontrolleri

- [ ] Tüm endpoint'ler çalışıyor
- [ ] Authentication çalışıyor
- [ ] Mobile app backend'e bağlanabiliyor
- [ ] Socket.IO bağlantısı çalışıyor

## 🚀 Railway Deployment Kontrolü

### 1. Environment Variables
Railway dashboard'unda tüm environment variable'ların ayarlandığından emin olun:
- Settings > Variables sekmesinde kontrol edin

### 2. Database Migration
```bash
# Railway CLI ile veya dashboard'dan
npx prisma migrate deploy
```

### 3. Health Check
Backend URL'inizi test edin:
```bash
curl https://your-app.railway.app/api/health
```

Beklenen yanıt:
```json
{
  "success": true,
  "uptime": ...,
  "timestamp": "..."
}
```

## 📱 Mobile App Bağlantısı

Mobile app'i build ederken Railway backend URL'ini kullanın:

```bash
cd apps/mobile
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://your-app.railway.app/api
```

**ÖNEMLİ**: URL'in sonuna `/api` eklemeyi unutmayın!

## 🔧 Sorun Giderme

### "DATABASE_URL cannot point to localhost"
- Production'da `DATABASE_URL` localhost içeremez
- Railway veya başka bir production database kullanın

### "Connection refused" veya "Cannot connect"
- Backend servisinin çalıştığından emin olun
- Railway dashboard'unda service'in "Active" durumunda olduğunu kontrol edin
- Deploy logs'larını kontrol edin

### "404 Not Found"
- URL'in sonuna `/api` eklediğinizden emin olun
- Health check endpoint'ini deneyin: `/api/health`

### Loglar çok fazla
- Production'da `NODE_ENV=production` olduğundan emin olun
- Morgan logger sadece 4xx ve 5xx logları gösterecek

## 📝 Notlar

1. **CORS**: Mobile app için genelde `ALLOWED_ORIGINS` boş bırakılır (tüm origin'lere izin)
2. **Logging**: Production'da sadece hata logları gösterilir, performans için optimize edilmiştir
3. **Security**: Hassas bilgiler production'da loglanmaz
4. **Database**: Production'da mutlaka SSL bağlantısı kullanın (`?sslmode=require`)

## ✅ Production Ready Checklist

Backend production'a hazır olduğunda:

- [x] Logging production için optimize edildi
- [x] Güvenlik iyileştirmeleri yapıldı
- [x] CORS yapılandırması eklendi
- [x] Environment validation güçlendirildi
- [x] Error handling production-safe
- [ ] Railway'da environment variables ayarlandı
- [ ] Database migration'ları çalıştırıldı
- [ ] Health check başarılı
- [ ] Mobile app backend'e bağlanabiliyor

Başarılar! 🚀

