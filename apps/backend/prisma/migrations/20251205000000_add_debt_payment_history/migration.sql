-- CreateTable
CREATE TABLE "DebtPaymentHistory" (
    "id" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "paidAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "DebtPaymentHistory_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "DebtPaymentHistory_customerId_idx" ON "DebtPaymentHistory"("customerId");

-- CreateIndex
CREATE INDEX "DebtPaymentHistory_paidAt_idx" ON "DebtPaymentHistory"("paidAt");

-- AddForeignKey
ALTER TABLE "DebtPaymentHistory" ADD CONSTRAINT "DebtPaymentHistory_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "Customer"("id") ON DELETE CASCADE ON UPDATE CASCADE;

