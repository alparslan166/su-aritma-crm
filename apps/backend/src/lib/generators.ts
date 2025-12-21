const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const PERSONNEL_ID_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";

export const generateLoginCode = (length = 6) => {
  let code = "";
  for (let i = 0; i < length; i += 1) {
    const index = Math.floor(Math.random() * CODE_ALPHABET.length);
    code += CODE_ALPHABET[index];
  }
  return code;
};

export const generatePersonnelId = async (adminId: string, length = 6): Promise<string> => {
  const { prisma } = await import("./prisma");
  let attempts = 0;
  const maxAttempts = 100;

  while (attempts < maxAttempts) {
    let id = "";
    for (let i = 0; i < length; i += 1) {
      const index = Math.floor(Math.random() * PERSONNEL_ID_ALPHABET.length);
      id += PERSONNEL_ID_ALPHABET[index];
    }

    // Check if this ID already exists for this admin
    const existing = await prisma.personnel.findFirst({
      where: {
        adminId,
        personnelId: id,
      },
    });

    if (!existing) {
      return id;
    }

    attempts += 1;
  }

  throw new Error("Failed to generate unique personnel ID after multiple attempts");
};

const ADMIN_ID_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // Excluding confusing chars (0, O, I, 1)

export const generateAdminId = async (length = 8): Promise<string> => {
  try {
    const { prisma } = await import("./prisma");
    let attempts = 0;
    const maxAttempts = 100;

    while (attempts < maxAttempts) {
      let id = "";
      for (let i = 0; i < length; i += 1) {
        const index = Math.floor(Math.random() * ADMIN_ID_ALPHABET.length);
        id += ADMIN_ID_ALPHABET[index];
      }

      // Check if this ID already exists
      // Use findFirst since adminId might not be in WhereUniqueInput yet
      const existing = await prisma.admin.findFirst({
        where: {
          adminId: id,
        },
      });

      if (!existing) {
        console.log(`✅ Generated unique adminId: ${id} (attempt ${attempts + 1})`);
        return id;
      }

      attempts += 1;
    }

    throw new Error(`Failed to generate unique admin ID after ${maxAttempts} attempts`);
  } catch (error) {
    console.error("❌ generateAdminId error:", error);
    throw error;
  }
};
