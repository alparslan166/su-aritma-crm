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
      // Admin login with email and password
      const admin = await prisma.admin.findUnique({
        where: { email: payload.identifier },
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
      // Personnel login with personnelId and loginCode
      // personnelId is now admin-specific, so we need to find by personnelId
      const personnel = await prisma.personnel.findFirst({
        where: { 
          personnelId: payload.identifier,
        },
      });

      if (!personnel) {
        throw new AppError("Geçersiz personel kodu", 401);
      }

      if (personnel.status !== "ACTIVE") {
        throw new AppError("Personel hesabı aktif değil", 403);
      }

      // Compare loginCode
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

const registerSchema = z.object({
  name: z.string().min(2, "İsim en az 2 karakter olmalıdır"),
  email: z.string().email("Geçerli bir e-posta adresi giriniz"),
  password: z.string().min(6, "Şifre en az 6 karakter olmalıdır"),
  phone: z.string().min(6, "Telefon numarası en az 6 karakter olmalıdır"),
  role: z.enum(["ANA", "ALT"]).default("ALT"),
});

export const registerHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const payload = registerSchema.parse(req.body);

    // Check if email already exists
    const existingAdmin = await prisma.admin.findUnique({
      where: { email: payload.email },
    });

    if (existingAdmin) {
      throw new AppError("Bu e-posta adresi zaten kullanılıyor", 409);
    }

    // Hash password
    const passwordHash = await bcrypt.hash(payload.password, 10);

    // Create admin
    const admin = await prisma.admin.create({
      data: {
        name: payload.name,
        email: payload.email,
        phone: payload.phone,
        role: payload.role,
        passwordHash,
      },
    });

    res.status(201).json({
      success: true,
      data: {
        id: admin.id,
        name: admin.name,
        email: admin.email,
        role: admin.role,
      },
      message: "Kayıt başarıyla oluşturuldu",
    });
  } catch (error) {
    next(error as Error);
  }
};

export const updateProfileHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);
    const payload = updateProfileSchema.parse(req.body);

    const updateData: any = {};
    
    if (payload.name !== undefined) updateData.name = payload.name;
    if (payload.phone !== undefined) updateData.phone = payload.phone;
    if (payload.email !== undefined) {
      // Check if email is being changed and if it's already taken
      const currentAdmin = await prisma.admin.findUnique({ where: { id: adminId } });
      if (payload.email !== currentAdmin?.email) {
        const existingAdmin = await prisma.admin.findUnique({
          where: { email: payload.email },
        });
        if (existingAdmin) {
          throw new AppError("Bu e-posta adresi zaten kullanılıyor", 409);
        }
      }
      updateData.email = payload.email;
    }
    if (payload.companyName !== undefined) {
      updateData.companyName = payload.companyName === "" ? { set: null } : payload.companyName;
    }
    if (payload.companyAddress !== undefined) {
      updateData.companyAddress = payload.companyAddress === "" ? { set: null } : payload.companyAddress;
    }
    if (payload.companyPhone !== undefined) {
      updateData.companyPhone = payload.companyPhone === "" ? { set: null } : payload.companyPhone;
    }
    if (payload.companyEmail !== undefined) {
      updateData.companyEmail = payload.companyEmail === "" ? { set: null } : payload.companyEmail;
    }
    if (payload.taxOffice !== undefined) {
      updateData.taxOffice = payload.taxOffice === "" ? { set: null } : payload.taxOffice;
    }
    if (payload.taxNumber !== undefined) {
      updateData.taxNumber = payload.taxNumber === "" ? { set: null } : payload.taxNumber;
    }
    // Handle logoUrl: empty string means remove logo (set to null), undefined means keep existing
    if (payload.logoUrl !== undefined) {
      updateData.logoUrl = payload.logoUrl === "" ? { set: null } : payload.logoUrl;
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
