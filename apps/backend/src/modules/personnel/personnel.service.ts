import { PersonnelStatus, Prisma } from "@prisma/client";

import { generateLoginCode, generatePersonnelId } from "@/lib/generators";
import { prisma } from "@/lib/prisma";
import { AppError } from "@/middleware/error-handler";

// Telefon numarasını normalize et (boşlukları ve özel karakterleri temizle)
function normalizePhoneNumber(phone: string): string {
  // Tüm boşlukları, tireleri, parantezleri ve diğer özel karakterleri temizle
  // Sadece rakamları ve başta + işaretini tut
  return phone.replace(/[\s\-\(\)]/g, "");
}

type ListFilters = {
  search?: string;
  status?: PersonnelStatus;
};

type CreatePayload = {
  name: string;
  phone: string;
  email?: string;
  photoUrl?: string;
  hireDate: Date;
  permissions: Record<string, unknown>;
  canShareLocation?: boolean;
};

type UpdatePayload = Partial<CreatePayload> & {
  status?: PersonnelStatus;
};

class PersonnelService {
  private async ensureOwnership(adminId: string, id: string) {
    const record = await prisma.personnel.findFirst({
      where: { id, adminId },
    });
    if (!record) {
      throw new AppError("Personnel not found", 404);
    }
    return record;
  }

  async list(adminId: string, filters: ListFilters) {
    const where: Prisma.PersonnelWhereInput = { adminId };
    if (filters.status) {
      where.status = filters.status;
    }
    if (filters.search) {
      const normalizedSearch = normalizePhoneNumber(filters.search);
      where.OR = [
        { name: { contains: filters.search, mode: Prisma.QueryMode.insensitive } },
        { phone: { contains: normalizedSearch, mode: Prisma.QueryMode.insensitive } },
        { email: { contains: filters.search, mode: Prisma.QueryMode.insensitive } },
      ];
    }

    const records = await prisma.personnel.findMany({
      where,
      orderBy: { createdAt: "desc" },
      include: {
        locationLogs: {
          orderBy: { startedAt: "desc" },
          take: 1,
          select: {
            lat: true,
            lng: true,
            jobId: true,
            startedAt: true,
          },
        },
        leaves: {
          orderBy: { startDate: "desc" },
        },
      } as Prisma.PersonnelInclude,
    });

    return records.map((record: any) => {
      const { locationLogs, leaves, ...rest } = record;
      return {
        ...rest,
        lastKnownLocation: locationLogs?.[0] ?? null,
        leaves: leaves ?? [],
      };
    });
  }

  async getById(adminId: string, id: string) {
    return prisma.personnel.findFirst({
      where: { id, adminId },
      include: {
        locationLogs: {
          orderBy: { startedAt: "desc" },
          take: 1,
          select: {
            lat: true,
            lng: true,
            jobId: true,
            startedAt: true,
          },
        },
        leaves: {
          orderBy: { startDate: "desc" },
        },
      } as Prisma.PersonnelInclude,
    });
  }

  async create(adminId: string, payload: CreatePayload) {
    const loginCode = generateLoginCode();
    const personnelId = await generatePersonnelId();
    return prisma.personnel.create({
      data: {
        adminId,
        personnelId,
        name: payload.name,
        phone: normalizePhoneNumber(payload.phone),
        email: payload.email,
        photoUrl: payload.photoUrl,
        hireDate: payload.hireDate,
        permissions: payload.permissions as Prisma.InputJsonValue,
        loginCode,
        loginCodeUpdatedAt: new Date(),
        canShareLocation: payload.canShareLocation ?? true,
      },
    });
  }

  async update(adminId: string, id: string, payload: UpdatePayload) {
    await this.ensureOwnership(adminId, id);
    const data: Prisma.PersonnelUpdateInput = {};
    
    if (payload.name !== undefined) {
      data.name = payload.name;
    }
    if (payload.phone !== undefined) {
      data.phone = normalizePhoneNumber(payload.phone);
    }
    if (payload.email !== undefined) {
      data.email = payload.email;
    }
    // photoUrl can be null (to remove), undefined (to keep existing), or a string (to update)
    if (payload.photoUrl !== undefined) {
      data.photoUrl = payload.photoUrl;
    }
    if (payload.hireDate !== undefined) {
      data.hireDate = payload.hireDate;
    }
    if (payload.permissions !== undefined) {
      data.permissions = payload.permissions as Prisma.InputJsonValue;
    }
    if (payload.status !== undefined) {
      data.status = payload.status;
    }
    if (payload.canShareLocation !== undefined) {
      data.canShareLocation = payload.canShareLocation;
    }
    
    return prisma.personnel.update({
      where: { id },
      data,
    });
  }

  async delete(adminId: string, id: string) {
    await this.ensureOwnership(adminId, id);
    await prisma.personnel.delete({
      where: { id },
    });
  }

  async resetCode(adminId: string, id: string) {
    await this.ensureOwnership(adminId, id);
    const loginCode = generateLoginCode();
    return prisma.personnel.update({
      where: { id },
      data: { loginCode, loginCodeUpdatedAt: new Date() },
    });
  }

  async listLeaves(adminId: string, personnelId: string) {
    await this.ensureOwnership(adminId, personnelId);
    return (prisma as any).personnelLeave.findMany({
      where: { personnelId },
      orderBy: { startDate: "desc" },
    });
  }

  async createLeave(adminId: string, personnelId: string, payload: {
    startDate: Date;
    endDate: Date;
    reason?: string;
  }) {
    await this.ensureOwnership(adminId, personnelId);
    if (payload.endDate < payload.startDate) {
      throw new AppError("End date must be after start date", 400);
    }
    return (prisma as any).personnelLeave.create({
      data: {
        personnelId,
        startDate: payload.startDate,
        endDate: payload.endDate,
        reason: payload.reason,
      },
    });
  }

  async deleteLeave(adminId: string, personnelId: string, leaveId: string) {
    await this.ensureOwnership(adminId, personnelId);
    const leave = await (prisma as any).personnelLeave.findFirst({
      where: { id: leaveId, personnelId },
    });
    if (!leave) {
      throw new AppError("Leave not found", 404);
    }
    await (prisma as any).personnelLeave.delete({
      where: { id: leaveId },
    });
  }
}

export const personnelService = new PersonnelService();

