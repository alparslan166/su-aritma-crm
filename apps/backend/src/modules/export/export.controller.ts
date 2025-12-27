import { NextFunction, Request, Response } from "express";
import ExcelJS from "exceljs";

import { prisma } from "../../lib/prisma";
import { getAdminId } from "../../lib/tenant";

export const exportAllDataHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const adminId = getAdminId(req);

    // Fetch admin info
    const admin = await prisma.admin.findUnique({
      where: { id: adminId },
      select: {
        id: true,
        adminId: true,
        name: true,
        email: true,
        phone: true,
        role: true,
        companyName: true,
        companyAddress: true,
        companyPhone: true,
        companyEmail: true,
        taxOffice: true,
        taxNumber: true,
        createdAt: true,
      },
    });

    if (!admin) {
      return res.status(404).json({ success: false, error: "Admin not found" });
    }

    // Fetch all related data
    const [personnel, customers, jobs, inventoryItems, invoices, subscription] = await Promise.all([
      prisma.personnel.findMany({
        where: { adminId },
        select: {
          id: true,
          personnelId: true,
          name: true,
          phone: true,
          email: true,
          hireDate: true,
          status: true,
          canShareLocation: true,
          lastLoginAt: true,
          createdAt: true,
        },
        orderBy: { createdAt: "desc" },
      }),
      prisma.customer.findMany({
        where: { adminId },
        select: {
          id: true,
          name: true,
          phone: true,
          email: true,
          address: true,
          status: true,
          hasDebt: true,
          debtAmount: true,
          hasInstallment: true,
          installmentCount: true,
          remainingDebtAmount: true,
          paidDebtAmount: true,
          nextMaintenanceDate: true,
          nextDebtDate: true,
          createdAt: true,
        },
        orderBy: { createdAt: "desc" },
      }),
      prisma.job.findMany({
        where: { adminId },
        select: {
          id: true,
          title: true,
          status: true,
          scheduledAt: true,
          price: true,
          paymentStatus: true,
          hasInstallment: true,
          notes: true,
          createdAt: true,
          deliveredAt: true,
          customer: {
            select: { name: true, phone: true },
          },
          personnel: {
            select: {
              personnel: { select: { name: true } },
            },
          },
        },
        orderBy: { createdAt: "desc" },
      }),
      prisma.inventoryItem.findMany({
        where: { adminId },
        select: {
          id: true,
          sku: true,
          name: true,
          category: true,
          unit: true,
          unitPrice: true,
          stockQty: true,
          criticalThreshold: true,
          reorderPoint: true,
          reorderQuantity: true,
          isActive: true,
          lastRestockedAt: true,
          createdAt: true,
        },
        orderBy: { createdAt: "desc" },
      }),
      prisma.invoice.findMany({
        where: { adminId },
        select: {
          id: true,
          invoiceNumber: true,
          customerName: true,
          customerPhone: true,
          customerAddress: true,
          jobTitle: true,
          jobDate: true,
          subtotal: true,
          tax: true,
          total: true,
          notes: true,
          isDraft: true,
          createdAt: true,
        },
        orderBy: { createdAt: "desc" },
      }),
      prisma.subscription.findUnique({
        where: { adminId },
        select: {
          id: true,
          planType: true,
          status: true,
          startDate: true,
          endDate: true,
          trialEnds: true,
          createdAt: true,
        },
      }),
    ]);

    // Create Excel workbook
    const workbook = new ExcelJS.Workbook();
    workbook.creator = "Su Arıtma CRM";
    workbook.created = new Date();

    // Helper function to format dates
    const formatDate = (date: Date | null | undefined): string => {
      if (!date) return "";
      return new Date(date).toLocaleDateString("tr-TR");
    };

    // 1. Admin Info Sheet
    const adminSheet = workbook.addWorksheet("Admin Bilgileri");
    adminSheet.columns = [
      { header: "Alan", key: "field", width: 25 },
      { header: "Değer", key: "value", width: 50 },
    ];
    adminSheet.addRows([
      { field: "Admin ID", value: admin.adminId || "" },
      { field: "İsim", value: admin.name },
      { field: "E-posta", value: admin.email },
      { field: "Telefon", value: admin.phone },
      { field: "Rol", value: admin.role },
      { field: "Firma Adı", value: admin.companyName || "" },
      { field: "Firma Adresi", value: admin.companyAddress || "" },
      { field: "Firma Telefonu", value: admin.companyPhone || "" },
      { field: "Firma E-posta", value: admin.companyEmail || "" },
      { field: "Vergi Dairesi", value: admin.taxOffice || "" },
      { field: "Vergi No", value: admin.taxNumber || "" },
      { field: "Kayıt Tarihi", value: formatDate(admin.createdAt) },
    ]);
    styleHeaderRow(adminSheet);

    // 2. Subscription Sheet
    const subSheet = workbook.addWorksheet("Abonelik");
    subSheet.columns = [
      { header: "Alan", key: "field", width: 25 },
      { header: "Değer", key: "value", width: 50 },
    ];
    if (subscription) {
      subSheet.addRows([
        { field: "Plan Tipi", value: subscription.planType === "monthly" ? "Aylık" : "Yıllık" },
        { field: "Durum", value: subscription.status },
        { field: "Başlangıç Tarihi", value: formatDate(subscription.startDate) },
        { field: "Bitiş Tarihi", value: formatDate(subscription.endDate) },
        { field: "Deneme Bitiş", value: formatDate(subscription.trialEnds) },
      ]);
    } else {
      subSheet.addRow({ field: "Durum", value: "Abonelik bulunamadı" });
    }
    styleHeaderRow(subSheet);

    // 3. Personnel Sheet
    const personnelSheet = workbook.addWorksheet("Personeller");
    personnelSheet.columns = [
      { header: "Personel ID", key: "personnelId", width: 15 },
      { header: "İsim", key: "name", width: 25 },
      { header: "Telefon", key: "phone", width: 15 },
      { header: "E-posta", key: "email", width: 25 },
      { header: "İşe Giriş", key: "hireDate", width: 15 },
      { header: "Durum", key: "status", width: 12 },
      { header: "Konum Paylaşımı", key: "canShareLocation", width: 15 },
      { header: "Son Giriş", key: "lastLoginAt", width: 15 },
      { header: "Kayıt Tarihi", key: "createdAt", width: 15 },
    ];
    personnel.forEach((p) => {
      personnelSheet.addRow({
        personnelId: p.personnelId || "",
        name: p.name,
        phone: p.phone,
        email: p.email || "",
        hireDate: formatDate(p.hireDate),
        status: p.status,
        canShareLocation: p.canShareLocation ? "Evet" : "Hayır",
        lastLoginAt: formatDate(p.lastLoginAt),
        createdAt: formatDate(p.createdAt),
      });
    });
    styleHeaderRow(personnelSheet);

    // 4. Customers Sheet
    const customersSheet = workbook.addWorksheet("Müşteriler");
    customersSheet.columns = [
      { header: "İsim", key: "name", width: 25 },
      { header: "Telefon", key: "phone", width: 15 },
      { header: "E-posta", key: "email", width: 25 },
      { header: "Adres", key: "address", width: 40 },
      { header: "Durum", key: "status", width: 12 },
      { header: "Borç Var", key: "hasDebt", width: 10 },
      { header: "Borç Tutarı", key: "debtAmount", width: 15 },
      { header: "Taksitli", key: "hasInstallment", width: 10 },
      { header: "Taksit Sayısı", key: "installmentCount", width: 12 },
      { header: "Kalan Borç", key: "remainingDebtAmount", width: 15 },
      { header: "Ödenen", key: "paidDebtAmount", width: 15 },
      { header: "Sonraki Bakım", key: "nextMaintenanceDate", width: 15 },
      { header: "Kayıt Tarihi", key: "createdAt", width: 15 },
    ];
    customers.forEach((c) => {
      customersSheet.addRow({
        name: c.name,
        phone: c.phone,
        email: c.email || "",
        address: c.address,
        status: c.status,
        hasDebt: c.hasDebt ? "Evet" : "Hayır",
        debtAmount: c.debtAmount ? Number(c.debtAmount) : 0,
        hasInstallment: c.hasInstallment ? "Evet" : "Hayır",
        installmentCount: c.installmentCount || 0,
        remainingDebtAmount: c.remainingDebtAmount ? Number(c.remainingDebtAmount) : 0,
        paidDebtAmount: c.paidDebtAmount ? Number(c.paidDebtAmount) : 0,
        nextMaintenanceDate: formatDate(c.nextMaintenanceDate),
        createdAt: formatDate(c.createdAt),
      });
    });
    styleHeaderRow(customersSheet);

    // 5. Jobs Sheet
    const jobsSheet = workbook.addWorksheet("İşler");
    jobsSheet.columns = [
      { header: "Başlık", key: "title", width: 30 },
      { header: "Müşteri", key: "customer", width: 25 },
      { header: "Müşteri Tel", key: "customerPhone", width: 15 },
      { header: "Durum", key: "status", width: 15 },
      { header: "Randevu", key: "scheduledAt", width: 15 },
      { header: "Fiyat", key: "price", width: 12 },
      { header: "Ödeme Durumu", key: "paymentStatus", width: 15 },
      { header: "Taksitli", key: "hasInstallment", width: 10 },
      { header: "Personeller", key: "personnel", width: 30 },
      { header: "Tamamlandı", key: "deliveredAt", width: 15 },
      { header: "Kayıt Tarihi", key: "createdAt", width: 15 },
    ];
    jobs.forEach((j) => {
      jobsSheet.addRow({
        title: j.title,
        customer: j.customer?.name || "",
        customerPhone: j.customer?.phone || "",
        status: j.status,
        scheduledAt: formatDate(j.scheduledAt),
        price: j.price ? Number(j.price) : 0,
        paymentStatus: j.paymentStatus,
        hasInstallment: j.hasInstallment ? "Evet" : "Hayır",
        personnel: j.personnel.map((p) => p.personnel.name).join(", "),
        deliveredAt: formatDate(j.deliveredAt),
        createdAt: formatDate(j.createdAt),
      });
    });
    styleHeaderRow(jobsSheet);

    // 6. Inventory Sheet
    const inventorySheet = workbook.addWorksheet("Stok");
    inventorySheet.columns = [
      { header: "SKU", key: "sku", width: 15 },
      { header: "Ürün Adı", key: "name", width: 30 },
      { header: "Kategori", key: "category", width: 20 },
      { header: "Birim", key: "unit", width: 10 },
      { header: "Birim Fiyat", key: "unitPrice", width: 12 },
      { header: "Stok Miktarı", key: "stockQty", width: 12 },
      { header: "Kritik Eşik", key: "criticalThreshold", width: 12 },
      { header: "Yeniden Sipariş", key: "reorderPoint", width: 15 },
      { header: "Sipariş Miktarı", key: "reorderQuantity", width: 15 },
      { header: "Aktif", key: "isActive", width: 10 },
      { header: "Son Stok Girişi", key: "lastRestockedAt", width: 15 },
      { header: "Kayıt Tarihi", key: "createdAt", width: 15 },
    ];
    inventoryItems.forEach((i) => {
      inventorySheet.addRow({
        sku: i.sku || "",
        name: i.name,
        category: i.category,
        unit: i.unit || "",
        unitPrice: Number(i.unitPrice),
        stockQty: i.stockQty,
        criticalThreshold: i.criticalThreshold,
        reorderPoint: i.reorderPoint || 0,
        reorderQuantity: i.reorderQuantity || 0,
        isActive: i.isActive ? "Evet" : "Hayır",
        lastRestockedAt: formatDate(i.lastRestockedAt),
        createdAt: formatDate(i.createdAt),
      });
    });
    styleHeaderRow(inventorySheet);

    // 7. Invoices Sheet
    const invoicesSheet = workbook.addWorksheet("Faturalar");
    invoicesSheet.columns = [
      { header: "Fatura No", key: "invoiceNumber", width: 15 },
      { header: "Müşteri", key: "customerName", width: 25 },
      { header: "Telefon", key: "customerPhone", width: 15 },
      { header: "Adres", key: "customerAddress", width: 40 },
      { header: "İş Başlığı", key: "jobTitle", width: 30 },
      { header: "İş Tarihi", key: "jobDate", width: 15 },
      { header: "Ara Toplam", key: "subtotal", width: 12 },
      { header: "KDV", key: "tax", width: 12 },
      { header: "Toplam", key: "total", width: 12 },
      { header: "Taslak", key: "isDraft", width: 10 },
      { header: "Oluşturulma", key: "createdAt", width: 15 },
    ];
    invoices.forEach((inv) => {
      invoicesSheet.addRow({
        invoiceNumber: inv.invoiceNumber,
        customerName: inv.customerName,
        customerPhone: inv.customerPhone,
        customerAddress: inv.customerAddress,
        jobTitle: inv.jobTitle,
        jobDate: formatDate(inv.jobDate),
        subtotal: Number(inv.subtotal),
        tax: inv.tax ? Number(inv.tax) : 0,
        total: Number(inv.total),
        isDraft: inv.isDraft ? "Evet" : "Hayır",
        createdAt: formatDate(inv.createdAt),
      });
    });
    styleHeaderRow(invoicesSheet);

    // Generate file
    const buffer = await workbook.xlsx.writeBuffer();
    const bufferData = Buffer.from(buffer);

    // Set response headers for file download
    const fileName = `SuAritma_Export_${new Date().toISOString().split("T")[0]}.xlsx`;
    res.setHeader("Content-Type", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
    res.setHeader("Content-Disposition", `attachment; filename="${fileName}"`);
    res.setHeader("Content-Length", bufferData.byteLength);

    res.send(bufferData);
    console.log(`✅ Exported data for admin ${adminId} (${personnel.length} personnel, ${customers.length} customers, ${jobs.length} jobs)`);
  } catch (error) {
    next(error as Error);
  }
};

// Helper function to style header row
function styleHeaderRow(sheet: ExcelJS.Worksheet) {
  const headerRow = sheet.getRow(1);
  headerRow.font = { bold: true, color: { argb: "FFFFFFFF" } };
  headerRow.fill = {
    type: "pattern",
    pattern: "solid",
    fgColor: { argb: "FF2563EB" },
  };
  headerRow.alignment = { vertical: "middle", horizontal: "center" };
  headerRow.height = 25;

  // Add borders to all cells
  sheet.eachRow((row, rowNumber) => {
    row.eachCell((cell) => {
      cell.border = {
        top: { style: "thin" },
        left: { style: "thin" },
        bottom: { style: "thin" },
        right: { style: "thin" },
      };
    });
  });
}
