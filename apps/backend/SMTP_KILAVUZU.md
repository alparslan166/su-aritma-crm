# E-posta Servisi Kılavuzu (Resend)

Bu kılavuz, e-posta doğrulama ve şifre sıfırlama için Resend API yapılandırmasını açıklar.

> ⚠️ **Not:** SMTP yerine Resend API kullanıyoruz çünkü Railway SMTP portlarını engelliyor.

## 🚀 Resend Kurulumu (5 dakika)

### 1. Hesap Oluştur
1. https://resend.com adresine gidin
2. **Get Started** → GitHub ile giriş yapın
3. E-postanızı doğrulayın

### 2. API Key Al
1. Dashboard'da sol menüden **API Keys** tıklayın
2. **Create API Key** butonuna basın
3. İsim: `su-aritma-crm`
4. Permission: `Full access`
5. **Create** → API key'i kopyalayın

### 3. Railway'e Ekle
1. [Railway Dashboard](https://railway.app/dashboard) → Backend projesi
2. **Variables** sekmesine gidin
3. Ekleyin:

```
RESEND_API_KEY=re_xxxxxxxxxxxxxxxxxxxxxxxxx
```

## 🔄 API Key Değiştirme

1. [Resend Dashboard](https://resend.com) → API Keys
2. Eski key'i **Revoke** edin
3. Yeni key oluşturun
4. Railway'de `RESEND_API_KEY` değişkenini güncelleyin

## 📧 Kendi Domain'inizi Kullanma (Opsiyonel)

Ücretsiz planda e-postalar `onboarding@resend.dev` adresinden gider.
Kendi domain'inizden göndermek için:

1. Resend Dashboard → **Domains** → **Add Domain**
2. Domain'inizi girin (örn: `suaritma.com`)
3. DNS kayıtlarını ekleyin (Resend gösterecek)
4. Doğrulandıktan sonra Railway'e ekleyin:

```
EMAIL_FROM=noreply@suaritma.com
```

## 🧪 Test Etme

### Kayıt Testi
1. Uygulamadan yeni hesap oluşturun
2. E-posta kutunuza doğrulama kodu gelmeli
3. Spam klasörünü de kontrol edin

### Şifre Sıfırlama Testi
1. Giriş sayfasında "Şifremi unuttum" tıklayın
2. E-posta adresinizi girin
3. Şifre sıfırlama kodu gelmeli

### Hesap Silme Testi
1. Profil sayfasında "Hesabı Sil" butonuna basın
2. Doğrulama kodu gelmeli

## ❓ Sorun Giderme

### E-posta Gelmiyorsa
1. **Spam klasörünü kontrol edin**
2. **Railway loglarını kontrol edin:**
   - Backend → Deployments → Logs
   - `❌ Failed to send` hatası varsa API key yanlış olabilir
3. **Resend Dashboard'u kontrol edin:**
   - Logs bölümünde gönderim durumunu görün

### API Key Hatası
- API key `re_` ile başlamalı
- Key'i kopyalarken başında/sonunda boşluk olmamalı

## 📊 Kullanım Limitleri

### Ücretsiz Plan
- **3000 e-posta/ay**
- Günlük limit yok
- `onboarding@resend.dev` gönderen adresi

### Pro Plan ($20/ay)
- **50.000 e-posta/ay**
- Kendi domain'iniz
- Öncelikli destek

## 📞 Destek

- Resend Docs: https://resend.com/docs
- Railway Logs: Dashboard → Deployments → Logs

