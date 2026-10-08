import { createHmac } from "node:crypto";
import Redis from "ioredis";
import { HttpError } from "../../shared/errors/http-error";

export function invitationLimitKeys(secret: string, token: string, ip: string) {
  const hash = (value: string) => createHmac("sha256", secret).update(value).digest("hex");
  return [`school:invitation:token:${hash(token)}`, `school:invitation:ip:${hash(ip)}`];
}

export function createSchoolInvitationLimiter(redisUrl: string, secret: string) {
  return async (token: string, ip: string) => {
    if (secret.length < 32) throw new HttpError(503, "Invitation acceptance is unavailable");
    const redis = new Redis(redisUrl, {
      lazyConnect: true, connectTimeout: 2000, commandTimeout: 2000,
      maxRetriesPerRequest: 0, retryStrategy: () => null, enableOfflineQueue: false,
    });
    redis.on("error", () => {});
    try {
      await redis.connect();
      const result = Number(await redis.eval(`
        local a = redis.call('INCR', KEYS[1])
        if a == 1 then redis.call('EXPIRE', KEYS[1], 900) end
        local b = redis.call('INCR', KEYS[2])
        if b == 1 then redis.call('EXPIRE', KEYS[2], 900) end
        if a > 10 or b > 30 then return 0 end
        return 1
      `, 2, ...invitationLimitKeys(secret, token, ip)));
      if (result === 0) throw new HttpError(429, "Too many attempts. Try again later");
      if (result !== 1) throw new Error("Invalid limiter response");
    } catch (error) {
      if (error instanceof HttpError) throw error;
      throw new HttpError(503, "Invitation acceptance is unavailable");
    } finally { redis.disconnect(); }
  };
}
