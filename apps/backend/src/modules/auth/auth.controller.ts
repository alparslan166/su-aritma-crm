import bcrypt from "bcryptjs";
import { NextFunction, Request, Response } from "express";
import { z } from "zod";

import { prisma } from "@/lib/prisma";
import { getAdminId } from "@/lib/tenant";
import { AppError } from "@/middleware/error-handler";

const loginSchema = z.object({
  identifier: z.string().min(3),
  password: z.string().min(4),
  role: z.enum(["admin", "personnel"]).optional(),
});

export const loginHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const payload = loginSchema.parse(req.body);
    const role = payload.role || "admin"; // Default to admin for backward compatibility

    if (role === "admin") {
      const admin = await prisma.admin.findUnique({
        where: { id: payload.identifier },
      });

      if (!admin || !admin.passwordHash) {
        throw new AppError("Geçersiz kullanıcı veya şifre", 401);
      }

      const isValid = await bcrypt.compare(payload.password, admin.passwordHash);
      if (!isValid) {
        throw new AppError("Geçersiz kullanıcı veya şifre", 401);
      }

      res.json({
        success: true,
        data: {
          id: admin.id,
          name: admin.name,
          role: admin.role,
        },
      });
    } else if (role === "personnel") {
      // Personnel login with loginCode
      const personnel = await prisma.personnel.findUnique({
        where: { id: payload.identifier },
      });

      if (!personnel) {
        throw new AppError("Geçersiz personel kodu", 401);
      }

      if (personnel.status !== "ACTIVE") {
        throw new AppError("Personel hesabı aktif değil", 403);
      }

      // Compare loginCode (6-digit code)
      if (personnel.loginCode !== payload.password) {
        throw new AppError("Geçersiz giriş kodu", 401);
      }

      res.json({
        success: true,
        data: {
          id: personnel.id,
          name: personnel.name,
          role: "personnel",
        },
      });
    } else {
      throw new AppError("Geçersiz rol", 400);
    }
  } catch (error) {
    next(error as Error);
  }
};

const updateProfileSchema = z.object({
  name: z.string().min(2).optional(),
  phone: z.string().min(6).optional(),
  email: z.string().email().optional(),
  companyName: z.string().optional(),
  companyAddress: z.string().optional(),
  companyPhone: z.string().optional(),
  companyEmail: z.string().email().optional(),
  taxOffice: z.string().optional(),
  taxNumber: z.string().optional(),
  logoUrl: z.string().optional().or(z.literal("")),
});

export const getProfileHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const admin = await prisma.admin.findUnique({
      where: { id: adminId },
    });

    if (!admin) {
      throw new AppError("Admin not found", 404);
    }

    res.json({
      success: true,
      data: {
        id: admin.id,
        name: admin.name,
        phone: admin.phone,
        email: admin.email,
        role: admin.role,
        companyName: admin.companyName ?? null,
        companyAddress: admin.companyAddress ?? null,
        companyPhone: admin.companyPhone ?? null,
        companyEmail: admin.companyEmail ?? null,
        taxOffice: admin.taxOffice ?? null,
        taxNumber: admin.taxNumber ?? null,
        logoUrl: admin.logoUrl ?? null,
      },
    });
  } catch (error) {
    next(error as Error);
  }
};

export const updateProfileHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const payload = updateProfileSchema.parse(req.body);

    const updateData: {
      name?: string;
      phone?: string;
      email?: string;
      companyName?: string | null;
      companyAddress?: string | null;
      companyPhone?: string | null;
      companyEmail?: string | null;
      taxOffice?: string | null;
      taxNumber?: string | null;
      logoUrl?: string | null;
    } = {};
    
    if (payload.name !== undefined) updateData.name = payload.name;
    if (payload.phone !== undefined) updateData.phone = payload.phone;
    if (payload.email !== undefined) {
      // Empty string means remove email (set to null)
      updateData.email = payload.email === "" ? null : payload.email;
    }
    if (payload.companyName !== undefined) {
      updateData.companyName = payload.companyName === "" ? null : payload.companyName;
    }
    if (payload.companyAddress !== undefined) {
      updateData.companyAddress = payload.companyAddress === "" ? null : payload.companyAddress;
    }
    if (payload.companyPhone !== undefined) {
      updateData.companyPhone = payload.companyPhone === "" ? null : payload.companyPhone;
    }
    if (payload.companyEmail !== undefined) {
      updateData.companyEmail = payload.companyEmail === "" ? null : payload.companyEmail;
    }
    if (payload.taxOffice !== undefined) {
      updateData.taxOffice = payload.taxOffice === "" ? null : payload.taxOffice;
    }
    if (payload.taxNumber !== undefined) {
      updateData.taxNumber = payload.taxNumber === "" ? null : payload.taxNumber;
    }
    // Handle logoUrl: empty string means remove logo (set to null), undefined means keep existing
    if (payload.logoUrl !== undefined) {
      updateData.logoUrl = payload.logoUrl === "" ? null : payload.logoUrl;
    }

    const updated = await prisma.admin.update({
      where: { id: adminId },
      data: updateData,
    });

    res.json({
      success: true,
      data: {
        id: updated.id,
        name: updated.name,
        phone: updated.phone,
        email: updated.email,
        role: updated.role,
        companyName: updated.companyName ?? null,
        companyAddress: updated.companyAddress ?? null,
        companyPhone: updated.companyPhone ?? null,
        companyEmail: updated.companyEmail ?? null,
        taxOffice: updated.taxOffice ?? null,
        taxNumber: updated.taxNumber ?? null,
        logoUrl: updated.logoUrl ?? null,
      },
    });
  } catch (error) {
    next(error as Error);
  }
};
