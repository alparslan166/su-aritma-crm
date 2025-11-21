# Su Arıtma Platformu

Flutter + Express/PostgreSQL tabanlı alt admin/personel yönetim platformunun monorepo iskeleti.

## Klasör Yapısı

```
apps/
  backend/    # Express + TypeScript servisleri
  mobile/     # Flutter uygulaması (Alt Admin & Personel)
docs/
  requirements/  # Kullanıcı hikâyeleri ve iş analizi
  architecture/  # Sistem tasarım dokümanları
infra/
  terraform/  # IaC şablonları
.github/workflows/  # CI/CD tanımları
```

## Başlangıç

1. `apps/backend` içinde `npm install` komutunu çalıştır.
2. Flutter SDK kuruluysa `apps/mobile` klasöründe `flutter pub get` çalıştır.
3. `infra/terraform` klasöründeki `README.md` talimatlarını takip ederek ortam değişkenlerini ayarla.

## Komutlar

| Komut                    | Açıklama                                      |
| ------------------------ | --------------------------------------------- |
| `npm run dev` (backend)  | Nodemon ile Express API’yi çalıştırır.        |
| `npm run lint` (backend) | ESLint + TypeScript kontrollerini çalıştırır. |
| `flutter run` (mobile)   | Flutter uygulamasını çalıştırır.              |

## CI/CD

GitHub Actions workflow’u backend lint/test ve Flutter format kontrollerini otomatikleştirir. Detaylar `.github/workflows/ci.yml` dosyasındadır.
