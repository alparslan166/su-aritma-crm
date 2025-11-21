import { createServer } from "http";

import { createApp } from "@/app";
import { config } from "@/config/env";
import { logger } from "@/lib/logger";
import { prisma } from "@/lib/prisma";
import { realtimeGateway } from "@/modules/realtime/realtime.gateway";
import { registerMaintenanceQueue } from "@/queues/maintenance.queue";

const app = createApp();
const server = createServer(app);

realtimeGateway.initialize(server);

const start = async () => {
  try {
    await prisma.$connect();
    server.listen(config.port, "0.0.0.0", () => {
      logger.info(`API listening on port ${config.port}`);
    });
    await registerMaintenanceQueue();
  } catch (error) {
    logger.error("Failed to start server", error);
    process.exit(1);
  }
};

void start();

const gracefulShutdown = async () => {
  await prisma.$disconnect();
  server.close(() => {
    process.exit(0);
  });
};

process.on("SIGINT", gracefulShutdown);
process.on("SIGTERM", gracefulShutdown);

