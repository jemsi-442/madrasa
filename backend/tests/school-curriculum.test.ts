import { describe, it, expect, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import type { AuthenticatedUser } from '../src/shared/middleware/authenticate';
import { SchoolCurriculumService } from '../src/modules/learning/school-curriculum';

const admin: AuthenticatedUser = { userId: '1', orgId: '10', role: 'ADMIN', branchId: '20' };
const input = { assignmentId: 'assigned-v1', classId: '30', subjectId: '40' };
function fixture() {
  const tx = {
    user: { findFirst: vi.fn().mockResolvedValue({ id: 1n }) },
    curriculumAssignment: { findFirst: vi.fn().mockResolvedValue({ id: 'assigned-v1' }), findMany: vi.fn().mockResolvedValue([]) },
    class: { findFirst: vi.fn().mockResolvedValue({ id: 30n }), findMany: vi.fn().mockResolvedValue([]) },
    subject: { findFirst: vi.fn().mockResolvedValue({ id: 40n }), findMany: vi.fn().mockResolvedValue([]) },
    classCurriculum: { findUnique: vi.fn().mockResolvedValue(null), create: vi.fn().mockResolvedValue({ id: 'adoption', orgId: 10n }) },
    auditLog: { create: vi.fn() },
  };
  const db = { $transaction: (fn: (t: typeof tx) => unknown) => fn(tx) } as unknown as PrismaClient;
  return { tx, service: new SchoolCurriculumService(db) };
}
describe('school curriculum boundaries', () => {
  it('adopts an assigned published version using scoped existing class and subject', async () => {
    const { tx, service } = fixture();
    expect(await service.adopt(admin, input)).toEqual({ id: 'adoption', orgId: '10' });
    expect(tx.curriculumAssignment.findFirst).toHaveBeenCalledWith(expect.objectContaining({ where: { id: input.assignmentId, organizationId: 10n, version: { status: 'PUBLISHED' } } }));
    expect(tx.class.findFirst).toHaveBeenCalledWith(expect.objectContaining({ where: { id: 30n, orgId: 10n, branchId: 20n } }));
    expect(tx.subject.findFirst).toHaveBeenCalledWith(expect.objectContaining({ where: { id: 40n, orgId: 10n, isActive: true } }));
    expect(tx.auditLog.create).toHaveBeenCalledOnce();
  });
  for (const missing of ['class', 'subject', 'curriculumAssignment'] as const) {
    it(`rejects unavailable or out-of-scope ${missing}`, async () => {
      const { tx, service } = fixture(); tx[missing].findFirst.mockResolvedValue(null);
      await expect(service.adopt(admin, input)).rejects.toMatchObject({ statusCode: 404 });
      expect(tx.classCurriculum.create).not.toHaveBeenCalled();
    });
  }
  it('makes repeat adoption idempotent and preserves previous versions', async () => {
    const { tx, service } = fixture();
    tx.classCurriculum.findUnique.mockResolvedValue({ id: 'existing', assignmentId: input.assignmentId });
    expect(await service.adopt(admin, input)).toMatchObject({ id: 'existing' });
    expect(tx.classCurriculum.create).not.toHaveBeenCalled();
    expect(tx.auditLog.create).not.toHaveBeenCalled();
    tx.classCurriculum.findUnique.mockResolvedValue({ id: 'existing', assignmentId: 'older-assignment' });
    await expect(service.adopt(admin, input)).rejects.toMatchObject({ statusCode: 409 });
  });
  it('restricts teacher reads to adopted assigned classes and hides school subject choices', async () => {
    const { tx, service } = fixture();
    await service.list({ ...admin, role: 'TEACHER', userId: '5' });
    expect(tx.curriculumAssignment.findMany).toHaveBeenCalledWith(expect.objectContaining({ where: {
      organizationId: 10n, version: { status: 'PUBLISHED' }, adoptions: { some: { class: { orgId: 10n, branchId: 20n, teacherId: 5n } } },
    } }));
    expect(tx.subject.findMany).not.toHaveBeenCalled();
    await expect(service.adopt({ ...admin, role: 'TEACHER' }, input)).rejects.toMatchObject({ statusCode: 403 });
  });
  it('denies accountant access and inactive users', async () => {
    const { tx, service } = fixture();
    await expect(service.list({ ...admin, role: 'ACCOUNTANT' })).rejects.toMatchObject({ statusCode: 403 });
    tx.user.findFirst.mockResolvedValue(null);
    await expect(service.adopt(admin, input)).rejects.toMatchObject({ statusCode: 403 });
    expect(tx.classCurriculum.create).not.toHaveBeenCalled();
  });
  it('rejects client supplied tenant and actor fields', async () => {
    const { service } = fixture();
    await expect(service.adopt(admin, { ...input, orgId: '99', adoptedBy: '99' })).rejects.toThrow();
  });
});
