import { NextFunction, Request, Response } from "express";

import { config } from "@/config/env";
import { logger } from "@/lib/logger";

export class AppError extends Error {
  statusCode: number;

  constructor(message: string, statusCode = 500) {
    super(message);
    this.statusCode = statusCode;
  }
}

export const notFoundHandler = (req: Request, res: Response, next: NextFunction) => {
  // Statik dosya istekleri için daha nazik bir yanıt
  if (req.originalUrl.match(/\.(html|css|js|png|jpg|jpeg|gif|ico|svg)$/i)) {
    return res.status(404).json({
      success: false,
      message: "Static file not found. This is an API server. Use /api/* endpoints.",
    });
  }
  
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
  
  // Production'da sadece temel hata bilgileri, development'ta detaylı
  logger.error("🛑 ERROR HANDLER:");
  logger.error("Error type:", error?.constructor?.name);
  logger.error("Error message:", error?.message);
  logger.error("Request URL:", req.originalUrl);
  logger.error("Request method:", req.method);
  
  // Hassas bilgiler sadece development'ta loglanır
  if (isDevelopment) {
    logger.error("Request body:", JSON.stringify(req.body, null, 2));
    logger.error("Request headers:", JSON.stringify(req.headers, null, 2));
    logger.error("Stack:", error?.stack);
  } else {
    // Production'da sadece stack trace (hassas bilgi içermeyen)
    if (error?.stack) {
      logger.error("Stack:", error.stack);
    }
  }

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

