import type { Server as HTTPServer } from "node:http";
import { Server as SocketIOServer, type Socket } from "socket.io";

class RealtimeGateway {
  private io?: SocketIOServer;

  initialize(server: HTTPServer) {
    this.io = new SocketIOServer(server, {
      cors: {
        origin: "*",
      },
    });

    this.io.on("connection", (socket) => this.handleConnection(socket));
  }

  private handleConnection(socket: Socket) {
    const role = socket.handshake.query.role;
    const userId = socket.handshake.query.userId;

    if (typeof role === "string") {
      socket.join(`role-${role}`);
    }

    if (typeof userId === "string" && typeof role === "string") {
      if (role === "admin") {
        socket.join(`admin-${userId}`);
      } else if (role === "personnel") {
        socket.join(`personnel-${userId}`);
      }
    }

    socket.on("join:job", (jobId: string) => socket.join(`job-${jobId}`));
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
    this.io?.to(`personnel-${personnelId}`).emit(event, payload);
  }

  emitMaintenanceReminder(payload: unknown) {
    this.emitToRole("admin", "maintenance-reminder", payload);
  }
}

export const realtimeGateway = new RealtimeGateway();
