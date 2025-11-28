#!/bin/bash

# Railway Deployment Script
# Bu script Railway'e backend ve database deploy etmek için kullanılır

set -e

echo "🚀 Railway Deployment Başlatılıyor..."

# 1. Railway CLI kontrolü
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI bulunamadı. Lütfen kurun:"
    echo "   brew install railway"
    echo "   veya: npm install -g @railway/cli"
    exit 1
fi

echo "✅ Railway CLI bulundu"

# 2. Railway'a giriş kontrolü
if ! railway whoami &> /dev/null; then
    echo "🔐 Railway'a giriş yapılıyor..."
    railway login
else
    echo "✅ Railway'a giriş yapılmış"
fi

# 3. Proje kontrolü
cd "$(dirname "$0")"

if [ ! -f ".railway/project.json" ]; then
    echo "📦 Yeni Railway projesi oluşturuluyor..."
    railway init
else
    echo "✅ Railway projesi mevcut"
fi

# 4. PostgreSQL Database ekleme kontrolü
echo "🗄️  PostgreSQL database kontrol ediliyor..."
if ! railway status | grep -q "postgres"; then
    echo "📊 PostgreSQL database ekleniyor..."
    railway add --database postgres
    echo "✅ PostgreSQL database eklendi"
else
    echo "✅ PostgreSQL database mevcut"
fi

# 5. Environment variables ayarlama
echo "🔐 Environment variables ayarlanıyor..."

# Zorunlu variables
railway variables set NODE_ENV=production
railway variables set PORT=4000

# Database URL kontrolü
if railway variables | grep -q "DATABASE_URL"; then
    echo "✅ DATABASE_URL mevcut"
else
    echo "⚠️  DATABASE_URL bulunamadı. Lütfen Railway Dashboard'dan PostgreSQL servisinden DATABASE_URL'i kopyalayın ve ayarlayın:"
    echo "   railway variables set DATABASE_URL='postgresql://...'"
    echo "   railway variables set DIRECT_URL='postgresql://...'"
fi

echo ""
echo "📋 Şimdi aşağıdaki environment variables'ları manuel olarak ayarlamanız gerekiyor:"
echo ""
echo "1. AWS S3 (Medya yükleme için):"
echo "   railway variables set AWS_REGION=eu-central-1"
echo "   railway variables set AWS_ACCESS_KEY_ID=your-access-key-id"
echo "   railway variables set AWS_SECRET_ACCESS_KEY=your-secret-access-key"
echo "   railway variables set S3_MEDIA_BUCKET=your-bucket-name"
echo ""
echo "2. Firebase Cloud Messaging:"
echo "   railway variables set FCM_SERVER_KEY=your-fcm-server-key"
echo ""
echo "3. Redis (Opsiyonel):"
echo "   railway add --database redis"
echo "   railway variables set REDIS_URL=\$REDIS_URL"
echo ""

# 6. Deploy
read -p "Deploy etmek istiyor musunuz? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Deploy başlatılıyor..."
    railway up
    echo "✅ Deploy tamamlandı!"
    echo ""
    echo "🌐 Public domain oluşturmak için Railway Dashboard'dan:"
    echo "   Backend servisi → Settings → Networking → Generate Domain"
    echo ""
    echo "🔍 Health check için:"
    echo "   curl https://your-app.railway.app/api/health"
else
    echo "⏸️  Deploy iptal edildi"
fi

echo ""
echo "✅ Railway deployment hazırlığı tamamlandı!"

