import { Router } from "express";

import {
  createOperationHandler,
  deleteOperationHandler,
  getOperationHandler,
  listOperationsHandler,
  updateOperationHandler,
} from "./operation.controller";

const router = Router();

router.get("/", listOperationsHandler);
router.get("/:id", getOperationHandler);
router.post("/", createOperationHandler);
router.put("/:id", updateOperationHandler);
router.delete("/:id", deleteOperationHandler);

export const operationRouter = router;

