# Railway Root Directory Ayarlama

## Adım Adım Talimatlar

### 1. Railway Dashboard'a Giriş

1. [Railway.app](https://railway.app) → Giriş yapın
2. Projenizi seçin: **"empowering-mindfulness"**

### 2. Backend Servisine Gidin

1. Sol taraftaki servisler listesinden **"su-aritma-crm"** servisine tıklayın
2. (Postgres değil, backend servisi)

### 3. Settings Sekmesine Gidin

1. Üst menüden **"Settings"** sekmesine tıklayın
2. (Şu anda muhtemelen "Deployments" veya başka bir sekmedesiniz)

### 4. General veya Source Bölümünü Bulun

Settings sayfasında şu bölümler olabilir:
- **General** (Genel Ayarlar)
- **Source** (Kaynak Kod)
- **Networking** (Ağ Ayarları)
- **Build** (Build Ayarları)
- **Deploy** (Deploy Ayarları)

### 5. Root Directory Ayarını Bulun

**Yöntem 1: Source Sekmesi (En Yaygın)**

1. Settings sayfasında **"Source"** sekmesine tıklayın
2. "Repository" veya "Source" bölümünde
3. **"Root Directory"** veya **"Working Directory"** alanını bulun
4. Bu alana `apps/backend` yazın
5. **"Save"** veya **"Update"** butonuna tıklayın

**Yöntem 2: General Sekmesi**

1. Settings sayfasında **"General"** sekmesine tıklayın
2. "Service Settings" veya "Configuration" bölümünde
3. **"Root Directory"** alanını bulun
4. Bu alana `apps/backend` yazın
5. **"Save"** veya **"Update"** butonuna tıklayın

**Yöntem 3: Build Sekmesi**

1. Settings sayfasında **"Build"** sekmesine tıklayın
2. "Build Configuration" bölümünde
3. **"Root Directory"** veya **"Working Directory"** alanını bulun
4. Bu alana `apps/backend` yazın
5. **"Save"** veya **"Update"** butonuna tıklayın

## Görsel İpuçları

Root Directory alanı genellikle:
- Bir text input kutusu olarak görünür
- "Root Directory", "Working Directory", "Base Directory" gibi etiketlerle işaretlenir
- Repository path'inin altında veya yanında bulunur
- Boş olabilir veya `/` yazabilir

## Eğer Bulamazsanız

Railway'ın yeni arayüzünde bazen farklı yerlerde olabilir:

1. **Settings > Source** → Repository ayarlarının altında
2. **Settings > Build** → Build configuration'ın içinde
3. **Settings > General** → Service configuration'da

## Alternatif: Railway Config File

Eğer UI'da bulamazsanız, proje root'una `railway.json` dosyası ekleyebilirsiniz (zaten ekledik):

```json
{
  "rootDirectory": "apps/backend"
}
```

Bu dosya commit edilip push edildiğinde Railway otomatik olarak algılar.

## Ayarladıktan Sonra

1. Root Directory'yi `apps/backend` olarak ayarlayın
2. **"Save"** veya **"Update"** butonuna tıklayın
3. Railway otomatik olarak yeni bir deployment başlatacak
4. Veya manuel olarak **"Redeploy"** yapabilirsiniz

## Kontrol

Yeni deployment'ın build loglarında:
- `apps/backend/package.json` dosyasını bulmalı
- Node.js projesi olarak algılanmalı
- Build başarılı olmalı

