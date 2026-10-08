import { createHmac } from "node:crypto";
import Redis from "ioredis";
import { HttpError } from "../../shared/errors/http-error";

export function platformLimitKeys(secret: string, email: string, ip: string) {
  const hash = (value: string) => createHmac("sha256", secret).update(value).digest("hex");
  return [`platform:login:account:${hash(email)}`, `platform:login:ip:${hash(ip)}`];
}

export function createPlatformLoginLimiter(redisUrl: string, secret: string) {
  return async (email: string, ip: string) => {
    const redis = new Redis(redisUrl, {
      lazyConnect: true, connectTimeout: 2000, maxRetriesPerRequest: 0,
      retryStrategy: () => null, enableOfflineQueue: false,
    });
    redis.on("error", () => {});
    try {
      await redis.connect();
      const allowed = Number(await redis.eval(`
        local a = redis.call('INCR', KEYS[1])
        if a == 1 then redis.call('EXPIRE', KEYS[1], 900) end
        local b = redis.call('INCR', KEYS[2])
        if b == 1 then redis.call('EXPIRE', KEYS[2], 900) end
        if a > 10 or b > 30 then return 0 end
        return 1
      `, 2, ...platformLimitKeys(secret, email, ip)));
      if (!allowed) throw new HttpError(429, "Too many platform login attempts; try again later");
    } catch (error) {
      if (error instanceof HttpError) throw error;
      throw new HttpError(503, "Platform login is temporarily unavailable");
    } finally { redis.disconnect(); }
  };
}
