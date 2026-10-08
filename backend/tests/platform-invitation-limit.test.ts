import { beforeEach, describe, expect, it, vi } from 'vitest';
const redis = vi.hoisted(() => ({ connect: vi.fn(), eval: vi.fn(), disconnect: vi.fn() }));
vi.mock('ioredis', () => ({ default: class { on() {} connect = redis.connect; eval = redis.eval; disconnect = redis.disconnect; } }));
import { createSchoolInvitationLimiter, invitationLimitKeys } from '../src/modules/platform/platform.invitation-limit';
const secret = 's'.repeat(32);
describe('school invitation throttling', () => {
  beforeEach(() => { vi.resetAllMocks(); redis.connect.mockResolvedValue(undefined); redis.eval.mockResolvedValue(1); });
  it('uses separate HMAC keys and never plaintext token or IP', async () => {
    const token = 't'.repeat(43), ip = '192.0.2.1';
    const keys = invitationLimitKeys(secret, token, ip);
    expect(keys.join('')).not.toContain(token);
    expect(keys.join('')).not.toContain(ip);
    await createSchoolInvitationLimiter('unused', secret)(token, ip);
    expect(redis.eval).toHaveBeenCalledWith(expect.any(String), 2, ...keys);
    expect(redis.disconnect).toHaveBeenCalled();
  });
  it('blocks excess attempts', async () => {
    redis.eval.mockResolvedValue(0);
    await expect(createSchoolInvitationLimiter('unused', secret)('token', 'ip')).rejects.toMatchObject({ statusCode: 429 });
  });
  it.each(['connect', 'eval'])('fails closed when %s fails', async (operation) => {
    redis[operation as 'connect' | 'eval'].mockRejectedValue(new Error('private redis configuration'));
    await expect(createSchoolInvitationLimiter('unused', secret)('token', 'ip')).rejects.toMatchObject({ statusCode: 503 });
    expect(redis.disconnect).toHaveBeenCalled();
  });
  it('rejects an invalid Redis result', async () => {
    redis.eval.mockResolvedValue('unexpected');
    await expect(createSchoolInvitationLimiter('unused', secret)('token', 'ip')).rejects.toMatchObject({ statusCode: 503 });
  });
  it('does not connect with missing limiter secret', async () => {
    await expect(createSchoolInvitationLimiter('unused', '')('token', 'ip')).rejects.toMatchObject({ statusCode: 503 });
    expect(redis.connect).not.toHaveBeenCalled();
  });
});
