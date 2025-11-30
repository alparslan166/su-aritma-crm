-- Add adminId column to Admin table
ALTER TABLE "Admin" ADD COLUMN "adminId" TEXT;

-- Create unique index on adminId
CREATE UNIQUE INDEX "Admin_adminId_key" ON "Admin"("adminId");

-- Generate adminId for existing admins (will be done via script)

