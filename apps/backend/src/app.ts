import cors from "cors";
import express from "express";
import helmet from "helmet";
import morgan from "morgan";

import { config } from "@/config/env";
import { errorHandler, notFoundHandler } from "@/middleware/error-handler";
import { apiRouter } from "@/routes";

export const createApp = () => {
  const app = express();

  app.use(
    helmet({
      crossOriginResourcePolicy: { policy: "cross-origin" },
    }),
  );
  app.use(
    cors({
      origin: config.cors.origin,
      credentials: true,
      methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
      allowedHeaders: ["Content-Type", "Authorization", "x-admin-id", "x-personnel-id"],
    }),
  );
  app.use(express.json({ limit: "1mb" }));
  app.use(express.urlencoded({ extended: true }));

  // Morgan logger: production'da sadece hata logları, development'ta detaylı
  if (config.nodeEnv === "production") {
    app.use(
      morgan("combined", {
        skip: (req, res) => res.statusCode < 400, // Sadece 4xx ve 5xx logları
      }),
    );
  } else {
    app.use(morgan("dev"));
  }

  // Root endpoint - API bilgileri
  app.get("/", (req, res) => {
    res.json({
      success: true,
      message: "Su Arıtma API",
      version: "1.0.0",
      endpoints: {
        health: "/api/health",
        auth: "/api/auth",
        customers: "/api/customers",
        inventory: "/api/inventory",
        invoices: "/api/invoices",
        jobs: "/api/jobs",
        media: "/api/media",
        notifications: "/api/notifications",
        maintenance: "/api/maintenance",
        personnel: "/api/personnel",
        "personnel-jobs": "/api/personnel/jobs",
      },
      documentation: "This API serves the Su Arıtma CRM mobile application",
    });
  });

  app.use("/api", apiRouter);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
};
