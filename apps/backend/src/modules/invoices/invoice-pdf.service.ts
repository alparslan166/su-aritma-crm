import * as fs from "fs";
import * as path from "path";
import PDFDocument from "pdfkit";
import { Readable } from "stream";

type MaterialItem = {
  name: string;
  quantity: number;
  unitPrice: number;
  total: number;
};

type PersonnelInfo = {
  name: string;
  phone: string;
  email?: string | null;
};

type InvoiceData = {
  invoiceNumber: string;
  invoiceDate: Date;
  customerName: string;
  customerPhone: string;
  customerAddress: string;
  customerEmail?: string | null;
  jobTitle: string;
  jobDate: Date;
  subtotal: number;
  tax: number;
  total: number;
  notes?: string | null;
  materials?: MaterialItem[];
  personnel?: PersonnelInfo[];
  collectedAmount?: number | null;
  companyName: string;
  companyAddress: string;
  companyPhone: string;
  companyEmail: string;
  taxOffice: string;
  taxNumber: string;
  logoUrl?: string | null;
};

const money = (v: number) =>
  new Intl.NumberFormat("tr-TR", {
    style: "currency",
    currency: "TRY",
  }).format(v);

export class InvoicePdfService {
  private getFontPath(filename: string): string {
    // Try multiple possible paths for the font file
    // In development: src/assets/fonts/
    // In production (compiled): dist/assets/fonts/ or __dirname relative
    const possiblePaths = [
      // Production paths (compiled JS location) - __dirname points to dist/modules/invoices/
      path.join(__dirname, "../../assets/fonts", filename),
      path.join(__dirname, "../../../assets/fonts", filename),
      path.join(__dirname, "../../../../assets/fonts", filename),
      // Development paths
      path.join(process.cwd(), "src/assets/fonts", filename),
      path.join(process.cwd(), "apps/backend/src/assets/fonts", filename),
      // Production build paths (from process.cwd())
      path.join(process.cwd(), "assets/fonts", filename),
      path.join(process.cwd(), "dist/assets/fonts", filename),
      path.join(process.cwd(), "apps/backend/dist/assets/fonts", filename),
      // Railway/production paths
      path.join("/app", "dist", "assets", "fonts", filename),
      path.join("/app", "apps", "backend", "dist", "assets", "fonts", filename),
    ];

    console.log(`🔍 Searching for font: ${filename}`);
    console.log(`   __dirname: ${__dirname}`);
    console.log(`   process.cwd(): ${process.cwd()}`);

    for (const fontPath of possiblePaths) {
      if (fs.existsSync(fontPath)) {
        console.log(`✅ Font found: ${fontPath}`);
        return fontPath;
      }
    }

    // If font file not found, return empty string (will fallback to Helvetica)
    console.warn(`⚠️ Font file not found: ${filename}, using default Helvetica`);
    console.warn(`   Searched ${possiblePaths.length} paths`);
    return "";
  }

  generatePdf(data: InvoiceData): Readable {
    const doc = new PDFDocument({
      size: "A4",
      margins: { top: 40, bottom: 40, left: 50, right: 50 },
      autoFirstPage: true,
    });

    // Register NotoSans fonts for Turkish character support
    const notoSansRegular = this.getFontPath("NotoSans-Regular.ttf");
    const notoSansBold = this.getFontPath("NotoSans-Bold.ttf");

    let fontRegular = "Helvetica";
    let fontBold = "Helvetica-Bold";

    // Try to register and use NotoSans fonts
    // Check if file exists and is a valid TTF file (not HTML/text)
    if (notoSansRegular && notoSansRegular.length > 0 && fs.existsSync(notoSansRegular)) {
      try {
        // Check if file is actually a TTF (starts with TTF magic bytes)
        const fontBuffer = fs.readFileSync(notoSansRegular);
        const isTTF =
          (fontBuffer.length > 4 &&
            fontBuffer[0] === 0x00 &&
            fontBuffer[1] === 0x01 &&
            fontBuffer[2] === 0x00 &&
            fontBuffer[3] === 0x00) ||
          (fontBuffer[0] === 0x4f &&
            fontBuffer[1] === 0x54 &&
            fontBuffer[2] === 0x54 &&
            fontBuffer[3] === 0x4f); // OTTO for OTF

        if (!isTTF) {
          console.warn(
            `⚠️ Font file ${notoSansRegular} is not a valid TTF/OTF file, using Helvetica`,
          );
        } else {
          doc.registerFont("NotoSans", notoSansRegular);
          fontRegular = "NotoSans";
          console.log(`✅ Registered NotoSans font from: ${notoSansRegular}`);
        }
      } catch (error) {
        console.warn(`⚠️ Failed to register NotoSans font: ${error}`);
        console.warn(`   Error details: ${error instanceof Error ? error.message : String(error)}`);
      }
    } else {
      console.warn(
        `⚠️ NotoSans-Regular.ttf not found, using Helvetica (Turkish characters may not display correctly)`,
      );
    }

    if (notoSansBold && notoSansBold.length > 0 && fs.existsSync(notoSansBold)) {
      try {
        // Check if file is actually a TTF (starts with TTF magic bytes)
        const fontBuffer = fs.readFileSync(notoSansBold);
        const isTTF =
          (fontBuffer.length > 4 &&
            fontBuffer[0] === 0x00 &&
            fontBuffer[1] === 0x01 &&
            fontBuffer[2] === 0x00 &&
            fontBuffer[3] === 0x00) ||
          (fontBuffer[0] === 0x4f &&
            fontBuffer[1] === 0x54 &&
            fontBuffer[2] === 0x54 &&
            fontBuffer[3] === 0x4f); // OTTO for OTF

        if (!isTTF) {
          console.warn(
            `⚠️ Font file ${notoSansBold} is not a valid TTF/OTF file, using Helvetica-Bold`,
          );
        } else {
          doc.registerFont("NotoSans-Bold", notoSansBold);
          fontBold = "NotoSans-Bold";
          console.log(`✅ Registered NotoSans-Bold font from: ${notoSansBold}`);
        }
      } catch (error) {
        console.warn(`⚠️ Failed to register NotoSans-Bold font: ${error}`);
        console.warn(`   Error details: ${error instanceof Error ? error.message : String(error)}`);
      }
    } else {
      console.warn(
        `⚠️ NotoSans-Bold.ttf not found, using Helvetica-Bold (Turkish characters may not display correctly)`,
      );
    }

    // Colors
    const primary = "#1E3A8A"; // mavi-gri kurumsal
    const lightGray = "#E5E7EB";
    const textDark = "#1F2937";

    // Header Bar Background
    doc.rect(0, 0, doc.page.width, 90).fill(primary);

    // Logo - S3 URL'ler için şimdilik desteklenmiyor (async gerektirir)
    // Logo yükleme özelliği ileride eklenebilir
    // if (data.logoUrl && !data.logoUrl.startsWith("http")) {
    //   try {
    //     doc.image(data.logoUrl, 50, 20, { width: 80 });
    //   } catch (err) {
    //     console.warn("Logo yüklenemedi:", err);
    //   }
    // }

    // Header text
    doc.fillColor("#ffffff").font(fontBold).fontSize(28).text("FATURA", 0, 35, { align: "center" });

    // Invoice Info Box
    const boxY = 110;
    doc.roundedRect(50, boxY, 500, 85, 8).fillOpacity(0.05).fill(primary).fillOpacity(1);

    doc
      .fillColor(textDark)
      .fontSize(12)
      .font(fontBold)
      .text("Fatura Bilgileri", 60, boxY + 10);

    doc
      .font(fontRegular)
      .fontSize(10)
      .fillColor("#555")
      .text(`Fatura No: ${data.invoiceNumber}`, 60, boxY + 35)
      .text(`Fatura Tarihi: ${data.invoiceDate.toLocaleDateString("tr-TR")}`, 60, boxY + 50);

    doc
      .font(fontRegular)
      .fontSize(10)
      .fillColor("#555")
      .text(`Vergi Dairesi: ${data.taxOffice}`, 300, boxY + 35)
      .text(`Vergi No: ${data.taxNumber}`, 300, boxY + 50);

    // Customer Box
    const custY = boxY + 110;
    doc.roundedRect(50, custY, 500, 110, 8).fillOpacity(0.07).fill(primary).fillOpacity(1);

    doc
      .fillColor(textDark)
      .font(fontBold)
      .fontSize(12)
      .text("Müşteri Bilgileri", 60, custY + 10);

    doc
      .font(fontRegular)
      .fontSize(10)
      .fillColor("#333")
      .text(`İsim: ${data.customerName}`, 60, custY + 35)
      .text(`Telefon: ${data.customerPhone}`, 60, custY + 50)
      .text(`Adres: ${data.customerAddress}`, 60, custY + 65, { width: 240 });

    if (data.customerEmail) {
      doc.text(`E-posta: ${data.customerEmail}`, 60, custY + 85);
    }

    // Company Box (right aligned)
    doc
      .font(fontBold)
      .fontSize(12)
      .fillColor(textDark)
      .text("Firma Bilgileri", 320, custY + 10);

    doc
      .font(fontRegular)
      .fontSize(10)
      .fillColor("#333")
      .text(data.companyName, 320, custY + 35)
      .text(data.companyAddress, 320, custY + 50, { width: 210 })
      .text(`Tel: ${data.companyPhone}`, 320, custY + 80)
      .text(`E-posta: ${data.companyEmail}`, 320, custY + 95);

    // Job Info
    const jobY = custY + 140;
    doc.font(fontBold).fontSize(12).fillColor(textDark).text("Hizmet Bilgileri", 50, jobY);

    let currentY = jobY + 20;
    doc
      .font(fontRegular)
      .fontSize(10)
      .fillColor("#444")
      .text(`Hizmet: ${data.jobTitle}`, 50, currentY)
      .text(`Tarih: ${data.jobDate.toLocaleDateString("tr-TR")}`, 50, currentY + 15);

    currentY += 30;

    // Personnel Info (Personel Bilgileri)
    if (data.personnel && data.personnel.length > 0) {
      doc.font(fontBold).fontSize(12).fillColor(textDark).text("Personel Bilgileri", 50, currentY);
      currentY += 20;

      doc.font(fontRegular).fontSize(10).fillColor("#444");

      for (const person of data.personnel) {
        doc.text(`Personel: ${person.name}`, 50, currentY);
        doc.text(`Telefon: ${person.phone}`, 50, currentY + 15);
        if (person.email) {
          doc.text(`E-posta: ${person.email}`, 50, currentY + 30);
          currentY += 45;
        } else {
          currentY += 30;
        }
      }
    }

    // Collected Amount (Alınan Ücret)
    if (data.collectedAmount !== null && data.collectedAmount !== undefined) {
      doc
        .font(fontBold)
        .fontSize(12)
        .fillColor(textDark)
        .text("Alınan Ücret", 50, currentY);
      currentY += 20;

      doc
        .font(fontBold)
        .fontSize(11)
        .fillColor(primary)
        .text(money(data.collectedAmount), 50, currentY);
      currentY += 25;
    }

    // Material Table
    let tableY = currentY + 10;
    if (data.materials && data.materials.length > 0) {
      doc.font(fontBold).fontSize(12).fillColor(textDark).text("Kullanılan Malzemeler", 50, tableY);

      tableY += 20;

      // Header background
      doc.rect(50, tableY, 500, 25).fill(primary).fillColor("#fff");

      doc
        .fontSize(10)
        .font(fontBold)
        .text("Malzeme", 55, tableY + 7)
        .text("Miktar", 280, tableY + 7)
        .text("Birim Fiyat", 350, tableY + 7)
        .text("Toplam", 440, tableY + 7);

      tableY += 30;

      doc.font(fontRegular).fontSize(10).fillColor("#333");

      for (const m of data.materials) {
        if (tableY > 700) {
          doc.addPage();
          tableY = 50;
        }

        doc.rect(50, tableY, 500, 22).strokeColor(lightGray).lineWidth(0.5).stroke();

        doc.text(m.name, 55, tableY + 6, { width: 220 });
        doc.text(m.quantity.toString(), 280, tableY + 6);
        doc.text(money(m.unitPrice), 350, tableY + 6, { width: 80 });
        doc.text(money(m.total), 440, tableY + 6);

        tableY += 25;
      }
    }

    // Totals
    const totalsY = tableY + 20;
    doc
      .font(fontBold)
      .fontSize(11)
      .fillColor(textDark)
      .text("Ara Toplam:", 350, totalsY, { width: 100, align: "right" })
      .font(fontRegular)
      .text(money(data.subtotal), 450, totalsY, { width: 100, align: "right" });

    doc
      .font(fontBold)
      .text("KDV:", 350, totalsY + 15, { width: 100, align: "right" })
      .font(fontRegular)
      .text(money(data.tax), 450, totalsY + 15, { width: 100, align: "right" });

    doc
      .font(fontBold)
      .fontSize(13)
      .fillColor(primary)
      .text("TOPLAM:", 350, totalsY + 40, { width: 100, align: "right" })
      .text(money(data.total), 450, totalsY + 40, {
        width: 100,
        align: "right",
      });

    // Notes
    if (data.notes) {
      doc
        .font(fontBold)
        .fontSize(12)
        .fillColor(textDark)
        .text("Notlar:", 50, totalsY + 80);

      doc
        .font(fontRegular)
        .fontSize(10)
        .fillColor("#444")
        .text(data.notes, 50, totalsY + 100, { width: 500 });
    }

    // Signature area
    const signY = doc.page.height - 180;
    doc.font(fontBold).fontSize(11).fillColor(textDark).text("Yetkili İmza", 350, signY);

    doc
      .moveTo(350, signY + 20)
      .lineTo(520, signY + 20)
      .strokeColor("#888")
      .stroke();

    // Footer Bar
    const footerY = doc.page.height - 50;
    doc.rect(0, footerY, doc.page.width, 50).fill(primary);

    doc
      .fillColor("#ffffff")
      .font(fontRegular)
      .fontSize(9)
      .text(
        `${data.companyName} • ${data.companyPhone} • ${data.companyEmail} • ${data.companyAddress}`,
        0,
        footerY + 18,
        { align: "center" },
      );

    doc.end();

    return doc as unknown as Readable;
  }
}

export const invoicePdfService = new InvoicePdfService();
