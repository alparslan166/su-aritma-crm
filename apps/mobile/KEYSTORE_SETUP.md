# Keystore Oluşturma Adımları

## Komut

```bash
cd apps/mobile/android/app
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

## Sorular ve Doğru Yanıtlar

1. **Enter keystore password**: 
   - ⚠️ **ÖNEMLİ**: Sadece ASCII karakterler kullanın!
   - Türkçe karakterler (ı, ş, ğ, ü, ö, ç) kullanmayın
   - Örnek: `MySecurePass123!` ✅
   - Örnek: `Sifre123!` ✅
   - Örnek: `MyPassword2024!` ✅
   - Yanlış: `Şifre123!` ❌ (ş harfi ASCII değil)
   - Yanlış: `Parola123!` ❌ (ı harfi ASCII değil)

2. **Re-enter new password**: 
   - Aynı şifreyi tekrar girin

3. **What is your first and last name?**
   - İsim: `Alparslan Turan` ✅

4. **What is the name of your organizational unit?**
   - Departman/Birim: `business` ✅

5. **What is the name of your organization?**
   - Şirket/Organizasyon: `su-aritma` ✅

6. **What is the name of your City or Locality?**
   - Şehir: `Ankara` ✅

7. **What is the name of your State or Province?**
   - Eyalet/İl: `Ankara` (veya boş bırakabilirsiniz)
   - ⚠️ **NOT**: Country code değil! Eyalet/il adı olmalı

8. **What is the two-letter country code for this unit?**
   - ⚠️ **ÖNEMLİ**: İki harfli ISO country code
   - Türkiye için: `TR` (06 değil!)
   - Diğer örnekler: `US`, `GB`, `DE`, `FR`

9. **Is CN=... correct?**
   - `yes` veya `y` yazın (Enter'a basın)

## Örnek Tam Komut Akışı

```
Enter keystore password: MySecurePass123!
Re-enter new password: MySecurePass123!
What is your first and last name?
  [Unknown]: Alparslan Turan
What is the name of your organizational unit?
  [Unknown]: business
What is the name of your organization?
  [Unknown]: su-aritma
What is the name of your City or Locality?
  [Unknown]: Ankara
What is the name of your State or Province?
  [Unknown]: Ankara
What is the two-letter country code for this unit?
  [Unknown]: TR
Is CN=Alparslan Turan, OU=business, O=su-aritma, L=Ankara, ST=Ankara, C=TR correct?
  [no]: yes
```

## Hata Durumunda

### "Password is not ASCII" Hatası

Bu hata, password'ta ASCII olmayan karakterler olduğunda oluşur.

**Çözüm:**
1. Komutu tekrar çalıştırın
2. Password olarak **sadece İngilizce harfler, rakamlar ve bazı özel karakterler** kullanın
3. Türkçe karakterler (ı, ş, ğ, ü, ö, ç) kullanmayın

**Örnek güvenli password'lar:**
- `SuAritma2024!`
- `MyAppKey123!`
- `SecurePass2024!`

### Diğer Hatalar

Eğer başka bir hata alırsanız:
1. Komutu tekrar çalıştırın
2. Doğru bilgileri girin
3. State/Province için eyalet/il adı girin (country code değil)

## Başarılı Olursa

Şu mesajı göreceksiniz:
```
Generating 2,048 bit RSA key pair and self-signed certificate (SHA256withRSA) with a validity of 10,000 days
        for: CN=Alparslan Turan, OU=business, O=su-aritma, L=Ankara, ST=Ankara, C=TR
[Storing upload-keystore.jks]
```

## Sonraki Adım

Keystore oluşturulduktan sonra `key.properties` dosyasını oluşturun:

```bash
cd apps/mobile/android
cp key.properties.example key.properties
```

Sonra `key.properties` dosyasını düzenleyin ve keystore şifrenizi girin.

