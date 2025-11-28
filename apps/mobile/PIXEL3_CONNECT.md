# Pixel 3 Cihazını Bağlama

Pixel 3 cihazınızı Flutter ile kullanmak için aşağıdaki adımları izleyin:

## USB ile Bağlama

1. **USB Kablosu ile Bağlayın**
   - Pixel 3'ü Mac'inize USB kablosu ile bağlayın
   - Cihazda "USB debugging" izni isteyecek, "Allow" deyin

2. **Developer Options Açık Olmalı**
   - Ayarlar → Telefon Hakkında → Yapı Numarası'na 7 kez tıklayın
   - Ayarlar → Geliştirici Seçenekleri → USB Debugging'i açın

3. **Cihazı Kontrol Edin**
   ```bash
   adb devices
   ```
   Pixel 3'ü görmelisiniz: `XXXXXXXXX device`

## Wireless Debugging (Android 11+)

1. **Wireless Debugging Açın**
   - Ayarlar → Geliştirici Seçenekleri → Wireless Debugging
   - "Wireless debugging" açın
   - "Pair device with pairing code" seçin

2. **IP ve Port'u Alın**
   - Ekranda IP adresi ve port numarası görünecek
   - Örnek: `192.168.1.100:12345`

3. **Pairing Yapın**
   ```bash
   adb pair 192.168.1.100:12345
   ```
   - Pairing code'u girin (ekranda görünen)

4. **Bağlanın**
   ```bash
   adb connect 192.168.1.100:XXXXX
   ```
   - Port numarasını kullanın (pairing'den sonra gösterilen)

## Flutter ile Çalıştırma

Cihaz bağlandıktan sonra:

```bash
cd apps/mobile
flutter devices  # Pixel 3'ü görmelisiniz
flutter run -d <device-id>  # Pixel 3'ün device ID'sini kullanın
```

## Sorun Giderme

### Cihaz Görünmüyor

1. **USB Debugging Kontrolü**
   - Developer Options → USB Debugging açık mı?
   - Cihazda "USB debugging" izni verildi mi?

2. **ADB Restart**
   ```bash
   adb kill-server
   adb start-server
   adb devices
   ```

3. **USB Kablosu**
   - Farklı bir USB kablosu deneyin
   - USB portunu değiştirin

4. **Mac'te İzin**
   - Sistem Ayarları → Güvenlik → USB erişimine izin verin

### "Unauthorized" Hatası

1. Cihazda "USB debugging" izni isteyen popup'ı kontrol edin
2. "Always allow from this computer" seçeneğini işaretleyin
3. "Allow" butonuna tıklayın

## Hızlı Komutlar

```bash
# Cihazları listele
adb devices
flutter devices

# Pixel 3'ü bul
adb devices | grep -i pixel

# Flutter ile çalıştır
flutter run -d <pixel3-device-id>
```

