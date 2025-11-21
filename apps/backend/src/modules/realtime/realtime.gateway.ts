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
    if (typeof role === "string") {
      socket.join(`role-${role}`);
    }

    socket.on("join:job", (jobId: string) => socket.join(`job-${jobId}`));
  }

  emitJobStatus(jobId: string, payload: unknown) {
    this.io?.to(`job-${jobId}`).emit("job-status", payload);
  }

  emitToRole(role: string, event: string, payload: unknown) {
    this.io?.to(`role-${role}`).emit(event, payload);
  }

  emitMaintenanceReminder(payload: unknown) {
    this.emitToRole("admin", "maintenance-reminder", payload);
  }
}

export const realtimeGateway = new RealtimeGateway();

