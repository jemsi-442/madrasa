import { readFile } from 'node:fs/promises';
import { parse } from 'dotenv';

export function validateDevelopment(env) {
  if (env.NODE_ENV !== 'development') throw new Error('Development mode is required.');
  let database, redis;
  try { database = new URL(env.DATABASE_URL); redis = new URL(env.REDIS_URL); }
  catch { throw new Error('Local database and Redis configuration is required.'); }
  const local = host => ['localhost', '127.0.0.1', '[::1]'].includes(host);
  if (database.protocol !== 'mysql:' || !local(database.hostname) ||
      !/^\/[a-zA-Z0-9_-]+$/.test(database.pathname) ||
      ['/mysql', '/sys', '/information_schema', '/performance_schema', '/afaq_local_demo'].includes(database.pathname) ||
      redis.protocol !== 'redis:' || !local(redis.hostname)) {
    throw new Error('Use the shared local development database, not production or the isolated test database.');
  }
  if (env.SNIPPE_MOCK_MODE !== 'true') throw new Error('Development requires mock payments.');
  return { database, redis };
}

export async function developmentEnvironment(file, inherited = process.env) {
  if (inherited.NODE_ENV === 'production') throw new Error('Production is not allowed.');
  // Keep dotenv precedence consistent with the ordinary backend entry point.
  const env = { ...parse(await readFile(file, 'utf8')), ...inherited };
  validateDevelopment(env);
  return env;
}
