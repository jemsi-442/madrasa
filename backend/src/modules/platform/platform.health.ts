import type { PrismaClient } from "@prisma/client";
import Redis from "ioredis";

export type PlatformHealth = {
  status: "healthy" | "degraded";
  checkedAt: string;
  checks: Array<{ name: "database" | "redis"; status: "available" | "unavailable"; latencyMs: number | null }>;
};
export type PlatformHealthReader = () => Promise<PlatformHealth>;

export function createHealthSnapshotReader(probes: Record<"database" | "redis", () => Promise<unknown>>): PlatformHealthReader {
  let pending: Promise<PlatformHealth> | undefined;
  let cached: PlatformHealth | undefined;
  let validUntil = 0;
  return async () => {
    if (cached && Date.now() < validUntil) return cached;
    if (pending) return pending;
    pending = (async () => {
      const checks = await Promise.all((["database", "redis"] as const).map(async (name) => {
        const started = performance.now();
        let timer: ReturnType<typeof setTimeout> | undefined;
        try {
          await Promise.race([
            Promise.resolve().then(probes[name]),
            new Promise<never>((_, reject) => { timer = setTimeout(() => reject(new Error("Probe timed out")), 3000); }),
          ]);
          return { name, status: "available" as const, latencyMs: Math.round(performance.now() - started) };
        } catch {
          // Operational responses must never expose connection strings or raw exceptions.
          return { name, status: "unavailable" as const, latencyMs: null };
        } finally { clearTimeout(timer); }
      }));
      cached = { status: checks.every((check) => check.status === "available") ? "healthy" : "degraded", checkedAt: new Date().toISOString(), checks };
      validUntil = Date.now() + 5000;
      return cached;
    })();
    try { return await pending; } finally { pending = undefined; }
  };
}

export function createPlatformHealthReader(db: PrismaClient, redisUrl: string): PlatformHealthReader {
  return createHealthSnapshotReader({
    database: () => db.$transaction(async (tx) => tx.$queryRaw`SELECT 1`, { maxWait: 1000, timeout: 2000 }),
    redis: async () => {
      const redis = new Redis(redisUrl, { lazyConnect: true, connectTimeout: 1000, commandTimeout: 1000,
        maxRetriesPerRequest: 0, retryStrategy: () => null, enableOfflineQueue: false });
      redis.on("error", () => {});
      try {
        await redis.connect();
        if (await redis.ping() !== "PONG") throw new Error("Unexpected probe response");
      } finally { redis.disconnect(); }
    },
  });
}
