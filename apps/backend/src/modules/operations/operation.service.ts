import { Prisma } from "@prisma/client";

import { prisma } from "@/lib/prisma";
import { AppError } from "@/middleware/error-handler";

type CreateOperationPayload = {
  name: string;
  description?: string;
  isActive?: boolean;
};

type UpdateOperationPayload = Partial<CreateOperationPayload>;

class OperationService {
  private async ensureOperation(adminId: string, operationId: string) {
    const operation = await prisma.operation.findFirst({
      where: { id: operationId, adminId },
    });
    if (!operation) {
      throw new AppError("Operation not found", 404);
    }
    return operation;
  }

  async list(adminId: string, activeOnly: boolean = false) {
    const where: Prisma.OperationWhereInput = {
      adminId,
    };
    if (activeOnly) {
      where.isActive = true;
    }
    return prisma.operation.findMany({
      where,
      orderBy: { name: "asc" },
    });
  }

  async getById(adminId: string, operationId: string) {
    return this.ensureOperation(adminId, operationId);
  }

  async create(adminId: string, payload: CreateOperationPayload) {
    return prisma.operation.create({
      data: {
        adminId,
        name: payload.name,
        description: payload.description,
        isActive: payload.isActive ?? true,
      },
    });
  }

  async update(adminId: string, operationId: string, payload: UpdateOperationPayload) {
    await this.ensureOperation(adminId, operationId);
    return prisma.operation.update({
      where: { id: operationId },
      data: {
        name: payload.name,
        description: payload.description,
        isActive: payload.isActive,
      },
    });
  }

  async delete(adminId: string, operationId: string) {
    await this.ensureOperation(adminId, operationId);
    // Check if operation is used in any jobs
    const jobsCount = await prisma.job.count({
      where: {
        operationId,
        adminId,
      },
    });
    if (jobsCount > 0) {
      throw new AppError("Cannot delete operation that is used in jobs", 400);
    }
    await prisma.operation.delete({ where: { id: operationId } });
  }
}

export const operationService = new OperationService();

