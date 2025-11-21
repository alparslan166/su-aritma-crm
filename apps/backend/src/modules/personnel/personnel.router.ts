import { Router } from "express";

import {
  createPersonnelHandler,
  createPersonnelLeaveHandler,
  deletePersonnelHandler,
  deletePersonnelLeaveHandler,
  getPersonnelHandler,
  listPersonnelHandler,
  listPersonnelLeavesHandler,
  resetPersonnelCodeHandler,
  updatePersonnelHandler,
} from "./personnel.controller";

const router = Router();

router.get("/", listPersonnelHandler);
router.post("/", createPersonnelHandler);
router.get("/:id", getPersonnelHandler);
router.put("/:id", updatePersonnelHandler);
router.delete("/:id", deletePersonnelHandler);
router.post("/:id/reset-code", resetPersonnelCodeHandler);

// Leave routes
router.get("/:id/leaves", listPersonnelLeavesHandler);
router.post("/:id/leaves", createPersonnelLeaveHandler);
router.delete("/:id/leaves/:leaveId", deletePersonnelLeaveHandler);

export const personnelRouter = router;

