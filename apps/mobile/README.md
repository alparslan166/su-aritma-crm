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

## Mimari

- `lib/features/auth` giriş akışı ve rol seçimi
- `lib/features/dashboard` rol bazlı placeholder sayfalar
- `lib/routing/app_router.dart` → GoRouter yapılandırması
- Riverpod (ProviderScope) uygulamanın tamamında kullanılır.
