import jwt from "jsonwebtoken";
import { describe, expect, it } from "vitest";

import { env } from "../src/config/env";
import { api, loginAsAdmin } from "./helpers/api-client";

describe("auth integration", () => {
  it("supports login, me, refresh rotation, logout, and expired-token handling", async () => {
    const loginResponse = await loginAsAdmin();

    expect(loginResponse.status).toBe(200);
    expect(loginResponse.body.success).toBe(true);
    expect(loginResponse.body.data.user.role).toBe("ADMIN");
    expect(loginResponse.body.data.accessToken).toBeTruthy();
    expect(loginResponse.body.data.refreshToken).toBeTruthy();

    const meResponse = await api
      .get("/api/auth/me")
      .set("Authorization", `Bearer ${loginResponse.body.data.accessToken}`);

    expect(meResponse.status).toBe(200);
    expect(meResponse.body.data.userId).toBe(loginResponse.body.data.user.id);
    expect(meResponse.body.data.role).toBe("ADMIN");

    const expiredAccessToken = jwt.sign(
      {
        orgId: loginResponse.body.data.user.orgId,
        role: loginResponse.body.data.user.role,
        branchId: loginResponse.body.data.user.branchId,
        type: "access",
      },
      env.JWT_SECRET,
      {
        subject: loginResponse.body.data.user.id,
        expiresIn: -10,
      },
    );

    const expiredMeResponse = await api
      .get("/api/auth/me")
      .set("Authorization", `Bearer ${expiredAccessToken}`);

    expect(expiredMeResponse.status).toBe(401);
    expect(expiredMeResponse.body.success).toBe(false);
    expect(expiredMeResponse.body.message).toBe("Access token expired");

    const refreshResponse = await api.post("/api/auth/refresh").send({
        refreshToken: loginResponse.body.data.refreshToken,
    });

    expect(refreshResponse.status).toBe(200);
    expect(refreshResponse.body.data.refreshToken).not.toBe(loginResponse.body.data.refreshToken);
    expect(refreshResponse.body.data.user.id).toBe(loginResponse.body.data.user.id);

    const reusedRefreshResponse = await api.post("/api/auth/refresh").send({
        refreshToken: loginResponse.body.data.refreshToken,
    });

    expect(reusedRefreshResponse.status).toBe(401);
    expect(reusedRefreshResponse.body.message).toBe("Refresh token has already been revoked");

    const logoutResponse = await api.post("/api/auth/logout").send({
        refreshToken: refreshResponse.body.data.refreshToken,
    });

    expect(logoutResponse.status).toBe(200);
    expect(logoutResponse.body.message).toBe("Session logged out successfully");

    const revokedRefreshResponse = await api.post("/api/auth/refresh").send({
        refreshToken: refreshResponse.body.data.refreshToken,
    });

    expect(revokedRefreshResponse.status).toBe(401);
    expect(revokedRefreshResponse.body.message).toBe("Refresh token has already been revoked");
  });
});
