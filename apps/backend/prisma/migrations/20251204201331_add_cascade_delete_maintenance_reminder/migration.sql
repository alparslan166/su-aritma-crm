-- AlterTable
ALTER TABLE "MaintenanceReminder" DROP CONSTRAINT "MaintenanceReminder_jobId_fkey";

-- AddForeignKey
ALTER TABLE "MaintenanceReminder" ADD CONSTRAINT "MaintenanceReminder_jobId_fkey" FOREIGN KEY ("jobId") REFERENCES "Job"("id") ON DELETE CASCADE ON UPDATE CASCADE;

