import bcrypt from "bcryptjs";
import { NextFunction, Request, Response } from "express";
import { z } from "zod";

import { prisma } from "@/lib/prisma";
import { AppError } from "@/middleware/error-handler";

const loginSchema = z.object({
  identifier: z.string().min(3),
  password: z.string().min(4),
  role: z.enum(["admin", "personnel"]).optional(),
});

export const loginHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
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

