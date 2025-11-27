# Google Play - Mapping File Uyarısı

## Uyarı Mesajı

"Bu App Bundle ile ilişkili kod gösterme dosyası mevcut değil"

## Açıklama

Bu bir **uyarı**, kritik bir hata değil. Uygulamanız yüklenebilir ve yayınlanabilir.

### Mapping File Nedir?

- **Mapping file** (kod gösterme dosyası), R8/ProGuard ile kod karartma (obfuscation) kullanıldığında oluşur
- Crash log'larını okunabilir hale getirmek için kullanılır
- Şu anda uygulamanızda **minify kapalı**, bu yüzden mapping dosyası oluşmamış

## Ne Yapmalı?

### Seçenek 1: Uyarıyı Görmezden Gel (Önerilen - İlk Sürüm İçin)

✅ **Uygulamanız normal şekilde yüklenebilir ve yayınlanabilir**
- Bu uyarı sadece bilgilendirme amaçlı
- İlk sürüm için sorun değil
- İleride minify aktif ederseniz mapping dosyası oluşturulur

**Devam edin**: Sürüm notlarını ekleyip "İncelemeye gönder" butonuna tıklayın.

### Seçenek 2: Mapping File Oluştur (İleride)

Eğer ileride kod karartma (minify) aktif ederseniz:

1. `build.gradle.kts` dosyasında:
   ```kotlin
   buildTypes {
       release {
           isMinifyEnabled = true  // true yap
           isShrinkResources = true
       }
   }
   ```

2. Build yapın:
   ```bash
   flutter build appbundle --release
   ```

3. Mapping dosyası oluşur:
   ```
   build/app/outputs/mapping/release/mapping.txt
   ```

4. Google Play Console'da bu dosyayı yükleyin

## Şu An İçin

✅ **Uyarıyı görmezden gelin ve devam edin**

1. Sürüm notları ekleyin
2. "Kaydet" butonuna tıklayın
3. "İncelemeye gönder" butonuna tıklayın

Uygulamanız normal şekilde yayınlanacaktır.

## Not

- İlk sürüm için mapping file zorunlu değil
- Uygulama boyutu biraz daha büyük olabilir (minify kapalı)
- İleride minify aktif edebilirsiniz

