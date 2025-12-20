import { NextFunction, Request, Response } from "express";
import { z } from "zod";

import { config } from "../config/env";
import { logger } from "../lib/logger";

export class AppError extends Error {
  statusCode: number;

  constructor(message: string, statusCode = 500) {
    super(message);
    this.statusCode = statusCode;
  }
}

export const notFoundHandler = (req: Request, res: Response, next: NextFunction) => {
  // API route'ları için daha açıklayıcı mesaj
  if (req.originalUrl.startsWith("/api")) {
    const error = new AppError(`API route ${req.originalUrl} not found`, 404);
    return next(error);
  }

  // Diğer istekler için genel mesaj
  const error = new AppError(
    `Route ${req.originalUrl} not found. This is an API server. Use /api/* endpoints.`,
    404,
  );
  next(error);
};

export const errorHandler = (
  error: Error | AppError,
  req: Request,
  res: Response,
  _next: NextFunction,
) => {
  const isDevelopment = config.nodeEnv === "development";

  // Detaylı error logging - her zaman logla (production'da da)
  logger.error(
    "═══════════════════════════════════════════════════════════════════════════════════════════",
  );
  logger.error("🛑🛑🛑 ERROR HANDLER - Hata Yakalandı 🛑🛑🛑");
  logger.error("   Error type:", error?.constructor?.name);
  logger.error("   Error message:", error?.message);
  logger.error("   Request URL:", req.originalUrl);
  logger.error("   Request method:", req.method);
  logger.error("   Request path:", req.path);
  logger.error("   Request params:", JSON.stringify(req.params, null, 2));
  logger.error("   Request body:", JSON.stringify(req.body, null, 2));
  logger.error("   Request headers:", JSON.stringify(req.headers, null, 2));

  // Stack trace her zaman logla
  if (error?.stack) {
    logger.error("   Stack:", error.stack);
  }

  // Handle Zod validation errors - özellikle detaylı logla
  if (error instanceof z.ZodError) {
    logger.error("   ❌ ZOD VALIDATION ERROR:");
    logger.error("   Issues:", JSON.stringify(error.issues, null, 2));
    error.issues.forEach((issue, index) => {
      logger.error(`   Issue ${index + 1}:`);
      logger.error(`     Path: ${issue.path.join(".")}`);
      logger.error(`     Message: ${issue.message}`);
      logger.error(`     Code: ${issue.code}`);
      if (issue.path.includes("nextMaintenanceDate")) {
        logger.error(`     ⚠️ nextMaintenanceDate validation hatası!`);
        logger.error(`     Received value: ${JSON.stringify(req.body?.nextMaintenanceDate)}`);
      }
    });

    const firstIssue = error.issues[0];
    const message = firstIssue?.message || "Geçersiz veri";
    const statusCode = 400;

    logger.error(
      "═══════════════════════════════════════════════════════════════════════════════════════════",
    );

    return res.status(statusCode).json({
      success: false,
      message: message,
      ...(isDevelopment && {
        issues: error.issues.map((issue) => ({
          path: issue.path.join("."),
          message: issue.message,
        })),
      }),
    });
  }

  logger.error(
    "═══════════════════════════════════════════════════════════════════════════════════════════",
  );

  const statusCode = error instanceof AppError ? error.statusCode : 500;
  const response = {
    success: false,
    message: error.message || "Internal Server Error",
    ...(process.env.NODE_ENV === "development" && {
      stack: error.stack,
      details: {
        type: error.constructor.name,
        url: req.originalUrl,
        method: req.method,
      },
    }),
  };
  res.status(statusCode).json(response);
};
