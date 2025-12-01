# 🔔 Bildirim Sistemi Dokümantasyonu

Bu dokümantasyon, CRM projesindeki Firebase Cloud Messaging (FCM) tabanlı bildirim sistemini açıklar.

## 📋 Özellikler

### 1. İş Ataması → Personel Bildirimi
- Admin bir personele iş atadığında
- Personelin telefonuna push notification gönderilir
- Bildirim notification panelinde görüntülenir
- İş detay sayfasına yönlendirme payload'ı içerir

### 2. Personel "İşe Başla" → Admin Bildirimi
- Personel mobil uygulamada "İşe Başla" tuşuna bastığında
- Admin paneline anlık bildirim gönderilir
- WebSocket ve FCM üzerinden iletim

### 3. Personel "İşi Bitir / Teslim Et" → Admin Bildirimi
- Personel işi tamamladığında
- Admin paneline push notification gönderilir
- "İş tamamlandı" içeriği JSON payload'ı ile

### 4. Personel Yeni Müşteri Eklediğinde → Admin Bildirimi
- Personel uygulamadan yeni müşteri eklediğinde
- Admin paneline "Yeni Müşteri Eklendi" bildirimi gönderilir
- Müşteri ID, ad soyad, ekleyen personel bilgisi payload içinde

## 🏗️ Mimari

### Backend

#### FCM Servisi (`fcm.service.ts`)
- Token-based bildirim gönderimi
- Topic-based bildirim gönderimi (fallback)
- Device token kayıt ve yönetimi
- Invalid token temizleme

#### Notification Servisi (`notification.service.ts`)
- Event-specific bildirim metodları:
  - `sendJobAssignedToEmployee()`
  - `sendJobStartedToAdmin()`
  - `sendJobCompletedToAdmin()`
  - `sendCustomerCreatedToAdmin()`

#### Database Schema
```prisma
model DeviceToken {
  id          String   @id @default(cuid())
  token       String   @unique
  platform    String   // "android" | "ios" | "web"
  userId      String
  userType    String   // "admin" | "personnel"
  adminId     String?
  personnelId String?
  isActive    Boolean  @default(true)
  lastUsedAt  DateTime @default(now())
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt
}
```

### Mobile App (Flutter)

#### Push Notification Service
- FCM token otomatik kaydı
- Platform detection (Android/iOS)
- Foreground, background ve terminated state handling
- Local notification gösterimi
- Notification tap handling

#### Token Kayıt
```dart
await _client.post("/notifications/register-token", data: {
  "token": token,
  "platform": platform, // "android" | "ios"
});
```

## 🔧 Kurulum

### 1. Backend Environment Variables
```env
FCM_SERVER_KEY=your_fcm_server_key_here
```

### 2. Database Migration
```bash
cd apps/backend
npx prisma migrate deploy
```

### 3. Mobile App
FCM token kaydı otomatik olarak yapılır. Uygulama açıldığında:
1. FCM token alınır
2. Backend'e kaydedilir
3. Role-based topic'lere subscribe olunur

## 📡 API Endpoints

### Token Kayıt
```
POST /api/notifications/register-token
Headers:
  x-admin-id: <admin_id> (admin için)
  x-personnel-id: <personnel_id> (personnel için)
Body:
{
  "token": "fcm_token_here",
  "platform": "android" | "ios" | "web"
}
```

### Token Kaldırma
```
POST /api/notifications/unregister-token
Body:
{
  "token": "fcm_token_here"
}
```

## 📦 Payload Formatı

Tüm bildirimlerde standart payload formatı:

```json
{
  "type": "job_assigned" | "job_started" | "job_completed" | "customer_created",
  "jobId": "12345", // job event'leri için
  "customerId": "67890", // customer event'i için
  "personnelId": "personnel_id",
  "adminId": "admin_id",
  "title": "İş Başlığı",
  "personnelName": "Personel Adı",
  "customerName": "Müşteri Adı"
}
```

## 🧪 Test

### Manuel Test
1. Admin bir personele iş ata → Personel bildirimi kontrol et
2. Personel işe başla → Admin bildirimi kontrol et
3. Personel işi bitir → Admin bildirimi kontrol et
4. Personel müşteri ekle → Admin bildirimi kontrol et

### Token Kontrolü
```sql
SELECT * FROM "DeviceToken" WHERE "isActive" = true;
```

## 🔍 Troubleshooting

### Bildirimler gelmiyor
1. FCM_SERVER_KEY doğru mu kontrol et
2. Device token kayıtlı mı kontrol et
3. Token aktif mi kontrol et (`isActive = true`)
4. Backend loglarını kontrol et

### Invalid Token Hatası
- Invalid token'lar otomatik olarak `isActive = false` yapılır
- Token refresh olduğunda yeni token kaydedilir

## 📝 Notlar

- Topic-based bildirimler fallback olarak kullanılır
- WebSocket real-time updates için kullanılır
- Her kullanıcı birden fazla cihazdan giriş yapabilir (çoklu token desteklenir)
- Invalid token'lar otomatik temizlenir

