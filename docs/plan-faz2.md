# Faz 2 Çalışma Planı – Personel Mobil Akışı

## 1. Backend Destekleri
- Personel’e özel job listesi: `GET /jobs?assignedTo=<personnelId>&status=...`
- İş başlangıç / teslim uçları: `POST /jobs/{id}/start`, `POST /jobs/{id}/deliver`
  - Teslim payload: ücret, alınan notlar, bakım tarihi (ay seçimi), kullanılan malzemeler (id + adet), fotoğraf URL’leri.
  - Teslim sonrası stok güncellemesi ve `JobStatusHistory`.
- İki günlük read-only takibi: personel bazlı `JobPersonnel.deliveredAt` + policy; yetkisiz isteklere 403.
- Medya yükleme: mevcut `/media/sign` uç noktası personel token’ı ile kullanılabilir hale getirilecek (RBAC kontrolü).

## 2. Flutter – Personel Uygulaması
- **Ekran akışı:**
  - Bildirim kutusundan iş detayına deep-link (FCM topic `role-personnel`).
  - `Mevcut İşler` listesi (müşteri, konum, tarih, durum rengi).
  - İş detay sayfası: müşteri bilgileri, konum, notlar, mevcut durum, atanan personeller, kullanılacak malzeme listesi, bakım sayaçları.
  - `İşe Başla` ve `İşi Teslim Et` call-to-action butonları.
- **Teslim formu:**
  - Ücret alanı, not alanı, 1-12 ay seçenekli “Bakım tarihi” seçim komponenti.
  - Fotoğraf yükleme (kamera/galeriden) → presigned URL akışı.
  - Malzeme seçici: stok listesinden çoklu seçim + adet.
- **State yönetimi:** Riverpod + AsyncNotifier; network çağrıları Dio üzerinden `x-personnel-id` header (veya JWT) ile yapılacak.
- **Read-only kuralı:** `deliveredAt + 2 gün < now` ise sadece uyarı ekranı göster; API 403 gelirse UI’da yetkisizlik moduna gir.

## 3. Bildirim & Realtime
- Personel app FCM topic abonelikleri (`role-personnel`, `job-{id}` özel kanalları).
- Socket.IO client entegrasyonu (durum değişikliği vs. anlık güncelleme).
- Teslim sonrası stok-bakım bildirimlerinin alt admin’e yönlendirilmesi: `notificationService.notifyRole("admin", ...)`.

## 4. Test & Doğrulama
- Backend Jest: teslim payload’ı stok düşümü ve JobStatusHistory kayıtlarını doğrular.
- Flutter: Widget + integration testi (iş başlangıç/tamamla akışı, read-only modu).
- Manuel senaryolar: fotoğraf yükleme, malzeme seçimi, bakım tarihlerinin okunması.

## 5. Dokümantasyon
- `docs/roadmap.md` güncellemesi (Faz 2 ilerleme).
- Mobil kullanıcı rehberi: personel ekranlarının kısa kullanım notları (`docs/requirements` altında yeni bölüm).

# Durum & Testler
- [x] Backend uçları (`/personnel/jobs`, `/start`, `/deliver`) devrede.
- [x] Flutter personel paneli (liste + detay + teslim formu) yayınlandı.
- [x] Realtime: Socket.IO client ile job-status event’leri dinleniyor.
- [x] Çalıştırılan komutlar: `npm run lint`, `npm run typecheck`, `npm test`, `flutter analyze`, `flutter test`.
# TODO
1. Faz 2 - Backend (tamamlandı)
2. Faz 2 - Flutter (tamamlandı)
3. Faz 2 - Realtime (tamamlandı)
4. Faz 2 - Test & dokümantasyon (güncel)
