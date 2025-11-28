# Railway Shell Bulma ve Script Çalıştırma Rehberi

## 🔍 Railway Dashboard'da Shell Nerede?

Railway'in yeni arayüzünde Shell'e erişim yolları:

### Yöntem 1: Deployments Sekmesinden (EN KOLAY)

1. Railway Dashboard → Projenizi seçin
2. **su-aritma-crm** servisini seçin
3. Üst menüden **"Deployments"** sekmesine tıklayın
4. En üstteki (ACTIVE) deployment kartına **tıklayın**
5. Açılan detay penceresinde sağ üstte **"Shell"** butonuna tıklayın
6. Veya deployment kartının sağ üstündeki **üç nokta menüsü** (⋮) → **"Open Shell"**

### Yöntem 2: Service Overview'dan

1. **su-aritma-crm** servisini seçin
2. Servis sayfasının sağ üst köşesinde **terminal ikonu** (🖥️) veya **"Shell"** butonuna tıklayın
3. Veya sayfanın üst kısmında **"Terminal"** sekmesine tıklayın

### Yöntem 3: Architecture View'dan

1. Sol panelde **su-aritma-crm** kartına **sağ tıklayın**
2. Açılan menüde **"Open Shell"** veya **"Terminal"** seçeneğine tıklayın

### Yöntem 4: Settings Sekmesinden

1. **su-aritma-crm** servisini seçin
2. **Settings** sekmesine gidin
3. Sayfanın altında veya yanında **"Shell"** veya **"Console"** bölümü olabilir

## 🚀 Railway Shell'de Script Çalıştırma

Railway Shell'i açtıktan sonra:

```bash
# 1. Backend dizinine git
cd /app

# 2. Script'i çalıştır
npm run seed:admin-data -- --email=test@suaritma.com
```

**Not:** Railway Shell'de environment variables otomatik yüklenir, `DATABASE_URL` ayarlamaya gerek yok!

## 🚀 Alternatif: Local'de DATABASE_URL ile Çalıştırma

Eğer Shell bulamıyorsanız, Railway'den DATABASE_URL'i alıp local'de çalıştırabilirsiniz:

### Adım 1: DATABASE_URL'i Alın

1. Railway Dashboard → **su-aritma-crm** servisi
2. **Variables** sekmesine tıklayın
3. `DATABASE_URL` değişkenini bulun
4. **Değerini kopyalayın** (göz ikonuna tıklayarak görebilirsiniz)

### Adım 2: Local'de Çalıştırın

```bash
cd apps/backend

# DATABASE_URL'i set ederek çalıştırın
DATABASE_URL="postgresql://user:password@host:port/database" npm run seed:admin-data -- --email=test@suaritma.com
```

**Örnek:**
```bash
DATABASE_URL="postgresql://postgres:ABC123@switchback.proxy.rlwy.net:10192/railway" npm run seed:admin-data -- --email=test@suaritma.com
```

## ⚠️ Önemli Notlar

- `DATABASE_URL` mutlaka `postgresql://` veya `postgres://` ile başlamalı
- API URL'si (`https://...`) değil, veritabanı URL'si olmalı
- Railway Variables'dan aldığınız URL doğru formatta olacaktır

## 📝 Hızlı Komut

```bash
# 1. Railway Dashboard → Variables → DATABASE_URL kopyala
# 2. Terminal'de çalıştır:

cd apps/backend
DATABASE_URL="<kopyaladığınız URL>" npm run seed:admin-data -- --email=test@suaritma.com
```

