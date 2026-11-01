import type { Prisma } from '@prisma/client';
import { HttpError } from '../../shared/errors/http-error';

export async function allocateMadrasaCode(tx: Prisma.TransactionClient) {
  // Auto-increment allocation is concurrency-safe; gaps after rollback are normal.
  for (let attempt = 0; attempt < 100; attempt++) {
    const sequence = await tx.madrasaCodeSequence.create({ data: {} });
    const code = `AFQ-${sequence.id.toString().padStart(6, '0')}`;
    const school = await tx.organization.findUnique({ where: { code }, select: { id: true } });
    const application = await tx.tenantApplication.findUnique({ where: { requestedCode: code }, select: { id: true } });
    if (!school && !application) return code;
  }
  throw new HttpError(409, 'Could not allocate a madrasa code. Contact support.');
}
