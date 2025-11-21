import { Request, Response } from "express";

export const healthCheck = (req: Request, res: Response) => {
  res.json({
    success: true,
    uptime: process.uptime(),
    version: process.env.npm_package_version,
    timestamp: new Date().toISOString(),
  });
};

