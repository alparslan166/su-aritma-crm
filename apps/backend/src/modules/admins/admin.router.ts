import { Router } from "express";

import {
  deleteAdminHandler,
  getAllAdminsHandler,
  getAdminByIdHandler,
} from "./admin.controller";

const router = Router();

// Get all admins (ANA admin only)
router.get("/", getAllAdminsHandler);

// Get admin by ID (ANA admin only)
router.get("/:id", getAdminByIdHandler);

// Delete admin (ANA admin only)
router.delete("/:id", deleteAdminHandler);

export const adminRouter = router;

