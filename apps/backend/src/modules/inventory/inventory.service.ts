import {
  InventoryTransactionType,
  Prisma,
} from "@prisma/client";

import { prisma } from "../../lib/prisma";
import { AppError } from "../../middleware/error-handler";

type ItemPayload = {
  category: string;
  name: string;
  sku?: string;
  unit?: string;
  photoUrl?: string;
  unitPrice: Prisma.Decimal | number;
  stockQty: number;
  criticalThreshold: number;
  reorderPoint?: number;
  reorderQuantity?: number;
  isActive?: boolean;
};

type AdjustPayload = {
  type: InventoryTransactionType;
  quantity: number;
  note?: string;
  jobId?: string;
};

class InventoryService {
  private async ensureItem(adminId: string, id: string) {
    const item = await prisma.inventoryItem.findFirst({ where: { id, adminId } });
    if (!item) {
      throw new AppError("Inventory item not found", 404);
    }
    return item;
  }

  async list(adminId: string) {
    return prisma.inventoryItem.findMany({
      where: { adminId, isActive: true },
      orderBy: { name: "asc" },
    });
  }

  async create(adminId: string, payload: ItemPayload) {
    return prisma.inventoryItem.create({
      data: {
        adminId,
        category: payload.category,
        name: payload.name,
        sku: payload.sku,
        unit: payload.unit,
        photoUrl: payload.photoUrl,
        unitPrice: new Prisma.Decimal(payload.unitPrice),
        stockQty: payload.stockQty,
        criticalThreshold: payload.criticalThreshold,
        reorderPoint: payload.reorderPoint,
        reorderQuantity: payload.reorderQuantity,
        isActive: payload.isActive ?? true,
      },
    });
  }

  async update(adminId: string, id: string, payload: Partial<ItemPayload>) {
    await this.ensureItem(adminId, id);
    return prisma.inventoryItem.update({
      where: { id },
      data: {
        category: payload.category,
        name: payload.name,
        sku: payload.sku,
        unit: payload.unit,
        photoUrl: payload.photoUrl,
        unitPrice: payload.unitPrice ? new Prisma.Decimal(payload.unitPrice as number) : undefined,
        stockQty: payload.stockQty,
        criticalThreshold: payload.criticalThreshold,
        reorderPoint: payload.reorderPoint,
        reorderQuantity: payload.reorderQuantity,
        isActive: payload.isActive,
      },
    });
  }

  async delete(adminId: string, id: string) {
    await this.ensureItem(adminId, id);
    // Soft delete to prevent foreign key errors with UsedProduct
    await prisma.inventoryItem.update({
      where: { id },
      data: { isActive: false },
    });
  }

  async adjust(adminId: string, id: string, payload: AdjustPayload) {
    const item = await this.ensureItem(adminId, id);

    return prisma.$transaction(async (tx) => {
      let newQty = item.stockQty;
      if (payload.type === InventoryTransactionType.INBOUND) {
        newQty += payload.quantity;
      } else if (payload.type === InventoryTransactionType.OUTBOUND) {
        newQty -= payload.quantity;
        if (newQty < 0) {
          throw new AppError("Stock cannot be negative", 400);
        }
      } else if (payload.type === InventoryTransactionType.ADJUSTMENT) {
        newQty = payload.quantity;
      }

      if (payload.jobId) {
        const job = await tx.job.findFirst({ where: { id: payload.jobId, adminId } });
        if (!job) {
          throw new AppError("Related job not found", 404);
        }
      }

      const updated = await tx.inventoryItem.update({
        where: { id },
        data: {
          stockQty: newQty,
          lastRestockedAt:
            payload.type === InventoryTransactionType.INBOUND ? new Date() : item.lastRestockedAt,
        },
      });

      await tx.inventoryTransaction.create({
        data: {
          inventoryItemId: id,
          type: payload.type,
          quantity: payload.quantity,
          jobId: payload.jobId,
          note: payload.note,
        },
      });

      return updated;
    });
  }
}

export const inventoryService = new InventoryService();

