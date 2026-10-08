import { beforeEach, describe, expect, it, vi } from "vitest";
const redis = vi.hoisted(() => ({ connect: vi.fn(), eval: vi.fn(), disconnect: vi.fn() }));
vi.mock("ioredis", () => ({ default: class {
  on() {}
  connect = redis.connect;
  eval = redis.eval;
  disconnect = redis.disconnect;
} }));
import { createPlatformLoginLimiter, platformLimitKeys } from "../src/modules/platform/platform.login-limit";

describe("platform login throttling", () => {
  beforeEach(() => { vi.resetAllMocks(); redis.connect.mockResolvedValue(undefined); redis.eval.mockResolvedValue(1); });
  it("keys by both account and IP without plaintext identifiers", async () => {
    await createPlatformLoginLimiter("unused", "key")("user@example.test", "127.0.0.1");
    const keys = platformLimitKeys("key", "user@example.test", "127.0.0.1");
    expect(keys.join("")).not.toContain("user@example.test");
    expect(keys.join("")).not.toContain("127.0.0.1");
    expect(redis.eval).toHaveBeenCalledWith(expect.any(String), 2, ...keys);
    expect(redis.disconnect).toHaveBeenCalled();
  });
  it("returns 429 when attempts are exhausted", async () => {
    redis.eval.mockResolvedValue(0);
    await expect(createPlatformLoginLimiter("unused", "key")("email", "ip")).rejects.toMatchObject({ statusCode: 429 });
    expect(redis.disconnect).toHaveBeenCalled();
  });
  it("returns 503 rather than bypassing limits when Redis fails", async () => {
    redis.connect.mockRejectedValue(new Error("unavailable"));
    await expect(createPlatformLoginLimiter("unused", "key")("email", "ip")).rejects.toMatchObject({ statusCode: 503 });
    expect(redis.disconnect).toHaveBeenCalled();
  });
});
