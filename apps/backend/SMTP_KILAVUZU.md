# SMTP E-posta Ayarları Kılavuzu

Bu kılavuz, e-posta doğrulama ve şifre sıfırlama özelliği için SMTP ayarlarının nasıl yapılandırılacağını açıklar.

## 📧 Gmail App Password Alma

### 1. Google Hesabı Ayarları
1. [Google Hesap Ayarları](https://myaccount.google.com) sayfasına gidin
2. Sol menüden **"Güvenlik"** seçin
3. **"2 Adımlı Doğrulama"** açık olmalı (kapalıysa açın)

### 2. App Password Oluşturma
1. [App Passwords](https://myaccount.google.com/apppasswords) sayfasına gidin
2. **"Uygulama seç"** → **"Diğer (Özel ad)"** seçin
3. İsim girin: `Su Aritma CRM`
4. **"Oluştur"** butonuna tıklayın
5. 16 haneli şifreyi kopyalayın (örn: `bnmi plxj dtsk gxtt`)

> ⚠️ Bu şifreyi bir yere kaydedin! Tekrar gösterilmez.

## 🚀 Railway'de SMTP Ayarları

### Ayarları Değiştirme
1. [Railway Dashboard](https://railway.app/dashboard) → Backend projesi
2. **Variables** sekmesine gidin
3. Aşağıdaki değişkenleri güncelleyin:

| Değişken | Açıklama | Örnek |
|----------|----------|-------|
| `SMTP_HOST` | Gmail SMTP sunucusu | `smtp.gmail.com` |
| `SMTP_PORT` | Port numarası | `587` |
| `SMTP_SECURE` | SSL kullanımı | `false` |
| `SMTP_USER` | Gmail adresiniz | `yeni-email@gmail.com` |
| `SMTP_PASS` | App Password (boşluksuz) | `bnmiplxjdtskgxtt` |
| `SMTP_FROM` | Gönderen adresi | `yeni-email@gmail.com` |

### Önemli Notlar
- App Password'daki **boşlukları kaldırın**: `bnmi plxj dtsk gxtt` → `bnmiplxjdtskgxtt`
- `SMTP_USER` ve `SMTP_FROM` aynı e-posta olmalı
- Değişiklik sonrası Railway otomatik deploy yapar

## 🔄 E-posta Değiştirme Adımları

1. **Yeni Gmail hesabında 2FA açın**
2. **Yeni App Password oluşturun** (yukarıdaki adımlar)
3. **Railway'de değişkenleri güncelleyin:**
   - `SMTP_USER` → yeni e-posta
   - `SMTP_PASS` → yeni app password
   - `SMTP_FROM` → yeni e-posta
4. **Deploy tamamlanmasını bekleyin** (~1-2 dk)
5. **Test edin:** Kayıt ol veya şifremi unuttum deneyin

## 🧪 Test Etme

### Kayıt Testi
1. Uygulamadan yeni hesap oluşturun
2. E-posta kutunuza doğrulama kodu gelmeli
3. Spam klasörünü de kontrol edin

### Şifre Sıfırlama Testi
1. Giriş sayfasında "Şifremi unuttum" tıklayın
2. E-posta adresinizi girin
3. Şifre sıfırlama kodu gelmeli

## ❓ Sorun Giderme

### E-posta Gelmiyorsa
1. **Spam klasörünü kontrol edin**
2. **App Password doğru mu?** (boşluksuz olmalı)
3. **2FA açık mı?** (App Password için gerekli)
4. **Railway loglarını kontrol edin:**
   - Backend → Deployments → En son deployment → Logs
   - `❌ Failed to send` hatası varsa SMTP bilgileri yanlış

### "Less Secure Apps" Hatası
Gmail artık "less secure apps" desteklemiyor. **App Password** kullanmanız gerekiyor.

### Farklı E-posta Sağlayıcıları

#### Outlook/Hotmail
```
SMTP_HOST=smtp-mail.outlook.com
SMTP_PORT=587
SMTP_SECURE=false
```

#### Yahoo Mail
```
SMTP_HOST=smtp.mail.yahoo.com
SMTP_PORT=587
SMTP_SECURE=false
```

## 📞 Destek

Sorun yaşarsanız Railway loglarından hata mesajını kontrol edin ve gerekirse SMTP bilgilerini tekrar girin.

