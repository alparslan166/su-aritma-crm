import { Router } from "express";

import {
  addJobNoteHandler,
  assignJobHandler,
  createJobHandler,
  deleteJobHandler,
  getJobHandler,
  listJobHistoryHandler,
  listJobNotesHandler,
  listJobsHandler,
  updateJobHandler,
  updateJobStatusHandler,
} from "./job.controller";

const router = Router();

// List and create routes
router.get("/", listJobsHandler);
router.post("/", createJobHandler);

// Specific routes (must come before /:id)
router.post("/:id/assign", assignJobHandler);
router.post("/:id/status", updateJobStatusHandler);
router.get("/:id/history", listJobHistoryHandler);
router.get("/:id/notes", listJobNotesHandler);
router.post("/:id/notes", addJobNoteHandler);

// General routes (must come after specific routes)
router.get("/:id", getJobHandler);
router.put("/:id", updateJobHandler);
router.delete("/:id", deleteJobHandler);

export const jobRouter = router;
