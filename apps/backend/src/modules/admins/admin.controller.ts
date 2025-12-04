import { NextFunction, Request, Response } from "express";

import { getAdminId } from "@/lib/tenant";
import { AppError } from "@/middleware/error-handler";
import { AdminService } from "./admin.service";

const adminService = new AdminService();

/**
 * Get all admins (ANA admin only)
 */
export const getAllAdminsHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const currentAdminId = getAdminId(req);
    const { prisma } = await import("@/lib/prisma");
    
    // Verify current admin is ANA admin
    const currentAdmin = await prisma.admin.findUnique({
      where: { id: currentAdminId },
    });

    if (!currentAdmin || currentAdmin.role !== "ANA") {
      throw new AppError("Unauthorized: Only ANA admin can access this", 403);
    }

    const admins = await adminService.getAllAdmins();

    res.json({
      success: true,
      data: admins,
    });
  } catch (error) {
    next(error as Error);
  }
};

/**
 * Get admin by ID (ANA admin only)
 */
export const getAdminByIdHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const currentAdminId = getAdminId(req);
    const { prisma } = await import("@/lib/prisma");
    
    // Verify current admin is ANA admin
    const currentAdmin = await prisma.admin.findUnique({
      where: { id: currentAdminId },
    });

    if (!currentAdmin || currentAdmin.role !== "ANA") {
      throw new AppError("Unauthorized: Only ANA admin can access this", 403);
    }

    const { id } = req.params;
    const admin = await adminService.getAdminById(id);

    res.json({
      success: true,
      data: admin,
    });
  } catch (error) {
    next(error as Error);
  }
};

/**
 * Delete admin (ANA admin only)
 */
export const deleteAdminHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const currentAdminId = getAdminId(req);
    const { prisma } = await import("@/lib/prisma");
    
    // Verify current admin is ANA admin
    const currentAdmin = await prisma.admin.findUnique({
      where: { id: currentAdminId },
    });

    if (!currentAdmin || currentAdmin.role !== "ANA") {
      throw new AppError("Unauthorized: Only ANA admin can access this", 403);
    }

    const { id } = req.params;
    
    // Prevent self-deletion
    if (id === currentAdminId) {
      throw new AppError("Cannot delete your own account", 400);
    }

    await adminService.deleteAdmin(id);

    res.json({
      success: true,
      message: "Admin deleted successfully",
    });
  } catch (error) {
    next(error as Error);
  }
};

