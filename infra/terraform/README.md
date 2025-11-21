# Terraform İskeleti

Bu klasör, altyapı kaynaklarının IaC ile yönetilmesi için ayrılmıştır. Şimdilik sadece temel dosya iskeleti bulunur.

## Önkoşullar

- Terraform >= 1.6
- AWS erişim anahtarları (veya seçilen bulut sağlayıcıya ait kimlik bilgileri)

## Dosya Yapısı

```
infra/terraform
├── main.tf
├── variables.tf
├── outputs.tf
└── README.md
```

## Komutlar

```
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

> Not: State dosyalarının yerel diskte tutulmaması için backend (S3, GCS vb.) daha sonra eklenecek.

