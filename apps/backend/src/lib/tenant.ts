import { Request } from "express";

import { AppError } from "@/middleware/error-handler";

const ADMIN_HEADER = "x-admin-id";
const PERSONNEL_HEADER = "x-personnel-id";

export const getAdminId = (req: Request): string => {
  const adminId = req.header(ADMIN_HEADER);
  if (!adminId) {
    throw new AppError(`Missing ${ADMIN_HEADER} header`, 400);
  }
  return adminId;
};

export const getPersonnelId = (req: Request): string => {
  const personnelId = req.header(PERSONNEL_HEADER);
  if (!personnelId) {
    throw new AppError(`Missing ${PERSONNEL_HEADER} header`, 400);
  }
  return personnelId;
};

