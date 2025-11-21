import { NextFunction, Request, Response } from "express";
import { z } from "zod";

import { mediaService } from "./media.service";

const signSchema = z.object({
  contentType: z.string().min(1),
  prefix: z.string().optional(),
});

export const createPresignedUrlHandler = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const parsed = signSchema.parse(req.body);
    const payload = await mediaService.createPresignedUpload(parsed);
    res.status(201).json({ success: true, data: payload });
  } catch (error) {
    next(error);
  }
};

