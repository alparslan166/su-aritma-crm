-- Drop unique constraint on personnelId
ALTER TABLE "Personnel" DROP CONSTRAINT IF EXISTS "Personnel_personnelId_key";

-- Add unique constraint on adminId + personnelId combination
ALTER TABLE "Personnel" ADD CONSTRAINT "Personnel_adminId_personnelId_key" UNIQUE ("adminId", "personnelId");

-- Add index on adminId (if not exists)
CREATE INDEX IF NOT EXISTS "Personnel_adminId_idx" ON "Personnel"("adminId");

