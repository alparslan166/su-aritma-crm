# Railway Backend URL'ini Bulma

Railway dashboard'unda backend servisinizin public URL'ini bulmak için aşağıdaki adımları izleyin.

## Adım 1: Railway Dashboard'a Giriş

1. [Railway.app](https://railway.app) adresine gidin
2. Giriş yapın

## Adım 2: Projenizi Seçin

1. Dashboard'da projenizi bulun
2. Projeye tıklayın

## Adım 3: Backend Servisinizi Seçin

1. Proje içinde backend servisinizi bulun (genellikle "backend" veya proje adınız)
2. Servise tıklayın

## Adım 4: Public URL'i Bulun

### Yöntem 1: Settings > Networking (Önerilen)

1. Servis sayfasında üst menüden **"Settings"** sekmesine tıklayın
2. **"Networking"** bölümüne gidin
3. **"Generate Domain"** veya **"Public URL"** bölümünde URL'inizi göreceksiniz
4. URL formatı genellikle: `https://your-service-name.railway.app`

### Yöntem 2: Deployments

1. Servis sayfasında **"Deployments"** sekmesine tıklayın
2. En son deployment'ın yanında **"View Logs"** veya **"Open"** butonuna tıklayın
3. URL'i görebilirsiniz

### Yöntem 3: Variables

1. Servis sayfasında **"Variables"** sekmesine tıklayın
2. `RAILWAY_PUBLIC_DOMAIN` veya benzeri bir variable varsa, orada URL'i görebilirsiniz

## Adım 5: URL'i Doğrulama

Backend URL'inizi bulduktan sonra, health check endpoint'i ile test edin:

```
https://your-service-name.railway.app/api/health
```

Bu URL'e tarayıcıdan veya curl ile istek atın:

```bash
curl https://your-service-name.railway.app/api/health
```

Başarılı yanıt:
```json
{
  "success": true,
  "uptime": ...,
  "timestamp": "..."
}
```

## Örnek URL Formatı

Railway URL'leri genellikle şu formatta olur:

```
https://your-app-name-production.up.railway.app
```

veya

```
https://your-service-name.railway.app
```

## Mobile App'te Kullanım

Build komutunda URL'i kullanın:

```bash
cd apps/mobile
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://your-service-name.railway.app/api
```

**ÖNEMLİ**: URL'in sonuna `/api` eklemeyi unutmayın!

## URL Bulunamazsa

Eğer public URL göremiyorsanız:

1. **Settings > Networking** bölümüne gidin
2. **"Generate Domain"** veya **"Create Public URL"** butonuna tıklayın
3. Railway otomatik olarak bir domain oluşturacaktır

## Özel Domain (Opsiyonel)

Railway'da özel domain de ekleyebilirsiniz:

1. Settings > Networking > Custom Domain
2. Kendi domain'inizi ekleyin
3. DNS ayarlarını yapın

## Troubleshooting

### "Connection refused" Hatası

- Backend servisinin çalıştığından emin olun
- Railway dashboard'unda service'in "Active" durumunda olduğunu kontrol edin

### "404 Not Found" Hatası

- URL'in sonuna `/api` eklediğinizden emin olun
- Health check endpoint'ini deneyin: `/api/health`

### URL Çalışmıyor

- Railway dashboard'unda deployment logs'larını kontrol edin
- Environment variables'ların doğru ayarlandığından emin olun
- Port'un doğru ayarlandığından emin olun (Railway otomatik sağlar)

