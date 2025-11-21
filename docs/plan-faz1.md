# Faz 1 Çalışma Planı

## 1. Veri modeli güncellemeleri

- `prisma/schema.prisma` içinde personel izin yapısı, job durum geçmişi ve stok kritik alanları netleştirilecek.
- Migrasyon çalıştırılıp `npx prisma migrate dev` ile yeni tablo/sütunlar oluşturulacak.

## 2. Backend modülleri

- `src/modules/personnel` altında servis, controller ve router ile list/create/update/delete/reset-password işlemleri.
- Şifre üretimi için yardımcı fonksiyon + audit log.
- `src/modules/jobs` ile iş oluşturma, atama, durum geçişleri ve geçmiş iş endpoint’leri.
- `src/modules/inventory` CRUD ve stok düşümü işlemleri.
- Socket.IO yayınları (job status) ve bildirim servis tetiklemeleri.

## 3. Flutter Alt Admin ekranları

- `lib/features/admin/personnel` altında liste, form ve detay sayfaları.
- `lib/features/admin/jobs` içinde mevcut işler, detay ve geçmiş iş ekranları + durum renkleri.
- `lib/features/admin/inventory` stok listesi ve düzenleme.
- API servis katmanı (dio) ve Riverpod state yönetimi.

## 4. Test & doğrulama

- Backend’de Jest ile personel/job/inventory servis testleri, Supertest ile endpoint testleri.
- Flutter’da widget/integration testleri: personel listesi ve iş kartlarının renkleri.
- Lint/CI kontrolü.

## 5. Dokümantasyon

- `docs/requirements/user-stories.md` ve `docs/roadmap.md` güncellenerek tamamlanan kapsam işaretlenecek.

# Durum & Testler

- [x] Veri modeli ve backend modülleri genişletildi.
- [x] Flutter Alt Admin personel/iş/stok ekranları yayınlandı.
- [x] Çalıştırılan komutlar: `npm run lint`, `npm run typecheck`, `npm test`, `flutter analyze`, `flutter test`.

# TODO

1. Veri modeli güncellemeleri
2. Backend modülleri
3. Flutter Alt Admin ekranları
4. Test & doğrulama
5. Dokümantasyon
