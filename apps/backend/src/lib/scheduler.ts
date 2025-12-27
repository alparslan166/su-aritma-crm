import cron from "node-cron";
import { subscriptionService } from "../modules/subscriptions/subscription.service";

/**
 * Initialize all scheduled jobs
 * Runs on server startup
 */
export function initializeScheduler() {
  console.log("📅 Initializing scheduled jobs...");

  // Run subscription expiry notification check every day at 9:00 AM (Turkey time UTC+3)
  // Cron expression: minute hour day-of-month month day-of-week
  // 0 9 * * * = Every day at 09:00
  // Note: Using timezone option for Turkey time
  cron.schedule(
    "0 9 * * *",
    async () => {
      console.log("🕘 [CRON] Running daily subscription expiry check...");
      try {
        const result = await subscriptionService.checkAndSendExpiryNotifications();
        console.log(`✅ [CRON] Completed: ${result.notified} notifications sent, ${result.errors} errors`);
      } catch (error) {
        console.error("❌ [CRON] Failed to run expiry check:", error);
      }
    },
    {
      timezone: "Europe/Istanbul", // Turkey timezone
    }
  );

  console.log("✅ Scheduler initialized - Daily subscription check at 09:00 (Turkey time)");
}

