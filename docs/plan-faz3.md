# Faz 3 Çalışma Planı – Bakım Otomasyonları & Bildirimler

## 1. Backend otomasyonları
- BullMQ repeatable job (cron) ile bakım tarihleri yaklaşan işleri kontrol et.
- `MaintenanceReminder` tablosu üzerinden durum (PENDING/SENT/COMPLETED) takibi.
- İş tesliminde seçilen bakım süresine göre `maintenanceDueAt` güncellensin; cron görevleri bu alanı referans alsın.
- Otomatik hatırlatma: 7 gün ve 3 gün kala turuncu/sarı; 1 gün kala kırmızı; süre aşılırsa “Bakım kaçırıldı” bildirimi.
- Alt admin panelinde bu reminder’lar Notification servisine düşsün (`notifyRole("admin", ...)`).

## 2. Flutter – Alt Admin UI
- Geçmiş işler sayfasında bakım geri sayımı ve renk kodları.
- Reminder kartlarında “Tekrar atama” CTA’sı (gelecekteki iş oluşturma sürecini tetikleyecek).
- Bildirim panelinde bakım hatırlatma kartları.
- Job detayında bakım sahibi personeller + seçilen interval bilgisi.

## 3. Bildirim ve Realtime
- Socket.IO kanalına `maintenance-reminder` event’i ekle; alt admin ekranları anında güncellensin.
- Opsiyonel: e-posta/SMS stub’ları (ileri fazda entegre edilecek).

## 4. Test & doğrulama
- Jest: cron job simülasyonu, reminder state geçişleri, bildirim çağrıları.
- Flutter: geçmiş işlerde renk kodu/g geri sayım widget testleri.
- Manuel senaryolar: teslim → bakım süreci → cron tetiklenmesi → alt admin ekranında görünmesi.

## 5. Dokümantasyon
- `docs/requirements/user-stories.md` içine bakım hatırlatma hikâyeleri.
- `docs/roadmap.md` Faz 3 durum takibi.

# Durum & Testler
- [x] Bakım cron + reminder backend devrede.
- [x] Flutter bakım tabı ve gerçek zamanlı güncellemeler tamamlandı.
- [x] Testler: `npm run lint`, `npm run typecheck`, `npm test`, `flutter analyze`, `flutter test`.

# TODO
1. Faz3 – Backend
2. Faz3 – Alt Admin UI
3. Faz3 – Realtime bildirim
4. Faz3 – Test/Dokümantasyon

