import cors from "cors";
import express from "express";
import fs from "fs";
import helmet from "helmet";
import morgan from "morgan";
import path from "path";

import { config } from "@/config/env";
import { errorHandler, notFoundHandler } from "@/middleware/error-handler";
import { apiRouter } from "@/routes";

export const createApp = () => {
  const app = express();

  app.use(
    helmet({
      crossOriginResourcePolicy: { policy: "cross-origin" },
      // APK indirme için gerekli ayarlar
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'"], // index.html için inline styles
          scriptSrc: ["'self'"],
          imgSrc: ["'self'", "data:", "https:"],
          download: ["'self'"], // APK indirme için
        },
      },
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
    app.use(morgan("combined", {
      skip: (req, res) => res.statusCode < 400, // Sadece 4xx ve 5xx logları
    }));
  } else {
    app.use(morgan("dev"));
  }

  // Static files (APK downloads)
  // Use process.cwd() to get project root in both dev and production
  const publicPath = path.join(process.cwd(), "public");
  
  // APK download endpoint - özel headers ile
  app.get("/download/apk/app-release.apk", (req, res) => {
    const apkPath = path.join(publicPath, "apk", "app-release.apk");
    
    if (!fs.existsSync(apkPath)) {
      return res.status(404).json({
        success: false,
        message: "APK dosyası bulunamadı. Lütfen daha sonra tekrar deneyin.",
      });
    }

    // APK için doğru MIME type ve download headers
    res.setHeader("Content-Type", "application/vnd.android.package-archive");
    res.setHeader("Content-Disposition", 'attachment; filename="app-release.apk"');
    res.setHeader("Cache-Control", "public, max-age=3600"); // 1 saat cache
    
    // Dosyayı gönder
    res.sendFile(apkPath);
  });

  // Diğer static dosyalar için genel static serving
  app.use("/download", express.static(publicPath, {
    setHeaders: (res, filePath) => {
      // APK dosyaları için özel header'lar
      if (filePath.endsWith(".apk")) {
        res.setHeader("Content-Type", "application/vnd.android.package-archive");
        res.setHeader("Content-Disposition", "attachment");
      }
    },
  }));

  // Serve index.html at root
  app.get("/", (req, res) => {
    const indexPath = path.join(publicPath, "index.html");
    // Check if file exists, otherwise return API info
    if (fs.existsSync(indexPath)) {
      res.sendFile(indexPath);
    } else {
      res.json({
        success: true,
        message: "Su Arıtma API",
        version: "1.0.0",
        endpoints: {
          health: "/api/health",
          auth: "/api/auth",
          customers: "/api/customers",
          download: "/download/apk/app-release.apk",
        },
      });
    }
  });

  app.use("/api", apiRouter);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
};
