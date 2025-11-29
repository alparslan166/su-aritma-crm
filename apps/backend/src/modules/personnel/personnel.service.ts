import { PersonnelStatus, Prisma } from "@prisma/client";

import { generateLoginCode, generatePersonnelId } from "@/lib/generators";
import { prisma } from "@/lib/prisma";
import { AppError } from "@/middleware/error-handler";
import { mediaService } from "@/modules/media/media.service";

// Telefon numarasını normalize et (boşlukları ve özel karakterleri temizle)
function normalizePhoneNumber(phone: string): string {
  // Tüm boşlukları, tireleri, parantezleri ve diğer özel karakterleri temizle
  // Sadece rakamları ve başta + işaretini tut
  return phone.replace(/[\s\-()]/g, "");
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
  loginCode?: string;
};

type UpdatePayload = Partial<Omit<CreatePayload, "photoUrl">> & {
  status?: PersonnelStatus;
  photoUrl?: string | null;
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

    const mappedRecords = records.map((record) => {
      const { locationLogs, leaves, ...rest } = record;
      return {
        ...rest,
        lastKnownLocation: locationLogs?.[0] ?? null,
        leaves: leaves ?? [],
      };
    });

    // Transform photoUrl to full URLs
    return mediaService.transformPhotoUrls(mappedRecords);
  }

  async getById(adminId: string, id: string) {
    const record = await prisma.personnel.findFirst({
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

    if (!record) {
      return null;
    }

    // Transform photoUrl to full URL
    return mediaService.transformPhotoUrl(record);
  }

  async create(adminId: string, payload: CreatePayload) {
    const loginCode = payload.loginCode || generateLoginCode();
    const personnelId = await generatePersonnelId(adminId);
    const record = await prisma.personnel.create({
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

    // Transform photoUrl to full URL
    return mediaService.transformPhotoUrl(record);
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
    if (payload.loginCode !== undefined) {
      data.loginCode = payload.loginCode;
      data.loginCodeUpdatedAt = new Date();
    }

    const record = await prisma.personnel.update({
      where: { id },
      data,
    });

    // Transform photoUrl to full URL
    return mediaService.transformPhotoUrl(record);
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
    return prisma.personnelLeave.findMany({
      where: { personnelId },
      orderBy: { startDate: "desc" },
    });
  }

  async createLeave(
    adminId: string,
    personnelId: string,
    payload: {
      startDate: Date;
      endDate: Date;
      reason?: string;
    },
  ) {
    await this.ensureOwnership(adminId, personnelId);
    if (payload.endDate < payload.startDate) {
      throw new AppError("End date must be after start date", 400);
    }
    return prisma.personnelLeave.create({
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
    const leave = await prisma.personnelLeave.findFirst({
      where: { id: leaveId, personnelId },
    });
    if (!leave) {
      throw new AppError("Leave not found", 404);
    }
    await prisma.personnelLeave.delete({
      where: { id: leaveId },
    });
  }
}

export const personnelService = new PersonnelService();
