-- CreateTable
CREATE TABLE "UsedProduct" (
    "id" TEXT NOT NULL,
    "customerId" TEXT NOT NULL,
    "inventoryItemId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL,
    "unit" TEXT,
    "usedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "UsedProduct_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "UsedProduct_customerId_idx" ON "UsedProduct"("customerId");

-- CreateIndex
CREATE INDEX "UsedProduct_inventoryItemId_idx" ON "UsedProduct"("inventoryItemId");

-- AddForeignKey
ALTER TABLE "UsedProduct" ADD CONSTRAINT "UsedProduct_customerId_fkey" FOREIGN KEY ("customerId") REFERENCES "Customer"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "UsedProduct" ADD CONSTRAINT "UsedProduct_inventoryItemId_fkey" FOREIGN KEY ("inventoryItemId") REFERENCES "InventoryItem"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
