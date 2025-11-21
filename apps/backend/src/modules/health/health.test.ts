import request from "supertest";

import { createApp } from "@/app";

describe("Health endpoint", () => {
  it("returns uptime payload", async () => {
    const app = createApp();
    const response = await request(app).get("/api/health");

    expect(response.status).toBe(200);
    expect(response.body).toEqual(
      expect.objectContaining({
        success: true,
      }),
    );
  });
});

