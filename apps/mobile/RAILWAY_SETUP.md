# Mobile App - Railway Backend Bağlantısı

Bu dokümantasyon, mobile uygulamanın Railway'da çalışan backend'e bağlanması için gerekli adımları açıklar.

## API URL Konfigürasyonu

Mobile uygulama, API URL'ini compile-time environment variable ile alır. Railway backend URL'inizi kullanmak için aşağıdaki adımları izleyin.

### Railway Backend URL'inizi Bulun

1. Railway dashboard'una gidin
2. Backend servisinize tıklayın
3. "Settings" > "Networking" bölümünde public URL'inizi bulun
4. URL formatı genellikle: `https://your-app-name.railway.app`

### Flutter App'i Railway Backend'e Bağlama

#### Development (Debug Mode)

```bash
cd apps/mobile
flutter run --dart-define=API_BASE_URL=https://your-app-name.railway.app/api
```

#### Production Build (Android)

```bash
cd apps/mobile
flutter build apk --release --dart-define=API_BASE_URL=https://your-app-name.railway.app/api
```

#### Production Build (iOS)

```bash
cd apps/mobile
flutter build ios --release --dart-define=API_BASE_URL=https://your-app-name.railway.app/api
```

### VS Code / Android Studio Launch Configuration

VS Code'da `.vscode/launch.json` dosyası oluşturun:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Mobile App (Railway)",
      "request": "launch",
      "type": "dart",
      "args": [
        "--dart-define=API_BASE_URL=https://your-app-name.railway.app/api"
      ]
    },
    {
      "name": "Mobile App (Local)",
      "request": "launch",
      "type": "dart"
    }
  ]
}
```

### Android Studio Run Configuration

1. Run > Edit Configurations
2. "Additional run args" alanına ekleyin:
   ```
   --dart-define=API_BASE_URL=https://your-app-name.railway.app/api
   ```

## CORS Ayarları

Backend'de CORS zaten `*` (tüm origin'lere izin) olarak ayarlanmış, bu yüzden mobile app'ten gelen istekler çalışacaktır.

## Socket.IO Bağlantısı

Socket.IO bağlantısı otomatik olarak API URL'inden türetilir:
- `https://your-app.railway.app/api` → `wss://your-app.railway.app`

## Test Etme

1. Mobile app'i Railway backend URL'i ile çalıştırın
2. Login ekranında giriş yapmayı deneyin
3. Network isteklerinin Railway backend'e gittiğini kontrol edin

## Troubleshooting

### Connection Refused / Timeout

- Railway backend'inin çalıştığından emin olun
- Railway dashboard'unda service'in "Active" durumunda olduğunu kontrol edin
- Public URL'in doğru olduğundan emin olun

### CORS Errors

- Backend'de CORS ayarlarının `origin: "*"` olduğundan emin olun
- Backend logs'larını kontrol edin

### Socket.IO Bağlantı Sorunları

- WebSocket bağlantısının Railway'da desteklendiğinden emin olun
- Backend'de Socket.IO server'ının çalıştığını kontrol edin

## Production Deployment

Production'da API URL'ini hardcode etmek yerine, build script'lerinde environment variable kullanın:

```bash
# CI/CD pipeline'da
export API_BASE_URL=https://your-app-name.railway.app/api
flutter build apk --release --dart-define=API_BASE_URL=$API_BASE_URL
```

