import { Router } from "express";

import {
  adjustInventoryHandler,
  createInventoryHandler,
  deleteInventoryHandler,
  listInventoryHandler,
  updateInventoryHandler,
} from "./inventory.controller";

const router = Router();

router.get("/", listInventoryHandler);
router.post("/", createInventoryHandler);
router.put("/:id", updateInventoryHandler);
router.delete("/:id", deleteInventoryHandler);
router.post("/:id/adjust", adjustInventoryHandler);

export const inventoryRouter = router;

