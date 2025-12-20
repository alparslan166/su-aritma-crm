import { Router } from "express";

import {
  activateSubscriptionHandler,
  cancelSubscriptionHandler,
  getAllSubscriptionsHandler,
  getSubscriptionHandler,
  markTrialNoticeSeenHandler,
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

// Mark trial started notice as seen (one-time)
router.post("/mark-trial-notice-seen", markTrialNoticeSeenHandler);

export const subscriptionRouter = router;
