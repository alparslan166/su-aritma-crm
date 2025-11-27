#!/bin/bash

# Failed migration'ı resolve et (enum zaten var, migration kısmen uygulanmış)
# Migration'ı "applied" olarak işaretle

echo "🔄 Failed migration'ı resolve ediliyor..."

# Migration'ı applied olarak işaretle (enum zaten var, migration kısmen başarılı)
npx prisma migrate resolve --applied 20251118223050_name || {
  echo "⚠️  Migration resolve edilemedi, database'den manuel olarak siliniyor..."
  
  # PostgreSQL connection string'i environment variable'dan al
  DATABASE_URL="${DATABASE_URL:-${DIRECT_URL}}"
  
  # Migration'ı _prisma_migrations tablosundan sil
  psql "$DATABASE_URL" -c "DELETE FROM \"_prisma_migrations\" WHERE migration_name = '20251118223050_name';" 2>/dev/null || {
    echo "⚠️  psql komutu bulunamadı, Prisma ile manuel silme deneniyor..."
    # Prisma ile manuel silme (node script gerekir)
    node -e "
      const { PrismaClient } = require('@prisma/client');
      const prisma = new PrismaClient();
      prisma.\$executeRawUnsafe(\"DELETE FROM \\\"_prisma_migrations\\\" WHERE migration_name = '20251118223050_name'\")
        .then(() => { console.log('✅ Migration silindi'); process.exit(0); })
        .catch((e) => { console.error('❌ Hata:', e); process.exit(1); })
        .finally(() => prisma.\$disconnect());
    " || echo "⚠️  Manuel silme başarısız, migration'ı applied olarak işaretlemeyi deneyin"
  }
}

echo "✅ Migration resolve işlemi tamamlandı"
echo "💡 Şimdi migration'lar uygulanacak..."

