import { Router } from "express";

import { createPresignedUrlHandler } from "./media.controller";

const router = Router();

router.post("/sign", createPresignedUrlHandler);

export const mediaRouter = router;

