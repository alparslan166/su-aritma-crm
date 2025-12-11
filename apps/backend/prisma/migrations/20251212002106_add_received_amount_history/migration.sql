-- CreateTable
CREATE TABLE IF NOT EXISTS "ReceivedAmountHistory" (
    "id" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "receivedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ReceivedAmountHistory_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX IF NOT EXISTS "ReceivedAmountHistory_customerId_idx" ON "ReceivedAmountHistory"("customerId");

-- CreateIndex
CREATE INDEX IF NOT EXISTS "ReceivedAmountHistory_receivedAt_idx" ON "ReceivedAmountHistory"("receivedAt");

-- AddForeignKey
ALTER TABLE "ReceivedAmountHistory" ADD CONSTRAINT "ReceivedAmountHistory_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "Customer"("id") ON DELETE CASCADE ON UPDATE CASCADE;

