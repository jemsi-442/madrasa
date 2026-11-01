import { Router } from "express";

import { asyncHandler } from "../../shared/utils/async-handler";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import { getMyOrganizationHandler } from "./organizations.controller";
import { locationSuggestions } from '../platform/location-suggestions';
import { listBranchLocations, saveBranchLocation } from './branch-locations';
import { requireRole } from '../../shared/middleware/require-role';

export const organizationsRouter = Router();

organizationsRouter.get('/branches', authenticate, requireTenantContext, requireRole('ADMIN'),
  asyncHandler(async (req, res) => {
    res.json({ success: true, data: await listBranchLocations(req.authUser!) });
  }));
organizationsRouter.post('/branches/:id/location', authenticate, requireTenantContext, requireRole('ADMIN'),
  asyncHandler(async (req, res) => {
    res.json({ success: true, data: await saveBranchLocation(req.authUser!, req.params.id, req.body) });
  }));

organizationsRouter.get('/location-suggestions', authenticate, requireTenantContext,
  asyncHandler(async (req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    res.json({ success: true, data: await locationSuggestions(null, req.query) });
  }));

organizationsRouter.get(
  "/me",
  authenticate,
  requireTenantContext,
  asyncHandler(getMyOrganizationHandler),
);

