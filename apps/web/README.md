# Ana Admin Paneli

Su Arıtma CRM sisteminin ana admin web paneli.

## Gereksinimler

1. **ANA rolünde bir admin hesabı** (veritabanında)
2. **Backend API'nin çalışıyor olması**
3. **API URL'inin ayarlanması**

## Kurulum

### 1. ANA Admin Hesabı Oluşturma

#### Yöntem 1: Railway Dashboard'dan DATABASE_URL ile (Önerilen)

1. Railway Dashboard → PostgreSQL servisi → Variables → `DATABASE_URL`'i kopyalayın
2. `apps/backend/.env` dosyasına ekleyin:
   ```bash
   DATABASE_URL="postgresql://..."
   ```
3. Script'i çalıştırın:
   ```bash
   cd apps/backend
   npm run create:ana-admin alp84202@gmail.com 123456 "Alparslan"
   ```

#### Yöntem 2: Railway CLI ile

```bash
# Railway projesine bağlan (eğer bağlı değilse)
cd apps/backend
railway link

# Servis seç (backend servisini seçin)
railway service

# Railway'de script'i çalıştır
railway run npm run create:ana-admin alp84202@gmail.com 123456 "Alparslan"
```

#### Yöntem 3: Varsayılan bilgilerle

```bash
cd apps/backend
npm run create:ana-admin
# Email: ana@admin.com
# Password: admin123
# Name: Ana Admin
```

**Not:** 
- Yöntem 1 en kolay ve hızlı yöntemdir
- Railway CLI kullanmak için önce `railway link` ve `railway service` ile servis seçmeniz gerekebilir

### 2. Environment Variables

Web uygulaması için `.env.local` dosyası oluşturun:

```bash
cd apps/web
echo "NEXT_PUBLIC_API_URL=http://localhost:3001/api" > .env.local
```

**Production için:**
```bash
echo "NEXT_PUBLIC_API_URL=https://your-railway-app.railway.app/api" > .env.local
```

### 3. Uygulamayı Çalıştırma

```bash
cd apps/web
npm install
npm run dev
```

Uygulama `http://localhost:3000` adresinde çalışacak.

## Giriş

1. Tarayıcıda `http://localhost:3000/login` adresine gidin
2. ANA admin hesabınızın email ve şifresini girin
3. Giriş yaptıktan sonra admin listesi sayfasına yönlendirileceksiniz

## Özellikler

- ✅ Tüm adminleri listeleme
- ✅ Admin detaylarını görüntüleme
- ✅ ALT adminleri silme (ANA admin silinemez)
- ✅ Abonelik durumlarını görüntüleme

## Notlar

- Sadece **ANA** rolündeki adminler web paneline giriş yapabilir
- ALT adminler mobil uygulama üzerinden giriş yapabilir
- Token localStorage'da saklanır
