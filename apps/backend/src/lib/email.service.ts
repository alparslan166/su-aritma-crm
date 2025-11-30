import nodemailer from "nodemailer";

// E-posta gönderimi için transporter
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || "smtp.gmail.com",
  port: parseInt(process.env.SMTP_PORT || "587", 10),
  secure: process.env.SMTP_SECURE === "true",
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

const FROM_EMAIL = process.env.SMTP_FROM || "noreply@suaritma.com";
const APP_NAME = "Su Arıtma Platformu";

// 6 haneli doğrulama kodu oluştur
export const generateVerificationCode = (): string => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

// E-posta doğrulama kodu gönder
export const sendVerificationEmail = async (
  email: string,
  code: string,
  name: string,
): Promise<boolean> => {
  try {
    await transporter.sendMail({
      from: `"${APP_NAME}" <${FROM_EMAIL}>`,
      to: email,
      subject: `${APP_NAME} - E-posta Doğrulama Kodu`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="text-align: center; margin-bottom: 30px;">
            <h1 style="color: #2563EB; margin: 0;">${APP_NAME}</h1>
          </div>
          
          <div style="background-color: #f8fafc; border-radius: 8px; padding: 30px; text-align: center;">
            <h2 style="color: #1f2937; margin-bottom: 10px;">Merhaba ${name},</h2>
            <p style="color: #6b7280; margin-bottom: 20px;">
              Hesabınızı doğrulamak için aşağıdaki kodu kullanın:
            </p>
            
            <div style="background-color: #2563EB; color: white; font-size: 32px; font-weight: bold; 
                        letter-spacing: 8px; padding: 20px 40px; border-radius: 8px; display: inline-block;">
              ${code}
            </div>
            
            <p style="color: #6b7280; margin-top: 20px; font-size: 14px;">
              Bu kod 10 dakika içinde geçerliliğini yitirecektir.
            </p>
          </div>
          
          <div style="margin-top: 30px; text-align: center; color: #9ca3af; font-size: 12px;">
            <p>Bu e-postayı siz talep etmediyseniz, lütfen dikkate almayın.</p>
            <p>&copy; ${new Date().getFullYear()} ${APP_NAME}</p>
          </div>
        </div>
      `,
    });
    console.log(`✅ Verification email sent to ${email}`);
    return true;
  } catch (error) {
    console.error(`❌ Failed to send verification email to ${email}:`, error);
    return false;
  }
};

// Şifre sıfırlama kodu gönder
export const sendPasswordResetEmail = async (
  email: string,
  code: string,
  name: string,
): Promise<boolean> => {
  try {
    await transporter.sendMail({
      from: `"${APP_NAME}" <${FROM_EMAIL}>`,
      to: email,
      subject: `${APP_NAME} - Şifre Sıfırlama Kodu`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="text-align: center; margin-bottom: 30px;">
            <h1 style="color: #2563EB; margin: 0;">${APP_NAME}</h1>
          </div>
          
          <div style="background-color: #f8fafc; border-radius: 8px; padding: 30px; text-align: center;">
            <h2 style="color: #1f2937; margin-bottom: 10px;">Merhaba ${name},</h2>
            <p style="color: #6b7280; margin-bottom: 20px;">
              Şifrenizi sıfırlamak için aşağıdaki kodu kullanın:
            </p>
            
            <div style="background-color: #DC2626; color: white; font-size: 32px; font-weight: bold; 
                        letter-spacing: 8px; padding: 20px 40px; border-radius: 8px; display: inline-block;">
              ${code}
            </div>
            
            <p style="color: #6b7280; margin-top: 20px; font-size: 14px;">
              Bu kod 10 dakika içinde geçerliliğini yitirecektir.
            </p>
            
            <p style="color: #ef4444; margin-top: 15px; font-size: 14px;">
              ⚠️ Bu talebi siz yapmadıysanız, hesabınız risk altında olabilir. 
              Lütfen şifrenizi değiştirin.
            </p>
          </div>
          
          <div style="margin-top: 30px; text-align: center; color: #9ca3af; font-size: 12px;">
            <p>Bu e-postayı siz talep etmediyseniz, lütfen dikkate almayın.</p>
            <p>&copy; ${new Date().getFullYear()} ${APP_NAME}</p>
          </div>
        </div>
      `,
    });
    console.log(`✅ Password reset email sent to ${email}`);
    return true;
  } catch (error) {
    console.error(`❌ Failed to send password reset email to ${email}:`, error);
    return false;
  }
};

// E-posta servisinin çalışıp çalışmadığını kontrol et
export const verifyEmailService = async (): Promise<boolean> => {
  try {
    await transporter.verify();
    console.log("✅ Email service is ready");
    return true;
  } catch (error) {
    console.warn("⚠️ Email service not configured:", error);
    return false;
  }
};

