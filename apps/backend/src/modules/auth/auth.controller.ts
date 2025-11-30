import bcrypt from "bcryptjs";
import { NextFunction, Request, Response } from "express";
import { z } from "zod";

import { prisma } from "@/lib/prisma";
import { generateAdminId } from "@/lib/generators";
import { getAdminId } from "@/lib/tenant";
import { AppError } from "@/middleware/error-handler";
import {
  generateVerificationCode,
  sendVerificationEmail,
  sendPasswordResetEmail,
} from "@/lib/email.service";

const loginSchema = z
  .object({
    identifier: z.string().min(1, "Identifier gereklidir"),
    password: z.string().min(1, "Password gereklidir"),
    role: z.enum(["admin", "personnel"]).optional(),
    adminId: z.string().optional(), // Admin ID for personnel login (replaces adminEmail for privacy)
  })
  .refine(
    (data) => {
      // For personnel login, adminId is required
      if (data.role === "personnel" && (!data.adminId || data.adminId.trim().length === 0)) {
        return false;
      }
      return true;
    },
    {
      message: "Personel girişi için Admin ID gereklidir",
      path: ["adminId"],
    },
  );

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
      // Personnel login with personnelId, loginCode, and adminId
      // personnelId is admin-specific (unique per admin), so we need adminId to find the correct admin
      if (!payload.adminId || payload.adminId.trim().length === 0) {
        throw new AppError("Admin ID gereklidir", 400);
      }

      // Normalize adminId (trim and uppercase for consistency)
      const normalizedAdminId = payload.adminId.trim().toUpperCase();

      // First, find the admin by adminId
      const admin = await prisma.admin.findUnique({
        where: { adminId: normalizedAdminId },
      });

      if (!admin) {
        throw new AppError("Geçersiz admin ID", 401);
      }

      // Normalize identifier (trim for consistency)
      const normalizedIdentifier = payload.identifier.trim();

      // Then find personnel by personnelId and adminId (ensures admin-specific uniqueness)
      const personnel = await prisma.personnel.findFirst({
        where: {
          adminId: admin.id,
          personnelId: normalizedIdentifier,
        },
      });

      if (!personnel) {
        console.log(
          `❌ Personnel not found - Admin ID: ${normalizedAdminId}, Personnel ID: ${normalizedIdentifier}`,
        );
        throw new AppError("Geçersiz personel kodu veya admin ID", 401);
      }

      if (personnel.status !== "ACTIVE") {
        throw new AppError("Personel hesabı aktif değil", 403);
      }

      // Compare loginCode (case-insensitive)
      const normalizedLoginCode = (personnel.loginCode || "").trim().toUpperCase();
      const normalizedPassword = (payload.password || "").trim().toUpperCase();

      console.log(
        `🔍 Login attempt - Personnel: ${personnel.name}, Personnel ID: ${personnel.personnelId}`,
      );
      console.log(`🔍 Expected loginCode: ${normalizedLoginCode}, Received: ${normalizedPassword}`);

      if (normalizedLoginCode !== normalizedPassword) {
        console.log(`❌ Login code mismatch`);
        throw new AppError("Geçersiz personel kodu veya şifre", 401);
      }

      console.log(`✅ Login successful for personnel: ${personnel.name}`);

      // Update lastLoginAt
      await prisma.personnel.update({
        where: { id: personnel.id },
        data: { lastLoginAt: new Date() },
      });

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
        adminId: admin.adminId ?? null,
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

    // Generate unique adminId
    let adminId: string;
    try {
      adminId = await generateAdminId();
      console.log(`✅ Generated adminId: ${adminId}`);
    } catch (error) {
      console.error("❌ Failed to generate adminId:", error);
      throw new AppError("Admin ID oluşturulamadı. Lütfen tekrar deneyin.", 500);
    }

    // Create admin (emailVerified defaults to false)
    const admin = await prisma.admin.create({
      data: {
        name: payload.name,
        email: payload.email,
        phone: payload.phone,
        role: payload.role,
        passwordHash,
        adminId,
        emailVerified: false,
      },
    });

    console.log(`✅ Created admin with adminId: ${admin.adminId}`);

    // Generate and send verification code
    const verificationCode = generateVerificationCode();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    await prisma.verificationCode.create({
      data: {
        email: admin.email,
        code: verificationCode,
        type: "email_verification",
        expiresAt,
      },
    });

    // Send verification email (don't block if email fails)
    sendVerificationEmail(admin.email, verificationCode, admin.name).catch((err) => {
      console.error("Failed to send verification email:", err);
    });

    res.status(201).json({
      success: true,
      data: {
        id: admin.id,
        name: admin.name,
        email: admin.email,
        role: admin.role,
        emailVerified: false,
      },
      message: "Kayıt başarıyla oluşturuldu. E-posta adresinize doğrulama kodu gönderildi.",
    });
  } catch (error) {
    next(error as Error);
  }
};

// E-posta doğrulama kodu gönder/tekrar gönder
const sendCodeSchema = z.object({
  email: z.string().email("Geçerli bir e-posta adresi giriniz"),
});

export const sendVerificationCodeHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { email } = sendCodeSchema.parse(req.body);

    const admin = await prisma.admin.findUnique({
      where: { email },
    });

    if (!admin) {
      throw new AppError("Bu e-posta adresi ile kayıtlı hesap bulunamadı", 404);
    }

    if (admin.emailVerified) {
      throw new AppError("E-posta adresi zaten doğrulanmış", 400);
    }

    // Invalidate old codes
    await prisma.verificationCode.updateMany({
      where: {
        email,
        type: "email_verification",
        used: false,
      },
      data: { used: true },
    });

    // Generate new code
    const verificationCode = generateVerificationCode();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    await prisma.verificationCode.create({
      data: {
        email,
        code: verificationCode,
        type: "email_verification",
        expiresAt,
      },
    });

    // Send verification email
    const sent = await sendVerificationEmail(email, verificationCode, admin.name);

    if (!sent) {
      throw new AppError("E-posta gönderilemedi. Lütfen tekrar deneyin.", 500);
    }

    res.json({
      success: true,
      message: "Doğrulama kodu e-posta adresinize gönderildi",
    });
  } catch (error) {
    next(error as Error);
  }
};

// E-posta doğrulama
const verifyEmailSchema = z.object({
  email: z.string().email(),
  code: z.string().length(6, "Doğrulama kodu 6 haneli olmalıdır"),
});

export const verifyEmailHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { email, code } = verifyEmailSchema.parse(req.body);

    const verificationRecord = await prisma.verificationCode.findFirst({
      where: {
        email,
        code,
        type: "email_verification",
        used: false,
        expiresAt: { gt: new Date() },
      },
    });

    if (!verificationRecord) {
      throw new AppError("Geçersiz veya süresi dolmuş doğrulama kodu", 400);
    }

    // Mark code as used
    await prisma.verificationCode.update({
      where: { id: verificationRecord.id },
      data: { used: true },
    });

    // Update admin email verification status
    const admin = await prisma.admin.update({
      where: { email },
      data: { emailVerified: true },
    });

    console.log(`✅ Email verified for admin: ${admin.name} (${admin.email})`);

    res.json({
      success: true,
      data: {
        id: admin.id,
        name: admin.name,
        email: admin.email,
        role: admin.role,
        emailVerified: true,
      },
      message: "E-posta adresi başarıyla doğrulandı",
    });
  } catch (error) {
    next(error as Error);
  }
};

// Şifremi unuttum - kod gönder
const forgotPasswordSchema = z.object({
  email: z.string().email("Geçerli bir e-posta adresi giriniz"),
});

export const forgotPasswordHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { email } = forgotPasswordSchema.parse(req.body);

    const admin = await prisma.admin.findUnique({
      where: { email },
    });

    // Don't reveal if email exists or not for security
    if (!admin) {
      // Still return success to prevent email enumeration
      res.json({
        success: true,
        message: "Eğer bu e-posta adresi kayıtlıysa, şifre sıfırlama kodu gönderildi",
      });
      return;
    }

    // Invalidate old password reset codes
    await prisma.verificationCode.updateMany({
      where: {
        email,
        type: "password_reset",
        used: false,
      },
      data: { used: true },
    });

    // Generate new code
    const resetCode = generateVerificationCode();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    await prisma.verificationCode.create({
      data: {
        email,
        code: resetCode,
        type: "password_reset",
        expiresAt,
      },
    });

    // Send password reset email
    await sendPasswordResetEmail(email, resetCode, admin.name);

    console.log(`📧 Password reset code sent to: ${email}`);

    res.json({
      success: true,
      message: "Eğer bu e-posta adresi kayıtlıysa, şifre sıfırlama kodu gönderildi",
    });
  } catch (error) {
    next(error as Error);
  }
};

// Şifre sıfırlama
const resetPasswordSchema = z.object({
  email: z.string().email(),
  code: z.string().length(6, "Doğrulama kodu 6 haneli olmalıdır"),
  newPassword: z.string().min(6, "Şifre en az 6 karakter olmalıdır"),
});

export const resetPasswordHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { email, code, newPassword } = resetPasswordSchema.parse(req.body);

    const verificationRecord = await prisma.verificationCode.findFirst({
      where: {
        email,
        code,
        type: "password_reset",
        used: false,
        expiresAt: { gt: new Date() },
      },
    });

    if (!verificationRecord) {
      throw new AppError("Geçersiz veya süresi dolmuş doğrulama kodu", 400);
    }

    // Mark code as used
    await prisma.verificationCode.update({
      where: { id: verificationRecord.id },
      data: { used: true },
    });

    // Hash new password and update
    const passwordHash = await bcrypt.hash(newPassword, 10);
    
    await prisma.admin.update({
      where: { email },
      data: { passwordHash },
    });

    console.log(`✅ Password reset successful for: ${email}`);

    res.json({
      success: true,
      message: "Şifreniz başarıyla değiştirildi. Yeni şifrenizle giriş yapabilirsiniz.",
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
      updateData.companyAddress =
        payload.companyAddress === "" ? { set: null } : payload.companyAddress;
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
        adminId: updated.adminId ?? null,
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
