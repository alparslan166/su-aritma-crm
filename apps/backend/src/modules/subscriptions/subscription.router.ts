import { Router } from "express";

import {
  activateSubscriptionHandler,
  cancelSubscriptionHandler,
  getAllSubscriptionsHandler,
  getSubscriptionHandler,
  markTrialNoticeSeenHandler,
  renewSubscriptionHandler,
  sendExpiryNotificationsHandler,
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

// Cron endpoint to send expiry notifications daily
// Call this with: GET /api/subscriptions/cron/expiry-notifications?secret=YOUR_CRON_SECRET
router.get("/cron/expiry-notifications", sendExpiryNotificationsHandler);

export const subscriptionRouter = router;
