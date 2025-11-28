# Railway Deploy Notları

## ✅ Yapılan Değişiklikler

### Backend
1. ✅ Admin modelinde email unique yapıldı (migration eklendi)
2. ✅ Admin login email/password ile yapılacak şekilde güncellendi
3. ✅ Admin kayıt endpoint'i eklendi (`/auth/register`)
4. ✅ Email kontrolü ve validasyon eklendi

### Mobile
1. ✅ Admin kayıt sayfası eklendi
2. ✅ Login sayfasına admin için "Kayıt Ol" butonu eklendi
3. ✅ AuthService'e signUp metodu eklendi
4. ✅ Email ile giriş yapılacak şekilde güncellendi

## 🚀 Railway Deploy

Railway'de zaten her şey hazır. Yapılan değişiklikler commit edildikten sonra:

1. **Otomatik Deploy**: Railway GitHub'a push yaptığınızda otomatik deploy başlatır
2. **Migration**: Yeni migration (`add_unique_email_to_admin`) otomatik çalışacak
3. **Build**: Backend otomatik build edilecek ve deploy edilecek

## 📋 Migration Detayları

Migration dosyası: `apps/backend/prisma/migrations/20250101000000_add_unique_email_to_admin/migration.sql`

```sql
-- AlterTable
ALTER TABLE "Admin" ADD CONSTRAINT "Admin_email_key" UNIQUE ("email");
```

Bu migration:
- Admin tablosundaki email kolonuna unique constraint ekler
- Aynı email ile birden fazla admin kaydı yapılmasını engeller

## ⚠️ Önemli Notlar

1. **Email Unique**: Artık aynı email ile birden fazla admin kaydı yapılamaz
2. **Login Değişikliği**: Adminler artık email ve şifre ile giriş yapıyor (ID değil)
3. **Kayıt Özelliği**: Adminler artık kendi hesaplarını oluşturabilir
4. **Mevcut Adminler**: Mevcut adminlerin email'leri unique olmalı, aksi halde migration hata verebilir

## 🔍 Deploy Sonrası Kontrol

Deploy tamamlandıktan sonra:

1. **Health Check**: `curl https://your-backend.railway.app/api/health`
2. **Migration Kontrol**: Railway logs'larında migration'ın başarılı olduğunu kontrol edin
3. **Test**: Admin kayıt ve giriş özelliklerini test edin

## 📝 Railway Logs

Deploy sırasında logları kontrol etmek için:

```bash
railway logs --tail 100
```

veya Railway Dashboard'dan:
- Backend servisi → Deployments → En son deployment → View Logs

