# Faz Bazlı Yol Haritası

Bu roadmap `ana-plan.txt`, kullanıcı hikâyeleri ve mevcut altyapı iskeletine göre belirlenmiştir. Her faz ölçülebilir “Definition of Done” maddeleriyle tanımlanır.

## Gündemdeki Adımlar

1. **Faz 1 – Alt Admin Operasyonları:** Personel CRUD/şifre, iş oluşturma & durum makinesi, stok ve admin paneli ekranları tamamlanacak; DoD için manuel senaryolar + jest/widget testleri ve Socket.IO yayınları doğrulanacak.
2. **Faz 2 – Personel Mobil Akışı (devam ediyor):** Mobil personel paneli, teslim formu, Socket.IO entegrasyonu ve 2 günlük read-only kuralları tamamlandı; dokümantasyon/test güncellemeleri kaldı.
3. **Faz 3 – Bakım Otomasyonları & Bildirimler:** BullMQ cron, bakım renk kodları ve geçmiş işlerde geri sayım tamamlanacak; jest integration + UI golden testleriyle doğrulanacak.
4. **Faz 4 – Abonelik & Ödeme:** Admin abonelik paneli, deneme uyarıları ve ödeme sağlayıcısı entegrasyonu hayata geçirilecek; sandbox akışı ve finans kayıtları için migration/raporlar hazırlanacak.

## Faz 0 – Temel Altyapı (tamamlandı)

- Monorepo dizin yapısı, CI/CD pipeline, Terraform iskeleti
- Express + Prisma + PostgreSQL çekirdeği
- Flutter giriş akışı (admin/personel) ve testler
- Realtime gateway (Socket.IO), medya presign ve bildirim servisleri

**DoD:** `npm run lint/test/build`, `flutter analyze/test`, CI yeşil.

## Faz 1 – Alt Admin Operasyonları

- Personel CRUD + şifre üretimi API’leri ve ekranları
- İş oluşturma & durum makinesi entegrasyonu
- Stok kayıtları ve kritik eşik uyarıları
- Admin panelinde job list, detay ve geçmiş sayfaları

**DoD:** Alt admin kullanıcı akışları manuel test senaryolarını geçer, jest + widget testleri güncellenir, Socket.IO job status emitleri doğrulanır.

## Faz 2 – Personel Mobil Akışı

- Bildirimden iş detayına yönlendirme + topic abonelikleri
- Mevcut işler listesi, işe başla/teslim et butonları
- Teslim formu (ücret, bakım tarihi, foto, malzeme seçimi)
- Teslim sonrası 2 günlük read-only kısıtlaması

**DoD:** E2E happy-path testi (Flutter integration) + stok düşümü için backend unit testleri + dokümantasyon.

## Faz 3 – Bakım Otomasyonları & Bildirimler

- Bakım tarihine göre cron + BullMQ job planlayıcı
- Bakım renk kodları ve bildirimleri (push + web)
- İş geçmişi ekranında bakım geri sayımı

**DoD:** Cron senaryoları için jest integration testi, bakım kutucuk renkleri için golden/widget testi.

## Faz 4 – Abonelik & Ödeme

- Admin abonelik paneli, deneme süresi uyarıları
- Ödeme sağlayıcı (iyzico/Stripe) entegrasyonu, webhook doğrulama
- Ana admin listesi renk kodları + deneme bitiş bildirimleri

**DoD:** Sandbox ödeme akışı uçtan uca akışı geçer, finans kayıtları için migration + rapor ekranı hazır.

## Faz 5 – Ana Admin & Raporlama

- Yeni admin başvurusu/ onay ekranları
- Alt admin silme cascade otomasyonu
- Fatura PDF üretimi, gelir-gider raporları

**DoD:** Ana admin tüm kritik işlemleri UI’dan tetikleyebilir, PDF çıktıları QA tarafından doğrulanır.

## Faz 6 – Sertifikasyon & Yayın Hazırlığı

- Güvenlik taramaları, yük testi, log/monitoring dashboard’ları
- Kullanıcı eğitimi, dökümantasyon, sürüm notları

**DoD:** Performans test raporu + gözlemlenebilirlik panoları paylaşılır, sürüm 1.0 adayı release branch’ine alınır.
