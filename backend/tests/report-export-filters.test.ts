import { beforeEach, expect, it, vi } from 'vitest';
const db = vi.hoisted(() => ({
  student: { findMany: vi.fn() }, payment: { findMany: vi.fn() },
  attendanceRecord: { findMany: vi.fn() }, class: { findFirst: vi.fn() },
}));
vi.mock('../src/shared/db/prisma', () => ({ prisma: db }));
import { exportStudentsReport, exportPaymentsReport, exportAttendanceReport } from '../src/modules/reports/reports.service';
import { paymentsExportQuerySchema } from '../src/modules/reports/reports.schemas';
const admin = { userId: '10', orgId: '20', role: 'ADMIN' as const };
beforeEach(() => {
  vi.clearAllMocks();
  db.student.findMany.mockResolvedValue([]); db.payment.findMany.mockResolvedValue([]);
  db.attendanceRecord.findMany.mockResolvedValue([]);
  db.class.findFirst.mockResolvedValue({ id: 3n, branchId: 2n, teacherId: 10n });
});
it('keeps payment search, invoice and channel within organization scope', async () => {
  const query = paymentsExportQuerySchema.parse({ search: 'Synthetic', invoiceId: '7', channel: 'mpesa', status: 'COMPLETED' });
  await exportPaymentsReport(admin, query);
  expect(db.payment.findMany).toHaveBeenCalledWith(expect.objectContaining({ where: expect.objectContaining({
    orgId: 20n, invoiceId: 7n, channel: 'mpesa', status: 'COMPLETED', AND: expect.any(Array),
  }) }));
});
it('keeps student search and status with assigned class scope', async () => {
  await exportStudentsReport({ ...admin, role: 'TEACHER' }, { search: 'Synthetic', status: 'ACTIVE', classId: '3' });
  expect(db.student.findMany).toHaveBeenCalledWith(expect.objectContaining({ where: expect.objectContaining({
    orgId: 20n, classId: 3n, status: 'ACTIVE', currentClass: { teacherId: 10n }, OR: expect.any(Array),
  }) }));
});
it('exports only saved attendance matching the class, day, search and status', async () => {
  await exportAttendanceReport(admin, { classId: '3', dateFrom: '2026-10-01', dateTo: '2026-10-01', search: 'Synthetic', status: 'LATE' });
  expect(db.attendanceRecord.findMany).toHaveBeenCalledWith(expect.objectContaining({ where: expect.objectContaining({
    orgId: 20n, classId: 3n, status: 'LATE', date: expect.any(Object), student: { OR: expect.any(Array) },
  }) }));
});
it('rejects another teachers class before reading any records', async () => {
  db.class.findFirst.mockResolvedValue({ id: 3n, branchId: 2n, teacherId: 99n });
  await expect(exportStudentsReport({ ...admin, role: 'TEACHER' }, { classId: '3' })).rejects.toMatchObject({ statusCode: 403 });
  expect(db.student.findMany).not.toHaveBeenCalled();
});
