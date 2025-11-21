# Kullanıcı Hikâyeleri ve Epic'ler

Bu doküman, `ana-plan.txt` içindeki kapsamı rol bazlı epic’lere ayırır ve her epic için kullanıcı hikâyeleri ile kabul kriterlerini tanımlar.

## Epic: Alt Admin – Personel Yönetimi

**Kapsam:** Personel kayıtları, kimlik bilgileri, izin parametreleri ve iş atama hazırlıklarının yönetilmesi.

1. **AA-PERS-001 – Personel Listeleme**
   - Alt admin olarak tüm personelleri tek sayfada filtreleyebilmek isterim.
   - _Kabul kriterleri:_ Liste sıralanabilir, arama ve durum filtreleri vardır; en üstte “Personel Ekle” CTA’sı bulunur.
2. **AA-PERS-002 – Personel Oluşturma**
   - Alt admin olarak yeni personel bilgilerini (isim, telefon, e-posta, kayıt tarihi) girip kayıt etmek isterim.
   - _Kabul kriterleri:_ Zorunlu alan validasyonları yapılır; kayıt sonrası 6 haneli giriş şifresi otomatik üretilip detay sayfasında görüntülenir.
3. **AA-PERS-003 – Personel Şifre Yönetimi**
   - Alt admin olarak personel şifresini görüntüleyip gerektiğinde yeni bir şifre üretebilmek isterim.
   - _Kabul kriterleri:_ “Yeni Şifre Oluştur” butonu yeni kod üretir, audit log’a işlenir, personel eski şifreyle giriş yapamaz.
4. **AA-PERS-004 – Personel Düzenleme/Silme**
   - Alt admin olarak personel detaylarını güncelleyip kayıtları silebilmek isterim.
   - _Kabul kriterleri:_ Silme işlemi geri alınamaz şekilde onay ister; düzenleme sonrası değişiklikler kaydedilir.
5. **AA-PERS-005 – Personel İzinleri**
   - Alt admin olarak personel izin parametrelerini tanımlayıp kaydedebilmek isterim.
   - _Kabul kriterleri:_ İzin değişiklikleri API seviyesinde yetkilendirme servislerine işlenir.

## Epic: Alt Admin – İş Yaşam Döngüsü

**Kapsam:** İş oluşturma, durum takibi, personel atama, geçmiş işler ve bakım otomasyonları.

1. **AA-JOB-001 – İş Oluşturma**
   - Alt admin olarak müşteri ve konum bilgileriyle yeni iş oluşturmak isterim.
   - _Kabul kriterleri:_ Harita otomatik adresi gösterir; isteğe bağlı personel ataması yapılabilir.
2. **AA-JOB-002 – Durum Göstergesi**
   - Alt admin olarak mevcut işlerin durumlarını renk kodlu kartlarda görmek isterim.
   - _Kabul kriterleri:_ Beklemede=mavi, İşe Başladı=turuncu, Teslim= gri, geçmişe taşınır.
3. **AA-JOB-003 – Personel Atama**
   - Alt admin olarak iş listesi veya detayından birden fazla personeli atayabilmek isterim.
   - _Kabul kriterleri:_ Çoklu seçim ve mevcut görev çakışması uyarısı vardır.
4. **AA-JOB-004 – İş Detayı Yönetimi**
   - Alt admin olarak iş detaylarını görüntüleyip düzenlemek/silmek isterim.
   - _Kabul kriterleri:_ Detay sayfasında müşteri, konum, tarih, personel, ücret, fatura, ödeme, notlar gösterilir ve düzenlenebilir.
5. **AA-JOB-005 – Geçmiş İşler & Bakım Hatırlatmaları**
   - Alt admin olarak teslim edilen işleri geçmiş listesinde görmek ve bakım uyarıları almak isterim.
   - _Kabul kriterleri:_ Bakım renk kodları (turuncu/sarı/kırmızı) uygulanır; süre aşılırsa kırmızı çerçeve yanıp bildirim düşer.

## Epic: Alt Admin – Stok ve Malzeme Yönetimi

1. **AA-STK-001 – Stok Listesi**
   - Alt admin olarak stok kalemlerini (kategori, ad, foto, fiyat, mevcut, eşik) yönetmek isterim.
   - _Kabul kriterleri:_ Kritik eşik altı kayıtlar uyarı verir.
2. **AA-STK-002 – Malzeme Kullanımı**
   - Alt admin olarak personelin iş tesliminde seçtiği malzemelerin stoktan otomatik düşülmesini isterim.
   - _Kabul kriterleri:_ Kullanılan adet kadar stok azalır; fiyat bilgisi rapora yansır.

## Epic: Bildirim ve Konum Servisleri

1. **AA-NTF-001 – Rol Bazlı Bildirim**
   - Sistem olarak belirli olaylarda hedef role push/web bildirimi göndermek isterim.
   - _Kabul kriterleri:_ Job durum değişikliği, bakım hatırlatma, yeni admin başvurusu gibi tetikleyiciler tanımlıdır.
2. **AA-LOC-001 – Konum Logları**
   - Sistem olarak personelin iş başlangıç/bitiş konumlarını kayıt altında tutmak isterim.
   - _Kabul kriterleri:_ Yayın izni olmayan personel için kayıt tutulmaz; loglar admin iş detaylarında gösterilir.

## Epic: Personel Uygulaması

1. **PR-JOB-001 – Bildirimden İş Detayı Açma**
   - Personel olarak gelen bildirime tıklayınca doğrudan iş detayına gitmek isterim.
   - _Kabul kriterleri:_ Bildirim paneli de iş listesini günceller.
2. **PR-JOB-002 – Mevcut İş Listesi**
   - Personel olarak bana atanan işleri müşteri adı/konumu/tarihiyle görmek isterim.
   - _Kabul kriterleri:_ İşe başla ve detay gör butonları her kartta bulunur.
3. **PR-JOB-003 – İşe Başlama/Teslim**
   - Personel olarak işe başladığımı ve teslim ettiğimi sistemde işaretleyebilmek isterim.
   - _Kabul kriterleri:_ Durum admin paneline gerçek zamanlı yansır.
4. **PR-JOB-004 – İş Teslim Formu**
   - Personel olarak ücret, not, bakım tarihi, fotoğraf ve kullanılan malzemeleri girerek teslim etmek isterim.
   - _Kabul kriterleri:_ Malzeme seçimi stokla entegre; fotoğraf yüklenir; teslim sonrası 2 gün read-only erişim verilir.
5. **PR-JOB-005 – Süre Sonu Kısıtlaması**
   - Personel olarak 2 gün sonra iş detayını açtığımda sadece uyarı mesajı görüp erişim alamam.
   - _Kabul kriterleri:_ API yetkisiz döner, tekrar açmak Alt Admin onayı gerektirir.

### Faz 2 Ek Hikâyeler
6. **PR-JOB-006 – Realtime Güncelleme**
   - Personel olarak iş durum değişiklikleri anında kartlara yansısın isterim.
   - _Kabul kriterleri:_ Socket.IO veya push event geldiğinde liste otomatik yenilenir, manual refresh gerekmez.
7. **PR-JOB-007 – Teslim Formu**
   - Teslim sırasında ücret, bakım süresi ve fotoğraf yükleyebileyim; kullanılan malzemeler stoktan düşsün.
   - _Kabul kriterleri:_ Form validasyonları, backend stok düşümü ve JobStatusHistory kayıtları doğrulanır.
8. **PR-JOB-008 – Read-only Detay**
   - 48 saatlik pencere sonrası job detayında sadece “Teslim sonrası görüntüleme” etiketi görürüm.
   - _Kabul kriterleri:_ Backend 403 döndüğünde UI read-only moda geçer, CTA’lar kapanır.

## Epic: Ana Admin & Abonelik

1. **MA-ADM-001 – Yeni Admin Onayı**
   - Ana admin olarak yeni başvuruları görüp onaylayarak sisteme erişim vermek isterim.
   - _Kabul kriterleri:_ Bildirim panelinde “Admin onayı bekleniyor” mesajı gösterilir; onay sonrası hesap aktif olur.
2. **MA-ADM-002 – Admin Listesi ve Durum Göstergesi**
   - Ana admin olarak tüm adminleri abonelik/deneme durumlarına göre renk kodlu çerçeveyle görmek isterim.
   - _Kabul kriterleri:_ Deneme süresi <3 gün sarı, <1 gün kırmızı kutucuk; aboneler siyah çerçeve.
3. **MA-ADM-003 – Abonelik & Ödeme Paneli**
   - Admin olarak abonelik tipi, başlangıç/bitiş tarihleri ve durumumu görebilmek, abonelik güncellemesi yapabilmek isterim.
   - _Kabul kriterleri:_ Ödeme paneli başarıyla tamamlanınca tarih alanları otomatik güncellenir.
4. **MA-ADM-004 – Alt Admin Silme Otomasyonu**
   - Ana admin olarak alt admini sildiğimde tüm personel ve iş ilanlarının otomatik silinmesini isterim.
   - _Kabul kriterleri:_ Cascade işlemi doğrulanır; kalıntı veri kalmaz.

## Epic: Kimlik Doğrulama ve Giriş Akışı

1. **AUTH-001 – Admin Girişi**
   - Alt/Ana admin olarak verilen şifreyle giriş yapmak ve cihazda oturumun hatırlanmasını isterim.
   - _Kabul kriterleri:_ İlk açılışta giriş ekranı admin/personel sekmeleri gösterir; JWT token saklanır.
2. **AUTH-002 – Personel Girişi**
   - Personel olarak adminin verdiği kullanıcı adı/şifreyle giriş yapmak isterim.
   - _Kabul kriterleri:_ Başarılı giriş sonrası cihazda oturum kalır; şifre değişince yeniden giriş istenir.

## Epic: Raporlama ve Finans (Son Faz)

1. **FIN-001 – Ödeme Kaydı**
   - Alt admin olarak işe ait tahsilat ve ödeme durumlarını kaydetmek isterim.
   - _Kabul kriterleri:_ Ücret/fatura/ödeme alanları iş detaylarında güncel gösterilir.
2. **FIN-002 – Fatura & Gelir-Gider**
   - Sistem olarak fatura PDF’i oluşturmak ve gelir-gider hesaplarını raporlamak isterim.
   - _Kabul kriterleri:_ PDF üretimi tetiklenir; gelir-gider raporu filtrelenebilir.
