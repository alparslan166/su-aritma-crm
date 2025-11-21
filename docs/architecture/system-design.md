# Sistem Mimarisi Özeti

Bu doküman, Flutter + Express/PostgreSQL yığını için servis sınırlarını, veri akışlarını ve temel veri modelini özetler.

## 1. Modüler Mimari

| Katman                       | Sorumluluklar                                                                      | Teknolojiler                                   |
| ---------------------------- | ---------------------------------------------------------------------------------- | ---------------------------------------------- |
| Mobil istemciler             | Alt Admin & Personel Flutter uygulamaları; offline cache, push alma, medya yükleme | Flutter 3, Riverpod/Bloc, Freezed, dio         |
| API Katmanı                  | Kimlik doğrulama, RBAC, REST/gRPC API’ler, websocket yayınları                     | Node.js 20, Express.js, Socket.IO              |
| İşlemci & Kuyruk             | Bildirim, bakım hatırlatma, stok senkronizasyonu, rapor oluşturma                  | BullMQ (Redis), Worker pod’ları                |
| Veri Katmanı                 | İlişkisel veri, konum uzantıları, arama indeksleri                                 | PostgreSQL + PostGIS, Prisma/TypeORM           |
| Önbellek & Orta Katman       | Oturum, hız sınırlama, kısa süreli veri                                            | Redis                                          |
| Depolama & CDN               | Foto/video dosyaları, imzalı URL akışı                                             | AWS S3 (veya eşdeğer) + CloudFront             |
| Harita & Bildirim Servisleri | Geocoding, push bildirimleri                                                       | Google Maps Platform, Firebase Cloud Messaging |
| Observability                | Log, metrik, hata izleme                                                           | Loki/ELK, Prometheus+Grafana, Sentry           |

## 2. Servis Sınırları ve Veri Akışları

1. **Kimlik doğrulama akışı**

   - Mobil istemci → `/auth/login` (kullanıcı adı + tek kullanımlık şifre).
   - API JWT üretir, Redis’te refresh token saklar.
   - RBAC middleware’i her istekte rol bazlı policy uygulaması yapar.

2. **İş oluşturma ve atama akışı**

   - Alt Admin uygulaması REST API aracılığıyla iş kaydı oluşturur.
   - İş kaydı sonrası `JobCreated` olayı kuyruğa düşer; worker push bildirimi tetikler.
   - Personel app websocket/FCM ile bilgilendirilir, iş listesi güncellenir.

3. **Personel teslim akışı**

   - Personel `PUT /jobs/{id}/deliver` ile ücret, bakım tarihi, malzeme listesi, fotoğraf yükler.
   - API stok güncelleme işlemlerini transaction içinde yapar, dosya için S3’e imzalı URL döner.
   - Worker bakım hatırlatma cron job’unu schedule eder (BullMQ repeatable job).

4. **Bakım hatırlatma akışı**

   - Worker her gece due tarihi yaklaşan işleri tarar.
   - Rest API ve notification service alt admin’e push + web bildirimi gönderir, `maintenance_reminder` kaydı oluşturur.

5. **Abonelik/ödeme akışı**
   - Alt admin “Abone Ol” panelinden ödeme sağlayıcı (iyzico/Stripe) Checkout’una yönlendirilir.
   - Başarılı dönüş web hook’u API’ye düşer; abonelik başlangıç/bitiş tarihleri güncellenir, admin listesi renk kodu yenilenir.

## 3. API Kontratları (Örnek)

- `/auth/login`, `/auth/refresh`, `/auth/logout`
- `/personnel` (list/create/update/delete/reset-password)
- `/jobs`, `/jobs/{id}`, `/jobs/{id}/assign`, `/jobs/{id}/status`, `/jobs/{id}/deliver`
- `/inventory/items`, `/inventory/items/{id}`
- `/notifications/subscribe`, `/notifications/{id}/read`
- `/admins` (ana admin paneli), `/subscriptions/checkout`

Tüm endpointler JWT + rol guard ile korunur. Socket.IO kanalları: `jobs:status`, `notifications:role-{roleName}`.

## 4. Veri Modeli (ER Özeti)

| Tablo             | Temel Alanlar                                                                                                           | İlişkiler                       |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------- | ------------------------------- |
| `admins`          | id, name, phone, email, role (`ANA`, `ALT`), status, subscription_id                                                    | 1:N alt admin → personel        |
| `personnel`       | id, admin_id, name, phone, email, hire_date, permissions_json, login_code                                               | N:M işler (join tablosu)        |
| `jobs`            | id, admin_id, customer_id, status, scheduled_at, location, price, invoice_id, payment_status, notes, maintenance_due_at | N:M personel, 1:N job_materials |
| `job_personnel`   | job_id, personnel_id, assigned_at, started_at, delivered_at                                                             | Köprü                           |
| `job_materials`   | job_id, inventory_item_id, quantity, unit_price                                                                         | N:1 inventory                   |
| `customers`       | id, admin_id, name, phone, email, address                                                                               | 1:N jobs                        |
| `inventory_items` | id, admin_id, category, name, photo_url, unit_price, stock_qty, critical_threshold                                      | 1:N job_materials               |
| `notifications`   | id, admin_id, role_target, entity_type, entity_id, type, payload, read_at                                               | -                               |
| `location_logs`   | id, job_id, personnel_id, lat, lng, started_at, ended_at, consent_flag                                                  | -                               |
| `subscriptions`   | id, admin_id, plan_type, start_date, end_date, status, trial_end                                                        | 1:1 admins                      |

Not: PostGIS uzantısı `jobs.location` ve `location_logs` için kullanılacaktır. Audit log tabloları (ör. `personnel_audits`) compliance ihtiyaçlarına göre eklenir.

## 5. Entegrasyon Noktaları

- **Push Bildirimleri:** FCM topic’leri (örn. `role-personnel`, `admin-{adminId}`) + web push VAPID anahtarları.
- **Medya Yükleme:** `POST /media/sign` endpoint’i imzalı URL döndürür, istemci doğrudan S3’e yükler.
- **Harita Servisi:** Geocoding çağrıları backend üzerinden cache’lenir; mobil uygulama sadece koordinat alır.
- **Ölçümler:** Prometheus exporter’ı API ve worker pod’larından metrik toplar, Grafana dashboard’u iş durumu, teslim süresi, bakım kaçırma gibi KPI’ları gösterir.

## 6. Güvenlik ve Erişim

- JWT payload’ında `role`, `adminId`, `personnelId` alanları bulunur; policy engine (Casl/Oso) UI görünürlüğünü de belirler.
- Gizli anahtarlar Secrets Manager/Vault üzerinden sağlanır; Docker image’larında sertifika yoktur.
- Tüm dosya erişimleri imzalı URL ve süre sınırlamasıyla yapılır; log’lar KVKK’ya uygun şekilde maskeleme katmanından geçer.
