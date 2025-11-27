/// <reference types="node" />
import "dotenv/config";
import { defineConfig } from "@prisma/config";

const databaseUrl = process.env.DATABASE_URL;
const directUrl = process.env.DIRECT_URL;

if (!databaseUrl) {
  throw new Error(
    "DATABASE_URL environment variable is not set. Please create a .env file with DATABASE_URL.",
  );
}

// Only use shadowDatabaseUrl if it's different from the main database URL
// Prisma requires shadow database to be different from main database for migrations
const shadowDatabaseUrl = directUrl && directUrl !== databaseUrl ? directUrl : undefined;

export default defineConfig({
  schema: "./prisma/schema.prisma",
  datasource: {
    url: databaseUrl,
    ...(shadowDatabaseUrl && { shadowDatabaseUrl }),
  },
});
