import dotenv from "dotenv";
import { z } from "zod";

dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  // Railway otomatik olarak PORT environment variable'ını set eder
  PORT: z.coerce.number().default(4000),
  // Railway PostgreSQL servisi DATABASE_URL'i otomatik set eder
  DATABASE_URL: z
    .string()
    .min(1, "DATABASE_URL is required")
    .default("postgresql://postgres:postgres@localhost:5432/su_aritma?schema=public"),
  AWS_REGION: z.string().default("eu-north-1"),
  AWS_ACCESS_KEY_ID: z.string().default("local"),
  AWS_SECRET_ACCESS_KEY: z.string().default("local"),
  S3_MEDIA_BUCKET: z.string().default("local-bucket"),
  FCM_SERVER_KEY: z.string().default("local"),
  REDIS_URL: z.string().optional(),
  MAINTENANCE_CRON: z.string().optional(),
  // CORS origin - production'da belirli domain'ler, development'ta *
  ALLOWED_ORIGINS: z.string().optional(),
  // Email service (opsiyonel)
  RESEND_API_KEY: z.string().optional(),
  EMAIL_FROM: z.string().optional(),
});

const env = envSchema.parse({
  NODE_ENV: process.env.NODE_ENV,
  PORT: process.env.PORT,
  DATABASE_URL: process.env.DATABASE_URL,
  AWS_REGION: "eu-north-1", // Force eu-north-1 regardless of process.env
  AWS_ACCESS_KEY_ID: process.env.AWS_ACCESS_KEY_ID,
  AWS_SECRET_ACCESS_KEY: process.env.AWS_SECRET_ACCESS_KEY,
  S3_MEDIA_BUCKET: process.env.S3_MEDIA_BUCKET,
  FCM_SERVER_KEY: process.env.FCM_SERVER_KEY,
  REDIS_URL: process.env.REDIS_URL,
  MAINTENANCE_CRON: process.env.MAINTENANCE_CRON,
  ALLOWED_ORIGINS: process.env.ALLOWED_ORIGINS,
});

// Production'da DATABASE_URL kontrolü
if (env.NODE_ENV === "production" && env.DATABASE_URL.includes("localhost")) {
  throw new Error(
    "DATABASE_URL cannot point to localhost in production. Please set a valid production database URL.",
  );
}

export const config = {
  nodeEnv: env.NODE_ENV,
  port: env.PORT,
  databaseUrl: env.DATABASE_URL,
  aws: {
    region: env.AWS_REGION,
    accessKeyId: env.AWS_ACCESS_KEY_ID,
    secretAccessKey: env.AWS_SECRET_ACCESS_KEY,
    mediaBucket: env.S3_MEDIA_BUCKET,
  },
  fcm: {
    serverKey: env.FCM_SERVER_KEY,
  },
  redis: {
    url: env.REDIS_URL,
  },
  maintenance: {
    cron: env.MAINTENANCE_CRON ?? "0 * * * *",
  },
  cors: {
    // Production'da ALLOWED_ORIGINS varsa kullan, yoksa * (mobile app için gerekli)
    origin: env.ALLOWED_ORIGINS ? env.ALLOWED_ORIGINS.split(",") : "*",
  },
};
