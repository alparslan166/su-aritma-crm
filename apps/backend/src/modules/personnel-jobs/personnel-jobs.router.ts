import { Router } from "express";

import {
  deliverJobHandler,
  getAssignedJobHandler,
  listAssignedJobsHandler,
  startJobHandler,
} from "./personnel-jobs.controller";

const router = Router();

router.get("/", listAssignedJobsHandler);
router.get("/:id", getAssignedJobHandler);
router.post("/:id/start", startJobHandler);
router.post("/:id/deliver", deliverJobHandler);

export const personnelJobsRouter = router;

