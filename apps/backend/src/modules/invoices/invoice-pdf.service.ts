import PDFDocument from "pdfkit";
import { Readable } from "stream";
import { Prisma } from "@prisma/client";

type InvoiceData = {
  invoiceNumber: string;
  customerName: string;
  customerPhone: string;
  customerAddress: string;
  customerEmail?: string | null;
  jobTitle: string;
  jobDate: Date;
  subtotal: number;
  tax?: number | null;
  total: number;
  notes?: string | null;
  materials?: Array<{
    name: string;
    quantity: number;
    unitPrice: number;
    total: number;
  }>;
  createdAt: Date;
};

export class InvoicePdfService {
  generatePdf(invoiceData: InvoiceData): Readable {
    const doc = new PDFDocument({
      size: "A4",
      margins: {
        top: 50,
        bottom: 50,
        left: 50,
        right: 50,
      },
    });

    // Header
    doc
      .fontSize(24)
      .font("Helvetica-Bold")
      .fillColor("#1a1a1a")
      .text("FATURA", 50, 50, { align: "center" });

    // Invoice number and date
    doc
      .fontSize(10)
      .font("Helvetica")
      .fillColor("#666666")
      .text(`Fatura No: ${invoiceData.invoiceNumber}`, 50, 90, { align: "left" })
      .text(
        `Tarih: ${new Date(invoiceData.createdAt).toLocaleDateString("tr-TR", {
          year: "numeric",
          month: "long",
          day: "numeric",
        })}`,
        50,
        105,
        { align: "left" }
      );

    // Company info (right side)
    const companyInfoY = 90;
    doc
      .fontSize(10)
      .font("Helvetica-Bold")
      .fillColor("#1a1a1a")
      .text("Firma Bilgileri", 350, companyInfoY, { align: "right", width: 200 });

    doc
      .fontSize(9)
      .font("Helvetica")
      .fillColor("#333333")
      .text("Su Arıtma Hizmetleri", 350, companyInfoY + 15, { align: "right", width: 200 })
      .text("İstanbul, Türkiye", 350, companyInfoY + 28, { align: "right", width: 200 });

    // Customer info section
    const customerY = 150;
    doc
      .fontSize(12)
      .font("Helvetica-Bold")
      .fillColor("#1a1a1a")
      .text("Müşteri Bilgileri", 50, customerY);

    doc
      .fontSize(10)
      .font("Helvetica")
      .fillColor("#333333")
      .text(`İsim: ${invoiceData.customerName}`, 50, customerY + 20)
      .text(`Telefon: ${invoiceData.customerPhone}`, 50, customerY + 35)
      .text(`Adres: ${invoiceData.customerAddress}`, 50, customerY + 50, {
        width: 250,
      });

    if (invoiceData.customerEmail) {
      doc.text(`E-posta: ${invoiceData.customerEmail}`, 50, customerY + 65);
    }

    // Job info section
    const jobY = customerY + (invoiceData.customerEmail ? 85 : 70);
    doc
      .fontSize(12)
      .font("Helvetica-Bold")
      .fillColor("#1a1a1a")
      .text("İş Bilgileri", 50, jobY);

    doc
      .fontSize(10)
      .font("Helvetica")
      .fillColor("#333333")
      .text(`İş Başlığı: ${invoiceData.jobTitle}`, 50, jobY + 20)
      .text(
        `İş Tarihi: ${new Date(invoiceData.jobDate).toLocaleDateString("tr-TR", {
          year: "numeric",
          month: "long",
          day: "numeric",
        })}`,
        50,
        jobY + 35
      );

    // Materials table
    let tableY = jobY + 60;
    if (invoiceData.materials && invoiceData.materials.length > 0) {
      doc
        .fontSize(12)
        .font("Helvetica-Bold")
        .fillColor("#1a1a1a")
        .text("Kullanılan Malzemeler", 50, tableY);

      tableY += 20;

      // Table header
      doc
        .fontSize(9)
        .font("Helvetica-Bold")
        .fillColor("#ffffff")
        .rect(50, tableY, 495, 20)
        .fill("#2563EB")
        .text("Malzeme Adı", 55, tableY + 5)
        .text("Miktar", 300, tableY + 5)
        .text("Birim Fiyat", 370, tableY + 5)
        .text("Toplam", 450, tableY + 5);

      tableY += 25;

      // Table rows
      doc.font("Helvetica").fillColor("#333333");
      for (const material of invoiceData.materials) {
        if (tableY > 700) {
          doc.addPage();
          tableY = 50;
        }

        doc
          .rect(50, tableY, 495, 20)
          .stroke("#e5e7eb")
          .text(material.name, 55, tableY + 5, { width: 240 })
          .text(material.quantity.toString(), 300, tableY + 5, { width: 65 })
          .text(`${material.unitPrice.toFixed(2)} ₺`, 370, tableY + 5, { width: 75 })
          .text(`${material.total.toFixed(2)} ₺`, 450, tableY + 5, { width: 90 });

        tableY += 25;
      }
    }

    // Totals section
    const totalsY = tableY + 20;
    doc
      .fontSize(10)
      .font("Helvetica")
      .fillColor("#333333")
      .text("Ara Toplam:", 350, totalsY, { width: 100, align: "right" })
      .text(`${invoiceData.subtotal.toFixed(2)} ₺`, 450, totalsY, { width: 95, align: "right" });

    if (invoiceData.tax && invoiceData.tax > 0) {
      doc
        .text("KDV:", 350, totalsY + 15, { width: 100, align: "right" })
        .text(`${invoiceData.tax.toFixed(2)} ₺`, 450, totalsY + 15, { width: 95, align: "right" });
    }

    doc
      .fontSize(12)
      .font("Helvetica-Bold")
      .fillColor("#1a1a1a")
      .text("TOPLAM:", 350, totalsY + (invoiceData.tax && invoiceData.tax > 0 ? 35 : 20), {
        width: 100,
        align: "right",
      })
      .text(
        `${invoiceData.total.toFixed(2)} ₺`,
        450,
        totalsY + (invoiceData.tax && invoiceData.tax > 0 ? 35 : 20),
        { width: 95, align: "right" }
      );

    // Notes section
    if (invoiceData.notes) {
      const notesY = totalsY + (invoiceData.tax && invoiceData.tax > 0 ? 60 : 45);
      doc
        .fontSize(10)
        .font("Helvetica-Bold")
        .fillColor("#1a1a1a")
        .text("Notlar:", 50, notesY);

      doc
        .fontSize(9)
        .font("Helvetica")
        .fillColor("#666666")
        .text(invoiceData.notes, 50, notesY + 15, {
          width: 495,
          align: "left",
        });
    }

    // Footer
    const pageHeight = doc.page.height;
    const footerY = pageHeight - 80;
    doc
      .fontSize(8)
      .font("Helvetica")
      .fillColor("#999999")
      .text(
        "Bu fatura elektronik ortamda oluşturulmuştur.",
        50,
        footerY,
        { align: "center", width: 495 }
      )
      .text(
        `Oluşturulma Tarihi: ${new Date().toLocaleDateString("tr-TR", {
          year: "numeric",
          month: "long",
          day: "numeric",
          hour: "2-digit",
          minute: "2-digit",
        })}`,
        50,
        footerY + 15,
        { align: "center", width: 495 }
      );

    doc.end();

    return doc as unknown as Readable;
  }
}

export const invoicePdfService = new InvoicePdfService();

