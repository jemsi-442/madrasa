import { afterEach, describe, expect, it, vi } from "vitest";
import { createHealthSnapshotReader } from "../src/modules/platform/platform.health";

describe("platform operational health", () => {
  afterEach(() => { vi.useRealTimers(); });
  it("checks both services and returns no configuration details", async () => {
    const read = createHealthSnapshotReader({ database: async () => 1, redis: async () => "PONG" });
    const result = await read();
    expect(result.status).toBe("healthy");
    expect(result.checks.map((check) => check.name)).toEqual(["database", "redis"]);
    expect(result.checks.every((check) => check.status === "available")).toBe(true);
    expect(Object.keys(result).sort()).toEqual(["checkedAt", "checks", "status"]);
  });
  it("reports degraded state without exposing probe errors", async () => {
    const read = createHealthSnapshotReader({ database: async () => 1, redis: async () => { throw new Error("redis://private:secret@internal"); } });
    const result = await read();
    expect(result.status).toBe("degraded");
    expect(result.checks[1]).toEqual({ name: "redis", status: "unavailable", latencyMs: null });
    expect(JSON.stringify(result)).not.toContain("secret");
  });
  it("bounds a stalled probe to three seconds", async () => {
    vi.useFakeTimers();
    const read = createHealthSnapshotReader({ database: async () => new Promise(() => {}), redis: async () => "PONG" });
    const result = read();
    await vi.advanceTimersByTimeAsync(3000);
    expect((await result).checks[0]?.status).toBe("unavailable");
    expect(vi.getTimerCount()).toBe(0);
  });
  it("shares concurrent checks and caches results for only five seconds", async () => {
    vi.useFakeTimers();
    const database = vi.fn().mockResolvedValue(1);
    const redis = vi.fn().mockResolvedValue("PONG");
    const read = createHealthSnapshotReader({ database, redis });
    await Promise.all([read(), read(), read()]);
    await read();
    expect(database).toHaveBeenCalledTimes(1);
    expect(redis).toHaveBeenCalledTimes(1);
    await vi.advanceTimersByTimeAsync(5001);
    await read();
    expect(database).toHaveBeenCalledTimes(2);
  });
});
