import { Resend } from "resend";

// Resend API client - sadece API key varsa initialize et
let resend: Resend | null = null;
if (process.env.RESEND_API_KEY) {
  try {
    resend = new Resend(process.env.RESEND_API_KEY);
    console.log("✅ Resend email service initialized");
  } catch (error) {
    console.warn("⚠️ Failed to initialize Resend:", error);
  }
} else {
  console.warn("⚠️ RESEND_API_KEY not set. Email service is disabled.");
}

const FROM_EMAIL = process.env.EMAIL_FROM || "onboarding@resend.dev";
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
): Promise<{ success: boolean; error?: string }> => {
  if (!resend) {
    console.warn("⚠️ Email service not available. RESEND_API_KEY not set.");
    return {
      success: false,
      error: "EMAIL_SERVICE_NOT_CONFIGURED",
    };
  }

  try {
    const { error, data } = await resend.emails.send({
      from: `${APP_NAME} <${FROM_EMAIL}>`,
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

    if (error) {
      console.error(`❌ Failed to send verification email to ${email}:`, error);

      // Check if it's a domain verification error
      const errorMessage = error.message || JSON.stringify(error);
      if (errorMessage.includes("verify a domain") || errorMessage.includes("testing emails")) {
        return {
          success: false,
          error: "EMAIL_DOMAIN_NOT_VERIFIED",
        };
      }

      return {
        success: false,
        error: errorMessage,
      };
    }

    console.log(`✅ Verification email sent to ${email}`, data?.id ? `(ID: ${data.id})` : "");
    return { success: true };
  } catch (error: unknown) {
    console.error(`❌ Failed to send verification email to ${email}:`, error);
    return {
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
    };
  }
};

// Şifre sıfırlama kodu gönder
export const sendPasswordResetEmail = async (
  email: string,
  code: string,
  name: string,
): Promise<{ success: boolean; error?: string }> => {
  if (!resend) {
    console.warn("⚠️ Email service not available. RESEND_API_KEY not set.");
    return {
      success: false,
      error: "EMAIL_SERVICE_NOT_CONFIGURED",
    };
  }

  try {
    const { error, data } = await resend.emails.send({
      from: `${APP_NAME} <${FROM_EMAIL}>`,
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

    if (error) {
      console.error(`❌ Failed to send password reset email to ${email}:`, error);
      const errorMessage = error.message || JSON.stringify(error);
      if (errorMessage.includes("verify a domain") || errorMessage.includes("testing emails")) {
        return {
          success: false,
          error: "EMAIL_DOMAIN_NOT_VERIFIED",
        };
      }
      return {
        success: false,
        error: errorMessage,
      };
    }

    console.log(`✅ Password reset email sent to ${email}`, data?.id ? `(ID: ${data.id})` : "");
    return { success: true };
  } catch (error: unknown) {
    console.error(`❌ Failed to send password reset email to ${email}:`, error);
    return {
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
    };
  }
};

// Hesap silme doğrulama kodu gönder
export const sendAccountDeletionEmail = async (
  email: string,
  code: string,
  name: string,
): Promise<{ success: boolean; error?: string }> => {
  if (!resend) {
    console.warn("⚠️ Email service not available. RESEND_API_KEY not set.");
    return {
      success: false,
      error: "EMAIL_SERVICE_NOT_CONFIGURED",
    };
  }

  try {
    const { error, data } = await resend.emails.send({
      from: `${APP_NAME} <${FROM_EMAIL}>`,
      to: email,
      subject: `${APP_NAME} - Hesap Silme Onayı`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="text-align: center; margin-bottom: 30px;">
            <h1 style="color: #DC2626; margin: 0;">${APP_NAME}</h1>
          </div>
          
          <div style="background-color: #fef2f2; border-radius: 8px; padding: 30px; text-align: center; border: 2px solid #fecaca;">
            <h2 style="color: #991b1b; margin-bottom: 10px;">⚠️ Hesap Silme Talebi</h2>
            <p style="color: #7f1d1d; margin-bottom: 20px;">
              Merhaba ${name}, hesabınızı silmek için aşağıdaki kodu kullanın:
            </p>
            
            <div style="background-color: #DC2626; color: white; font-size: 32px; font-weight: bold; 
                        letter-spacing: 8px; padding: 20px 40px; border-radius: 8px; display: inline-block;">
              ${code}
            </div>
            
            <p style="color: #7f1d1d; margin-top: 20px; font-size: 14px;">
              Bu kod 10 dakika içinde geçerliliğini yitirecektir.
            </p>
            
            <div style="background-color: #fee2e2; padding: 15px; border-radius: 8px; margin-top: 20px;">
              <p style="color: #991b1b; margin: 0; font-weight: bold;">
                ⚠️ DİKKAT: Bu işlem geri alınamaz!
              </p>
              <p style="color: #7f1d1d; margin: 10px 0 0 0; font-size: 13px;">
                Hesabınız silindiğinde tüm verileriniz (personeller, müşteriler, işler, faturalar) 
                kalıcı olarak silinecektir.
              </p>
            </div>
          </div>
          
          <div style="margin-top: 30px; text-align: center; color: #9ca3af; font-size: 12px;">
            <p>Bu talebi siz yapmadıysanız, bu e-postayı dikkate almayın ve şifrenizi değiştirin.</p>
            <p>&copy; ${new Date().getFullYear()} ${APP_NAME}</p>
          </div>
        </div>
      `,
    });

    if (error) {
      console.error(`❌ Failed to send account deletion email to ${email}:`, error);
      const errorMessage = error.message || JSON.stringify(error);
      if (errorMessage.includes("verify a domain") || errorMessage.includes("testing emails")) {
        return {
          success: false,
          error: "EMAIL_DOMAIN_NOT_VERIFIED",
        };
      }
      return {
        success: false,
        error: errorMessage,
      };
    }

    console.log(`✅ Account deletion email sent to ${email}`, data?.id ? `(ID: ${data.id})` : "");
    return { success: true };
  } catch (error: unknown) {
    console.error(`❌ Failed to send account deletion email to ${email}:`, error);
    return {
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
    };
  }
};

// E-posta servisinin çalışıp çalışmadığını kontrol et
export const verifyEmailService = async (): Promise<boolean> => {
  if (!process.env.RESEND_API_KEY) {
    console.warn("⚠️ RESEND_API_KEY is not set. Email service is disabled.");
    return false;
  }
  console.log("✅ Email service (Resend) is configured");
  return true;
};
