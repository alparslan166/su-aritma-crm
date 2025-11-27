-- Tüm failed migration'ları göster
SELECT 
    migration_name, 
    started_at, 
    finished_at, 
    applied_steps_count,
    rolled_back_at,
    CASE 
        WHEN finished_at IS NULL AND rolled_back_at IS NULL THEN 'FAILED'
        WHEN rolled_back_at IS NOT NULL THEN 'ROLLED_BACK'
        ELSE 'SUCCESS'
    END as status
FROM "_prisma_migrations"
ORDER BY started_at DESC;

-- Tüm failed migration'ları sil (DİKKAT: Sadece failed olanları)
-- Önce yukarıdaki query ile kontrol edin, sonra bu komutu çalıştırın
DELETE FROM "_prisma_migrations" 
WHERE finished_at IS NULL 
  AND rolled_back_at IS NULL
  AND migration_name IN ('20251118223050_name', '20251119132546_add_admin_password');

-- Alternatif: Tüm bu migration'ları sil (kaç tane varsa)
DELETE FROM "_prisma_migrations" 
WHERE migration_name IN ('20251118223050_name', '20251119132546_add_admin_password');

