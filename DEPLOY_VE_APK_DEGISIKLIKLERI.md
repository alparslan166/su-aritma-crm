# Deploy ve APK Değişiklikleri Rehberi

## 🔄 Backend vs Frontend Değişiklikleri

### Backend Deploy (Railway)

**Backend deploy edildiğinde:**
- ✅ **Mevcut APK'lar otomatik olarak yeni backend'i kullanır**
- ✅ Yeni APK build etmeye **gerek yok**
- ✅ Tüm kullanıcılar anında yeni backend özelliklerini görür

**Neden?**
- APK içinde backend URL'i sabit kodlanmış (Railway URL'i)
- Backend değişiklikleri sunucu tarafında olduğu için mevcut APK'lar otomatik kullanır

**Örnek:**
- Backend'de yeni bir API endpoint eklendi
- Backend'de bir bug düzeltildi
- Backend'de validation kuralları değişti
- → **Mevcut APK'lar hemen yeni backend'i kullanır**

---

### Frontend Değişiklikleri (Mobile App)

**Mobile app'te değişiklik yapıldığında:**
- ❌ **Yeni APK build edilmeli**
- ❌ Kullanıcılar yeni APK'yı yüklemeli
- ❌ Eski APK'lar eski özellikleri gösterir

**Neden?**
- Frontend değişiklikleri APK içine derlenir
- APK build edildiğinde kod APK içine gömülür
- Yeni özellikler için yeni APK gerekir

**Örnek:**
- UI değişiklikleri (buton, sayfa, renk)
- Yeni ekranlar eklendi
- Türkçe karakter desteği eklendi
- Hata mesajları iyileştirildi
- → **Yeni APK build edilmeli**

---

## 📊 Son Deploy Analizi

### Son Commit: `feat: add Turkish character support and UTC date formatting`

**Değişiklikler:**
- ✅ Türkçe karakter desteği (frontend)
- ✅ UTC tarih formatı (frontend)
- ✅ Text capitalization (frontend)

**Sonuç:**
- ❌ **Yeni APK build edilmeli** (frontend değişiklikleri var)
- ✅ Backend deploy edildi (migration'lar çalıştı)

---

## 🎯 Ne Zaman Yeni APK Gerekir?

### ✅ Yeni APK Gerekmez (Sadece Backend Deploy)

- Backend API endpoint'leri değişti
- Backend validation kuralları değişti
- Backend'de bug düzeltildi
- Database migration'ları çalıştı
- Backend'de yeni özellik eklendi (sadece API)

### ❌ Yeni APK Gerekir (Frontend Değişiklikleri)

- UI/UX değişiklikleri
- Yeni ekranlar/sayfalar
- Yeni butonlar/özellikler
- Hata mesajları değişti
- Text input davranışı değişti
- Yeni paketler eklendi (`pubspec.yaml`)
- Flutter kod değişiklikleri

---

## 🚀 Pratik Örnekler

### Senaryo 1: Sadece Backend Deploy

```bash
# Backend'de yeni endpoint eklendi
git commit -m "feat: add new customer endpoint"
git push origin main
# Railway otomatik deploy eder
```

**Sonuç:**
- ✅ Mevcut APK'lar yeni endpoint'i kullanabilir
- ❌ Yeni APK gerekmez

---

### Senaryo 2: Frontend Değişiklikleri

```bash
# Mobile app'te yeni sayfa eklendi
git commit -m "feat: add new settings page"
git push origin main
# Backend deploy edilir ama...
```

**Sonuç:**
- ❌ **Yeni APK build edilmeli**
- ❌ Mevcut APK'lar yeni sayfayı göremez

**Yapılacaklar:**
```bash
cd apps/mobile
flutter build apk --release \
  --dart-define=API_BASE_URL=https://su-aritma-crm-production-5d49.up.railway.app/api
```

---

### Senaryo 3: Hem Backend Hem Frontend

```bash
# Backend'de yeni endpoint + Mobile'da yeni sayfa
git commit -m "feat: add invoice feature"
git push origin main
```

**Sonuç:**
- ✅ Backend deploy edilir (mevcut APK'lar endpoint'i kullanabilir)
- ❌ **Yeni APK build edilmeli** (yeni sayfa için)

---

## 📱 Mevcut APK Durumu

### Şu Anki Durum

**Son Deploy:**
- ✅ Backend: Railway'e deploy edildi
- ❌ Frontend: Yeni APK build edilmeli (Türkçe karakter desteği için)

**Mevcut APK'lar:**
- Eski APK'lar: Türkçe karakter desteği yok
- Yeni APK (build edilmeli): Türkçe karakter desteği var

---

## ✅ Kontrol Listesi

Deploy sonrası kontrol edin:

- [ ] Backend deploy başarılı mı? (Railway dashboard)
- [ ] Backend değişiklikleri var mı? → Mevcut APK'lar kullanır
- [ ] Frontend değişiklikleri var mı? → Yeni APK build et
- [ ] Yeni APK build edildi mi?
- [ ] Yeni APK test edildi mi?
- [ ] Kullanıcılara yeni APK dağıtıldı mı?

---

## 🔍 Nasıl Anlaşılır?

### Backend Değişiklikleri mi?

```bash
git diff HEAD~1 apps/backend/
```

Eğer değişiklik varsa → Sadece backend deploy yeterli

### Frontend Değişiklikleri mi?

```bash
git diff HEAD~1 apps/mobile/
```

Eğer değişiklik varsa → Yeni APK build et

---

## 📝 Özet

| Değişiklik Tipi | Yeni APK Gerekir mi? | Açıklama |
|----------------|---------------------|----------|
| Backend API | ❌ Hayır | Mevcut APK'lar otomatik kullanır |
| Backend Bug Fix | ❌ Hayır | Mevcut APK'lar otomatik kullanır |
| Frontend UI | ✅ Evet | Yeni APK build edilmeli |
| Frontend Feature | ✅ Evet | Yeni APK build edilmeli |
| Frontend Bug Fix | ✅ Evet | Yeni APK build edilmeli |

