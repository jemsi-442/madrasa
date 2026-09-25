import { Router, type Request, type Response } from "express";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireRole } from "../../shared/middleware/require-role";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import { asyncHandler } from "../../shared/utils/async-handler";
import { jsonRecord } from "../../shared/utils/json-record";
import { directoryQuerySchema, recordId } from "../fundraising/fundraising.schemas";
import { eventSchema, teacherDirectorySchema } from "./admin-panel.schemas";
import * as service from "./admin-panel.service";

export const adminPanelRouter = Router();
adminPanelRouter.use(authenticate, requireTenantContext, requireRole("ADMIN"));
const handle = (fn: (req: Request) => Promise<unknown>, status = 200) => asyncHandler(async (req: Request, res: Response) => {
  res.status(status).json({ success: true, data: jsonRecord(await fn(req)) });
});
adminPanelRouter.get("/guardians", handle((req) => service.guardianDirectory(req.authUser!, directoryQuerySchema.parse(req.query))));
adminPanelRouter.get("/students/summary", handle((req) => service.studentDemographics(req.authUser!)));
adminPanelRouter.get("/overview", handle((req) => service.adminOverview(req.authUser!)));
adminPanelRouter.get("/teachers", handle((req) => service.teachersDirectory(req.authUser!, teacherDirectorySchema.parse(req.query))));
adminPanelRouter.get("/subjects", handle((req) => service.subjectsDirectory(req.authUser!, directoryQuerySchema.parse(req.query))));
adminPanelRouter.post("/events", handle((req) => service.createEvent(req.authUser!, eventSchema.parse(req.body)), 201));
adminPanelRouter.post("/events/:id/cancel", handle((req) => service.cancelEvent(req.authUser!, recordId.parse(req.params.id))));
