# Admin Yönetimi ve Veri Ekleme Rehberi

## 📋 Mevcut Adminleri Listeleme

```bash
# Railway CLI ile
railway run npm run seed:update-admin

# Railway Dashboard Shell'den
npm run seed:update-admin
```

## 🚀 Railway'de Admin Ekleme

### Yöntem 1: Railway CLI ile (Önerilen)

```bash
# Railway'e bağlan
railway link

# Script'i Railway'de çalıştır
railway run npm run seed:add-admin
```

### Yöntem 2: Railway Dashboard'dan

1. Railway Dashboard'a gidin
2. Backend servisinizi seçin
3. **Deployments** sekmesine gidin
4. **Shell** sekmesine tıklayın
5. Şu komutu çalıştırın:

```bash
npm run seed:add-admin
```

## 📋 Varsayılan Admin Bilgileri

Script şu bilgilerle bir admin oluşturur:

- **Ad**: Test Admin
- **Email**: test@suaritma.com
- **Şifre**: 1234
- **Telefon**: +90 555 123 45 67
- **Rol**: ALT
- **Firma Adı**: Test Su Arıtma Ltd.
- **Firma Adresi**: İstanbul, Türkiye
- **Vergi Dairesi**: Kadıköy
- **Vergi No**: 1234567890

## 🔧 Özelleştirme

Script'i düzenlemek için `apps/backend/scripts/add-admin.ts` dosyasını açın ve `adminData` objesindeki değerleri değiştirin.

## ✅ Başarılı Çıktı

Script başarıyla çalıştığında şu çıktıyı göreceksiniz:

```
✨ Yeni admin oluşturuldu!

✅ Admin başarıyla oluşturuldu/güncellendi!
📋 Admin Bilgileri:
   ID: clx...
   Ad: Test Admin
   Email: test@suaritma.com
   Telefon: +90 555 123 45 67
   Rol: ALT
   Şifre: 1234
   Firma Adı: Test Su Arıtma Ltd.
   ...

🔐 Giriş bilgileri:
   Email: test@suaritma.com
   Şifre: 1234
```

## 🔄 Mevcut Admin Güncelleme

### Admin Listesini Görüntüleme

```bash
npm run seed:update-admin
```

### Admin Güncelleme

```bash
# Email ile admin güncelleme
npm run seed:update-admin -- --email=test@suaritma.com --name="Yeni Ad" --password="yenişifre"

# Tüm alanları güncelleme örneği
npm run seed:update-admin -- \
  --email=test@suaritma.com \
  --name="Güncellenmiş Ad" \
  --phone="+90 555 999 88 77" \
  --password="yenişifre123" \
  --companyName="Yeni Firma Adı" \
  --companyAddress="Yeni Adres" \
  --taxOffice="Yeni Vergi Dairesi" \
  --taxNumber="9876543210"
```

### Güncellenebilir Alanlar

- `--name`: Admin adı
- `--phone`: Telefon numarası
- `--password`: Şifre (otomatik hash'lenir)
- `--role`: Rol (ANA veya ALT)
- `--companyName`: Firma adı
- `--companyAddress`: Firma adresi
- `--companyPhone`: Firma telefonu
- `--companyEmail`: Firma email'i
- `--taxOffice`: Vergi dairesi
- `--taxNumber`: Vergi numarası

### Örnekler

```bash
# Sadece şifre değiştirme
npm run seed:update-admin -- --email=test@suaritma.com --password="yenişifre"

# Sadece firma bilgilerini güncelleme
npm run seed:update-admin -- \
  --email=test@suaritma.com \
  --companyName="Yeni Firma" \
  --taxOffice="Kadıköy" \
  --taxNumber="1234567890"

# Ad ve telefon güncelleme
npm run seed:update-admin -- \
  --email=test@suaritma.com \
  --name="Ahmet Yılmaz" \
  --phone="+90 555 111 22 33"
```

## 📦 Mevcut Admin'e Test Verileri Ekleme

Mevcut bir admin'e test verileri eklemek için:

### Railway Dashboard'dan DATABASE_URL Alma

1. Railway Dashboard → **su-aritma-crm** servisi
2. **Variables** sekmesine tıklayın
3. `DATABASE_URL` değişkenini bulun
4. Değerini kopyalayın (şu formatta olmalı: `postgresql://...`)

### Local'de Çalıştırma

```bash
cd apps/backend

# DATABASE_URL'i set ederek çalıştırın
DATABASE_URL="postgresql://user:password@host:port/database" npm run seed:admin-data -- --email=test@suaritma.com
```

**Örnek:**
```bash
DATABASE_URL="postgresql://postgres:password@switchback.proxy.rlwy.net:10192/railway" npm run seed:admin-data -- --email=test@suaritma.com
```

### Admin Listesini Görüntüleme

```bash
DATABASE_URL="postgresql://..." npm run seed:admin-data
```

### Eklenen Veriler

Script şu verileri ekler:

1. **Personel** (5 kişi)
   - Aktif personel kayıtları

2. **Müşteriler** (8 müşteri)
   - Borcu gelen müşteriler (4 adet)
   - Bakımı gelen müşteriler (4 adet)
   - Normal müşteriler

3. **Stok** (6 ürün)
   - Düşük stoklu ürünler
   - Farklı kategoriler (Filtre, Pompa, Yedek Parça)

4. **Geçmiş İşler** (8 iş)
   - Tamamlanmış işler (COMPLETED)
   - Teslim edilmiş işler (DELIVERED)
   - Geçmiş tarihlerde yapılan işler
   - İş durumu geçmişi

5. **Bakım Hatırlatmaları**
   - Yaklaşan bakımlar
   - Gelecek bakımlar

6. **Bildirimler** (5 bildirim)
   - İş tamamlandı bildirimleri
   - Ödeme gecikmesi bildirimleri
   - Bakım zamanı bildirimleri
   - Düşük stok uyarıları
   - Yeni iş atama bildirimleri
   - Bazıları okunmuş, bazıları okunmamış

### Railway'de Çalıştırma

```bash
# Railway CLI ile
railway run npm run seed:admin-data -- --email=test@suaritma.com

# Railway Dashboard Shell'den
npm run seed:admin-data -- --email=test@suaritma.com
```

### Örnek Çıktı

```
📝 Admin bulundu: Test Admin (test@suaritma.com)

🔄 Veri ekleme başlatılıyor...

🔄 Personel ekleniyor...
   ✓ Ahmet Yılmaz eklendi
   ✓ Mehmet Demir eklendi
   ...

🔄 Müşteriler ekleniyor...
   ✓ İstanbul Su Arıtma Ltd. eklendi (Borçlu) (Bakımı Gelen)
   ✓ Ankara Temiz Su A.Ş. eklendi (Borçlu)
   ...

🔄 Stok ekleniyor...
   ✓ Sediment Filtre 10 inç (Stok: 5)
   ...

🔄 Geçmiş işler ekleniyor...
   ✓ İstanbul Su Arıtma Ltd. - Su Arıtma Cihazı Kurulumu (COMPLETED)
   ...

🔄 Bakım hatırlatmaları ekleniyor...
   ✓ Bakım hatırlatması eklendi (15.01.2025)
   ...

🔄 Bildirimler ekleniyor...
   ✓ İş Tamamlandı
   ✓ Ödeme Gecikmesi
   ...

✅ Tüm veriler başarıyla eklendi!

📊 Özet:
   - Personel: 5
   - Müşteriler: 8
   - Stok: 6
   - İşler: 8
   - Bildirimler: 5
```

