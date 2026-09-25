import { describe, expect, it } from "vitest";

import { api, loginAsAdmin } from "./helpers/api-client";

describe("reports integration", () => {
  it("returns stable health and protected report responses", async () => {
    const healthResponse = await api.get("/api/health");

    expect(healthResponse.status).toBe(200);
    expect(healthResponse.body.success).toBe(true);
    expect(healthResponse.body.data.timestamp).toBeTruthy();

    const unauthorizedDashboard = await api.get("/api/reports/dashboard");

    expect(unauthorizedDashboard.status).toBe(401);
    expect(unauthorizedDashboard.body.message).toBe("Authorization header is required");

    const loginResponse = await loginAsAdmin();
    expect(loginResponse.status).toBe(200);

    const dashboardResponse = await api
      .get("/api/reports/dashboard")
      .set("Authorization", `Bearer ${loginResponse.body.data.accessToken}`);

    expect(dashboardResponse.status).toBe(200);
    expect(dashboardResponse.body.success).toBe(true);
    expect(dashboardResponse.body.data.students).toBeTruthy();
    expect(dashboardResponse.body.data.attendance).toBeTruthy();

    const attendanceSummaryResponse = await api
      .get("/api/reports/attendance/summary")
      .set("Authorization", `Bearer ${loginResponse.body.data.accessToken}`);

    expect(attendanceSummaryResponse.status).toBe(200);
    expect(attendanceSummaryResponse.body.success).toBe(true);
    expect(Array.isArray(attendanceSummaryResponse.body.data.timeline)).toBe(true);

    const financeSummaryResponse = await api
      .get("/api/reports/finance/monthly-summary?year=2026")
      .set("Authorization", `Bearer ${loginResponse.body.data.accessToken}`);

    expect(financeSummaryResponse.status).toBe(200);
    expect(financeSummaryResponse.body.success).toBe(true);
    expect(financeSummaryResponse.body.data.year).toBe(2026);
    expect(Array.isArray(financeSummaryResponse.body.data.months)).toBe(true);
  });
});
