import { Router } from "express";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import { requireActiveSchoolAccount } from "../../shared/middleware/active-school-account";
import { requireRole } from "../../shared/middleware/require-role";
import { asyncHandler } from "../../shared/utils/async-handler";
import { jsonRecord } from "../../shared/utils/json-record";
import * as schema from "./assessments.schemas";
import * as service from "./assessments.service";
export const assessmentsRouter = Router();
assessmentsRouter.use(authenticate, requireTenantContext, requireActiveSchoolAccount);
assessmentsRouter.use((_req, res, next) => { res.setHeader("Cache-Control", "no-store"); next(); });
assessmentsRouter.get("/children/:id/academic", requireRole("PARENT"), asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await service.parentAcademics(req.authUser!,
    schema.assessmentId.parse(req.params.id), schema.academicQuery.parse(req.query).year)) });
}));
assessmentsRouter.use(requireRole("TEACHER", "ADMIN"));
assessmentsRouter.get("/options", asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await service.assessmentOptions(req.authUser!)) });
}));
assessmentsRouter.get("/", asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await service.listAssessments(req.authUser!, schema.assessmentQuery.parse(req.query))) });
}));
assessmentsRouter.post("/", asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await service.createAssessment(req.authUser!, schema.createAssessmentInput.parse(req.body))) });
}));
assessmentsRouter.get("/:id", asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await service.assessmentDetail(req.authUser!, schema.assessmentId.parse(req.params.id))) });
}));
assessmentsRouter.post("/:id/results", asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await service.saveAssessment(req.authUser!, schema.assessmentId.parse(req.params.id), schema.resultsInput.parse(req.body))) });
}));
assessmentsRouter.post("/:id/transition", asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await service.transitionAssessment(req.authUser!, schema.assessmentId.parse(req.params.id), schema.transitionInput.parse(req.body))) });
}));
