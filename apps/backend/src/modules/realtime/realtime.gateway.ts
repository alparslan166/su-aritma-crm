import type { Server as HTTPServer } from "node:http";
import { Server as SocketIOServer, type Socket } from "socket.io";
import { logger } from "@/lib/logger";

class RealtimeGateway {
  private io?: SocketIOServer;

  initialize(server: HTTPServer) {
    this.io = new SocketIOServer(server, {
      cors: {
        origin: "*",
      },
    });

    this.io.on("connection", (socket) => this.handleConnection(socket));
    logger.info("🔌 WebSocket server initialized");
  }

  private handleConnection(socket: Socket) {
    const role = socket.handshake.query.role;
    const userId = socket.handshake.query.userId;

    logger.info(`🔌 New WebSocket connection: role=${role}, userId=${userId}`);

    if (typeof role === "string") {
      socket.join(`role-${role}`);
      logger.info(`✅ Socket joined role-${role}`);
    }

    if (typeof userId === "string" && typeof role === "string") {
      if (role === "admin") {
        socket.join(`admin-${userId}`);
        logger.info(`✅ Socket joined admin-${userId}`);
      } else if (role === "personnel") {
        socket.join(`personnel-${userId}`);
        logger.info(`✅ Socket joined personnel-${userId}`);
      }
    }

    socket.on("join:job", (jobId: string) => {
      socket.join(`job-${jobId}`);
      logger.info(`✅ Socket joined job-${jobId}`);
    });

    socket.on("disconnect", () => {
      logger.info(`🔌 Socket disconnected: role=${role}, userId=${userId}`);
    });
  }

  emitJobStatus(jobId: string, payload: unknown) {
    this.io?.to(`job-${jobId}`).emit("job-status", payload);
  }

  emitToRole(role: string, event: string, payload: unknown) {
    this.io?.to(`role-${role}`).emit(event, payload);
  }

  emitToAdmin(adminId: string, event: string, payload: unknown) {
    this.io?.to(`admin-${adminId}`).emit(event, payload);
  }

  emitToPersonnel(personnelId: string, event: string, payload: unknown) {
    const room = `personnel-${personnelId}`;
    const socketsInRoom = this.io?.sockets.adapter.rooms.get(room);
    const socketCount = socketsInRoom?.size ?? 0;
    logger.info(`📡 Emitting ${event} to room ${room} (${socketCount} sockets)`);
    this.io?.to(room).emit(event, payload);
    logger.info(`✅ Emitted ${event} to personnel ${personnelId}:`, payload);
  }

  emitMaintenanceReminder(payload: unknown) {
    this.emitToRole("admin", "maintenance-reminder", payload);
  }

  emitPersonnelLocation(
    adminId: string,
    personnelId: string,
    location: { lat: number; lng: number; timestamp: string; jobId?: string },
  ) {
    const payload = {
      personnelId,
      lat: location.lat,
      lng: location.lng,
      timestamp: location.timestamp,
      jobId: location.jobId,
    };
    logger.info(
      `📍 Emitting personnel location update: adminId=${adminId}, personnelId=${personnelId}`,
    );
    this.emitToAdmin(adminId, "personnel-location-update", payload);
  }
}

export const realtimeGateway = new RealtimeGateway();
