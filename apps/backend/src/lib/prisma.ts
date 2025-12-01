import { PrismaClient } from "@prisma/client";

const client = new PrismaClient({
  log: process.env.NODE_ENV === "development" ? ["query", "error", "warn"] : ["error"],
});

export const prisma = client;
