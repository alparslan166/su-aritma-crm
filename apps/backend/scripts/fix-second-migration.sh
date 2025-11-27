#!/bin/bash

# İkinci failed migration'ı düzelt

echo "🔄 İkinci failed migration düzeltiliyor..."

# PostgreSQL connection string
DATABASE_URL="postgresql://postgres:ezxcbkKCcAsFbRpugzHZmOyOOUsaBKPb@switchback.proxy.rlwy.net:10192/railway"

# Migration'ı sil
psql "$DATABASE_URL" -c "DELETE FROM \"_prisma_migrations\" WHERE migration_name = '20251119132546_add_admin_password';"

echo "✅ Migration silindi!"
echo "💡 Şimdi Railway'de deploy'u tekrar başlatın"

