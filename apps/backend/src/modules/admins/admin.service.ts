import { prisma } from "@/lib/prisma";
import { AppError } from "@/middleware/error-handler";

export class AdminService {
  /**
   * Get all admins (only for ANA admin)
   */
  async getAllAdmins() {
    return prisma.admin.findMany({
      select: {
        id: true,
        adminId: true,
        name: true,
        email: true,
        phone: true,
        role: true,
        status: true,
        emailVerified: true,
        createdAt: true,
        updatedAt: true,
        subscription: {
          select: {
            id: true,
            planType: true,
            status: true,
            startDate: true,
            endDate: true,
            trialEnds: true,
          },
        },
      },
      orderBy: {
        createdAt: "desc",
      },
    });
  }

  /**
   * Get admin by ID with full details
   */
  async getAdminById(adminId: string) {
    const admin = await prisma.admin.findUnique({
      where: { id: adminId },
      include: {
        subscription: true,
        _count: {
          select: {
            personnel: true,
            customers: true,
            jobs: true,
            inventoryItems: true,
          },
        },
      },
    });

    if (!admin) {
      throw new AppError("Admin not found", 404);
    }

    return admin;
  }

  /**
   * Delete admin and all related data (only for ANA admin)
   */
  async deleteAdmin(adminId: string): Promise<void> {
    const admin = await prisma.admin.findUnique({
      where: { id: adminId },
    });

    if (!admin) {
      throw new AppError("Admin not found", 404);
    }

    if (admin.role === "ANA") {
      throw new AppError("Cannot delete ANA admin", 400);
    }

    console.log(`🗑️ Starting admin deletion for: ${admin.name} (${admin.email})`);

    // Delete all related data in correct order (same as account deletion)
    // 1. Delete job notes
    await prisma.jobNote.deleteMany({
      where: {
        job: { adminId },
      },
    });

    // 2. Delete job status history
    await prisma.jobStatusHistory.deleteMany({
      where: {
        job: { adminId },
      },
    });

    // 3. Delete job personnel assignments
    await prisma.jobPersonnel.deleteMany({
      where: {
        job: { adminId },
      },
    });

    // 4. Delete jobs
    await prisma.job.deleteMany({
      where: { adminId },
    });

    // 5. Delete invoices
    await prisma.invoice.deleteMany({
      where: { adminId },
    });

    // 6. Delete customers
    await prisma.customer.deleteMany({
      where: { adminId },
    });

    // 7. Delete personnel leaves
    await prisma.personnelLeave.deleteMany({
      where: {
        personnel: { adminId },
      },
    });

    // 8. Delete location logs
    await prisma.locationLog.deleteMany({
      where: {
        personnel: { adminId },
      },
    });

    // 9. Delete personnel
    await prisma.personnel.deleteMany({
      where: { adminId },
    });

    // 10. Delete operations
    await prisma.operation.deleteMany({
      where: { adminId },
    });

    // 11. Delete inventory transactions
    await prisma.inventoryTransaction.deleteMany({
      where: {
        item: { adminId },
      },
    });

    // 12. Delete inventory items
    await prisma.inventoryItem.deleteMany({
      where: { adminId },
    });

    // 13. Delete notifications
    await prisma.notification.deleteMany({
      where: { adminId },
    });

    // 14. Delete subscription
    await prisma.subscription.deleteMany({
      where: { adminId },
    });

    // 15. Delete verification codes
    await prisma.verificationCode.deleteMany({
      where: { email: admin.email },
    });

    // 16. Delete device tokens
    await prisma.deviceToken.deleteMany({
      where: { adminId },
    });

    // 17. Finally, delete the admin
    await prisma.admin.delete({
      where: { id: adminId },
    });

    console.log(`✅ Admin deleted successfully: ${admin.name} (${admin.email})`);
  }
}

