import { describe, expect, it, vi } from 'vitest';
import type { PrismaClient } from '@prisma/client';
import { PlatformCurriculumService } from '../src/modules/platform/platform.curriculum';
import { SchoolCurriculumService } from '../src/modules/learning/school-curriculum';
import { ensureTeacherCurriculumDemo } from '../scripts/teacher-curriculum-demo';

vi.mock('../src/modules/platform/platform.curriculum');
vi.mock('../src/modules/learning/school-curriculum');

function fixture() {
  vi.clearAllMocks();
  const version = { id: 'demo-version', status: 'PUBLISHED', description: 'DEMO ONLY' };
  const assignment = { id: 'demo-assignment', subjectId: 40n };
  const tx = {
    organization: { findUnique: vi.fn().mockResolvedValue({ id: 10n, status: 'ACTIVE' }) },
    user: { findFirst: vi.fn().mockResolvedValueOnce({ id: 1n, branchId: 20n }).mockResolvedValueOnce({ id: 2n, branchId: 20n }) },
    class: { findMany: vi.fn().mockResolvedValue([{ id: 30n, teacherId: 1n, branchId: 20n, name: 'Demo teaching group 1' }]) },
    platformAccount: { findFirst: vi.fn().mockResolvedValue({ id: 'demo-super' }) },
    curriculumVersion: { findMany: vi.fn().mockResolvedValue([version]) },
    curriculumAssignment: { findUnique: vi.fn().mockResolvedValue(assignment), findUniqueOrThrow: vi.fn().mockResolvedValue(assignment) },
    subject: { findMany: vi.fn().mockResolvedValue([{ id: 40n, isActive: true }]), create: vi.fn().mockResolvedValue({ id: 40n }) },
    classCurriculum: { findUnique: vi.fn().mockResolvedValue({ assignmentId: assignment.id }) },
  };
  const db = { $transaction: vi.fn((fn: (client: typeof tx) => unknown) => fn(tx)) } as unknown as PrismaClient;
  vi.mocked(PlatformCurriculumService.prototype.save).mockResolvedValue(version as never);
  vi.mocked(PlatformCurriculumService.prototype.addTopic).mockResolvedValue({ topic: { objectives: [{ id: 'objective' }] } } as never);
  return { db, tx };
}

describe('persistent teacher curriculum demo', () => {
  it('leaves existing published content and adoption unchanged on repeat runs', async () => {
    const { db } = fixture();
    expect((await ensureTeacherCurriculumDemo(db)).created).toEqual({ framework: false, assignment: false, subject: false, adoption: false });
    expect(PlatformCurriculumService.prototype.save).not.toHaveBeenCalled();
    expect(PlatformCurriculumService.prototype.transition).not.toHaveBeenCalled();
    expect(PlatformCurriculumService.prototype.assign).not.toHaveBeenCalled();
    expect(SchoolCurriculumService.prototype.adopt).not.toHaveBeenCalled();
    expect(SchoolCurriculumService.prototype.recordDelivery).not.toHaveBeenCalled();
  });
  it('creates, publishes, assigns and adopts through the role services', async () => {
    const { db, tx } = fixture();
    tx.curriculumVersion.findMany.mockResolvedValue([]);
    tx.curriculumAssignment.findUnique.mockResolvedValue(null);
    tx.classCurriculum.findUnique.mockResolvedValue(null);
    tx.subject.findMany.mockResolvedValue([]);
    expect((await ensureTeacherCurriculumDemo(db)).created).toEqual({ framework: true, assignment: true, subject: true, adoption: true });
    expect(PlatformCurriculumService.prototype.addTopic).toHaveBeenCalledTimes(2);
    expect(PlatformCurriculumService.prototype.saveLesson).toHaveBeenCalledTimes(2);
    expect(PlatformCurriculumService.prototype.transition).toHaveBeenCalledWith(expect.objectContaining({ accountId: 'demo-super' }), 'demo-version', expect.objectContaining({ action: 'publish' }));
    expect(PlatformCurriculumService.prototype.assign).toHaveBeenCalledWith(expect.anything(), 'demo-version', { organizationId: '10' });
    expect(SchoolCurriculumService.prototype.adopt).toHaveBeenCalledWith({ userId: '2', orgId: '10', branchId: '20', role: 'ADMIN' }, { assignmentId: 'demo-assignment', classId: '30', subjectId: '40' });
    expect(SchoolCurriculumService.prototype.recordDelivery).not.toHaveBeenCalled();
    expect(db.$transaction).toHaveBeenCalledWith(expect.any(Function), { isolationLevel: 'Serializable', timeout: 30000 });
  });
  it('reuses an existing subject instead of duplicating it', async () => {
    const { db, tx } = fixture();
    tx.classCurriculum.findUnique.mockResolvedValue(null);
    expect((await ensureTeacherCurriculumDemo(db)).created.adoption).toBe(true);
    expect(tx.subject.create).not.toHaveBeenCalled();
  });
  it('refuses a reassigned class', async () => {
    const { db, tx } = fixture();
    tx.class.findMany.mockResolvedValue([{ id: 30n, teacherId: 99n, branchId: 20n, name: 'Demo teaching group 1' }]);
    await expect(ensureTeacherCurriculumDemo(db)).rejects.toThrow('ownership changed');
    expect(PlatformCurriculumService.prototype.save).not.toHaveBeenCalled();
  });
  it('refuses to replace a different adoption', async () => {
    const { db, tx } = fixture();
    tx.classCurriculum.findUnique.mockResolvedValue({ assignmentId: 'newer-version-assignment' });
    await expect(ensureTeacherCurriculumDemo(db)).rejects.toThrow('curriculum differs');
    expect(SchoolCurriculumService.prototype.adopt).not.toHaveBeenCalled();
  });
  it.each(['DRAFT', 'IN_REVIEW', 'APPROVED', 'ARCHIVED'])('does not publish an existing %s automatically', async status => {
    const { db, tx } = fixture();
    tx.curriculumVersion.findMany.mockResolvedValue([{ id: 'demo-version', status, description: 'DEMO ONLY' }]);
    await expect(ensureTeacherCurriculumDemo(db)).rejects.toThrow('manual review');
    expect(PlatformCurriculumService.prototype.transition).not.toHaveBeenCalled();
  });
  it('does not repurpose unmarked curriculum', async () => {
    const { db, tx } = fixture();
    tx.curriculumVersion.findMany.mockResolvedValue([{ id: 'demo-version', status: 'PUBLISHED', description: 'School curriculum' }]);
    await expect(ensureTeacherCurriculumDemo(db)).rejects.toThrow('manual review');
  });
  it('rejects staff in different branches', async () => {
    const { db, tx } = fixture();
    tx.user.findFirst.mockReset().mockResolvedValueOnce({ id: 1n, branchId: 20n }).mockResolvedValueOnce({ id: 2n, branchId: 21n });
    await expect(ensureTeacherCurriculumDemo(db)).rejects.toThrow('staff scopes');
  });
  it('does not reactivate an inactive mapped subject', async () => {
    const { db, tx } = fixture();
    tx.subject.findMany.mockResolvedValue([{ id: 40n, isActive: false }]);
    await expect(ensureTeacherCurriculumDemo(db)).rejects.toThrow('inactive');
  });
});
