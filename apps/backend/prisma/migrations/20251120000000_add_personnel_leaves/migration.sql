-- CreateTable
CREATE TABLE "PersonnelLeave" (
    "id" TEXT NOT NULL,
    "personnelId" TEXT NOT NULL,
    "startDate" TIMESTAMP(3) NOT NULL,
    "endDate" TIMESTAMP(3) NOT NULL,
    "reason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PersonnelLeave_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "PersonnelLeave_personnelId_idx" ON "PersonnelLeave"("personnelId");

-- CreateIndex
CREATE INDEX "PersonnelLeave_startDate_endDate_idx" ON "PersonnelLeave"("startDate", "endDate");

-- AddForeignKey
ALTER TABLE "PersonnelLeave" ADD CONSTRAINT "PersonnelLeave_personnelId_fkey" FOREIGN KEY ("personnelId") REFERENCES "Personnel"("id") ON DELETE CASCADE ON UPDATE CASCADE;

