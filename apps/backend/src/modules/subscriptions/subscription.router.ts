import { Router } from "express";

import {
  activateSubscriptionHandler,
  cancelSubscriptionHandler,
  getAllSubscriptionsHandler,
  getSubscriptionHandler,
  renewSubscriptionHandler,
} from "./subscription.controller";

const router = Router();

// Get current user's subscription
router.get("/", getSubscriptionHandler);

// Get all subscriptions (ANA admin only)
router.get("/all", getAllSubscriptionsHandler);

// Activate subscription (after payment)
router.post("/activate", activateSubscriptionHandler);

// Renew subscription
router.post("/renew", renewSubscriptionHandler);

// Cancel subscription
router.post("/cancel", cancelSubscriptionHandler);

export const subscriptionRouter = router;

