-- Add personnelId column to Personnel table
ALTER TABLE "Personnel" ADD COLUMN IF NOT EXISTS "personnelId" TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS "Personnel_personnelId_key" ON "Personnel"("personnelId");
