# Railway Node.js Versiyon Düzeltmesi

## Sorun

Prisma 7.0.1, Node.js 20.19+, 22.12+, veya 24.0+ gerektiriyor. Nixpacks'ta `nodejs_24` mevcut değil.

## Çözüm: Railway Dashboard'da NODE_VERSION Ekleyin

### Adım 1: Railway Dashboard'a Gidin

1. [Railway.app](https://railway.app) → Projenize gidin
2. Backend servisinize tıklayın
3. **"Variables"** sekmesine gidin

### Adım 2: NODE_VERSION Environment Variable Ekleyin

1. **"New Variable"** butonuna tıklayın
2. **Name**: `NODE_VERSION`
3. **Value**: `22.12.0`
4. **"Add"** butonuna tıklayın

### Adım 3: Deploy

Railway otomatik olarak yeni deploy başlatacak ve Node.js 22.12.0 kullanacak.

## Alternatif: NVM ile Node.js Kurulumu

Eğer NODE_VERSION environment variable çalışmazsa, nixpacks.toml'a şunu ekleyebilirsiniz:

```toml
[phases.setup]
nixPkgs = ["nodejs_22", "npm-10_x", "openssl", "nvm"]

[phases.install]
cmds = [
  "export NVM_DIR=\"$HOME/.nvm\"",
  "[ -s \"$NVM_DIR/nvm.sh\" ] && . \"$NVM_DIR/nvm.sh\"",
  "nvm install 22.12.0",
  "nvm use 22.12.0",
  "npm ci"
]
```

Ancak en basit çözüm Railway dashboard'unda `NODE_VERSION=22.12.0` environment variable'ı eklemektir.

## Kontrol

Deploy tamamlandıktan sonra logları kontrol edin:

1. **"Deployments"** sekmesine gidin
2. En son deployment'a tıklayın
3. **"View Logs"** butonuna tıklayın
4. Node.js versiyonunu kontrol edin: `node --version` (22.12.0 veya üzeri olmalı)

## Not

- Railway, `NODE_VERSION` environment variable'ını algıladığında otomatik olarak o versiyonu kurar
- Eğer hala sorun olursa, Railway support'a başvurun

