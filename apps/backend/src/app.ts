import cors from "cors";
import express from "express";
import fs from "fs";
import helmet from "helmet";
import morgan from "morgan";
import path from "path";

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
      origin: "*",
      credentials: true,
    }),
  );
  app.use(express.json({ limit: "1mb" }));
  app.use(express.urlencoded({ extended: true }));
  app.use(morgan("dev"));

  // Static files (APK downloads)
  // Use process.cwd() to get project root in both dev and production
  const publicPath = path.join(process.cwd(), "public");
  app.use("/download", express.static(publicPath));

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
