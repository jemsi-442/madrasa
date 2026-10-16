import { Router } from 'express';
import { prisma } from '../../shared/db/prisma';
import { authenticate } from '../../shared/middleware/authenticate';
import { requireTenantContext } from '../../shared/middleware/tenant-context';
import { requireRole } from '../../shared/middleware/require-role';
import { asyncHandler } from '../../shared/utils/async-handler';
import { SchoolCurriculumService } from './school-curriculum';

export const schoolCurriculumRouter = Router();
const service = new SchoolCurriculumService(prisma);
schoolCurriculumRouter.use(authenticate, requireTenantContext, requireRole('ADMIN', 'TEACHER'));
schoolCurriculumRouter.use((_req, res, next) => { res.setHeader('Cache-Control', 'no-store'); next(); });
schoolCurriculumRouter.get('/', asyncHandler(async (req, res) => {
  res.json({ success: true, data: await service.list(req.authUser!) });
}));
schoolCurriculumRouter.post('/adoptions', requireRole('ADMIN'), asyncHandler(async (req, res) => {
  res.json({ success: true, data: await service.adopt(req.authUser!, req.body) });
}));
