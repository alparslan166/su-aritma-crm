# Flutter Uygulaması

Alt Admin ve Personel rollerini tek koda toplayan Flutter projesi.

## Kurulum

```
cd apps/mobile
flutter pub get
dart format lib test
flutter analyze
flutter test
```

## API URL Yapılandırması

Uygulama, backend API URL'ini environment variable'dan alır. Railway veya başka bir deployment kullanıyorsanız, API URL'ini set etmeniz gerekir.

### Development (Local Backend)

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:4000/api
```

### Production (Railway)

1. Railway Dashboard'dan backend servisinize public domain oluşturun
2. API URL'ini set edin:

```bash
flutter run --dart-define=API_BASE_URL=https://your-app.railway.app/api
```

### Android/iOS Build

```bash
# Android
flutter build apk --dart-define=API_BASE_URL=https://your-app.railway.app/api

# iOS
flutter build ios --dart-define=API_BASE_URL=https://your-app.railway.app/api
```

**Not:** Eğer `API_BASE_URL` set edilmezse, default olarak `http://localhost:4000/api` kullanılır (sadece development için).

## Timeout Ayarları

- **Connect Timeout:** 60 saniye (Railway cold start için)
- **Receive Timeout:** 60 saniye (yavaş network için)
- **Send Timeout:** 60 saniye
- **Retry Mekanizması:** Timeout durumunda otomatik 2 retry (toplam 3 deneme)

## Mimari

- `lib/features/auth` giriş akışı ve rol seçimi
- `lib/features/dashboard` rol bazlı placeholder sayfalar
- `lib/routing/app_router.dart` → GoRouter yapılandırması
- Riverpod (ProviderScope) uygulamanın tamamında kullanılır.
