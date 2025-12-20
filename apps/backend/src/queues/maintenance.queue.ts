import { Queue, Worker } from "bullmq";
import IORedis from "ioredis";

import { config } from "../config/env";
import { logger } from "../lib/logger";

import { maintenanceReminderProcessor } from "./maintenance.processor";

const QUEUE_NAME = "maintenance-reminders";

let initialized = false;

export const registerMaintenanceQueue = async () => {
  if (initialized) {
    return;
  }

  if (!config.redis.url) {
    logger.warn("REDIS_URL is not set. Maintenance reminders are disabled.");
    return;
  }

  try {
    const connection = new IORedis(config.redis.url, {
      maxRetriesPerRequest: null,
    });

    const queue = new Queue(QUEUE_NAME, { connection });
    const worker = new Worker(QUEUE_NAME, maintenanceReminderProcessor, {
      connection,
    });

    await queue.add(
      "maintenance-check",
      {},
      {
        jobId: "maintenance-check",
        repeat: { pattern: config.maintenance.cron },
        removeOnComplete: true,
        removeOnFail: true,
      },
    );

    initialized = true;

    const shutdown = async () => {
      await worker.close();
      await queue.close();
      await connection.quit();
    };

    process.on("SIGTERM", shutdown);
    process.on("SIGINT", shutdown);
  } catch (error) {
    logger.error("Failed to initialize maintenance queue:", error);
  }
};

