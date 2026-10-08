import express from 'express';
import request from 'supertest';
import type { PrismaClient } from '@prisma/client';
import { beforeEach, describe, expect, it, vi } from 'vitest';
const accept = vi.hoisted(() => vi.fn());
vi.mock('../src/modules/platform/platform.school-invitation', () => ({ acceptSchoolAdminInvitation: accept }));
import { createSchoolInvitationRouter } from '../src/modules/platform/platform.invitation-routes';
import { errorHandler } from '../src/shared/middleware/error-handler';
import { HttpError } from '../src/shared/errors/http-error';
import { z } from 'zod';
const body = { token: 't'.repeat(43), fullName: 'First Admin', password: 'private-password-example' };
function fixture(enabled?: boolean) {
  const limit = vi.fn().mockResolvedValue(undefined);
  const app = express(); app.use(express.json());
  app.use('/school-invitations', createSchoolInvitationRouter({} as PrismaClient, enabled === undefined ? undefined : { enabled, consumeLimit: limit }));
  app.use(errorHandler);
  return { app, limit };
}
describe('school invitation acceptance boundary', () => {
  beforeEach(() => { vi.clearAllMocks(); accept.mockResolvedValue({ status: 'PENDING_ACTIVATION' }); });
  it.each([undefined, false])('stays closed with enabled=%s', async (enabled) => {
    const f = fixture(enabled);
    const response = await request(f.app).post('/school-invitations/accept').send(body);
    expect(response.status).toBe(503);
    expect(response.headers['cache-control']).toBe('no-store');
    expect(f.limit).not.toHaveBeenCalled(); expect(accept).not.toHaveBeenCalled();
  });
  it('checks limits before acceptance and returns no credentials or identity', async () => {
    const f = fixture(true);
    const response = await request(f.app).post('/school-invitations/accept').send(body);
    expect(f.limit).toHaveBeenCalledWith(body.token, expect.any(String));
    expect(f.limit.mock.invocationCallOrder[0]).toBeLessThan(accept.mock.invocationCallOrder[0]!);
    expect(response.status).toBe(200);
    expect(response.body).toEqual({ success: true, data: { status: 'PENDING_ACTIVATION' } });
    expect(response.headers['set-cookie']).toBeUndefined();
    expect(response.headers['referrer-policy']).toBe('no-referrer');
  });
  it.each([429, 503])('does not accept when limiter returns %s', async (status) => {
    const f = fixture(true); f.limit.mockRejectedValue(new HttpError(status, 'Unavailable'));
    const response = await request(f.app).post('/school-invitations/accept').send(body);
    expect(response.status).toBe(status); expect(accept).not.toHaveBeenCalled();
    if (status === 429) expect(response.headers['retry-after']).toBe('900');
  });
  it('counts malformed attempts and sanitizes validation errors', async () => {
    const f = fixture(true);
    accept.mockRejectedValue(z.never().safeParse(body).error);
    const response = await request(f.app).post('/school-invitations/accept').send({ token: 'bad', password: body.password });
    expect(f.limit).toHaveBeenCalledWith('invalid-token', expect.any(String));
    expect(response.status).toBe(422);
    expect(JSON.stringify(response.body)).not.toContain(body.password);
  });
  it('rejects query-supplied details and GET without accepting', async () => {
    const f = fixture(true);
    expect((await request(f.app).post('/school-invitations/accept?token=bad').send(body)).status).toBe(422);
    expect((await request(f.app).get('/school-invitations/accept')).status).toBe(404);
    expect(accept).not.toHaveBeenCalled();
  });
  it('hides unexpected database secrets from responses and logs', async () => {
    const f = fixture(true); accept.mockRejectedValue(new Error(body.token + body.password));
    const logger = vi.spyOn(console, 'error').mockImplementation(() => {});
    try {
      const response = await request(f.app).post('/school-invitations/accept').send(body);
      expect(response.status).toBe(503);
      expect(JSON.stringify(response.body)).not.toContain(body.token);
      expect(logger).not.toHaveBeenCalled();
    } finally { logger.mockRestore(); }
  });
});
