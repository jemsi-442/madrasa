import { Router } from "express";
import { HttpError } from "../../shared/errors/http-error";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import { requireActiveSchoolAccount } from "../../shared/middleware/active-school-account";
import { requireRole } from "../../shared/middleware/require-role";
import { asyncHandler } from "../../shared/utils/async-handler";
import { jsonRecord } from "../../shared/utils/json-record";
import { transitionInput } from "../assessments/assessments.schemas";
import * as s from "./student-reports.schemas";
import * as service from "./student-reports.service";
import { reportPdf } from "./report-pdf";

export const studentReportsRouter = Router();
studentReportsRouter.use(authenticate, requireTenantContext, requireActiveSchoolAccount);
studentReportsRouter.use((_req, res, next) => { res.setHeader("Cache-Control", "no-store"); next(); });
studentReportsRouter.get("/children/:studentId", requireRole("PARENT"), asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await service.parentList(req.authUser!, s.reportId.parse(req.params.studentId), s.pageQuery.parse(req.query).page)) });
}));
studentReportsRouter.get("/children/:studentId/:id/pdf", requireRole("PARENT"), asyncHandler(async (req, res) => {
  const row = await service.parentRelease(req.authUser!, s.reportId.parse(req.params.studentId), s.reportId.parse(req.params.id));
  const pdf = await reportPdf(row.snapshot as unknown as service.LearningReport, `R-${row.id}`, row.createdAt);
  // JSON delivery reuses the authenticated client's refresh/retry path; never a public URL.
  res.json({ success: true, data: { fileName: `learning-report-${row.id}.pdf`, contentType: "application/pdf", base64: pdf.toString("base64") } });
}));
studentReportsRouter.use(requireRole("ADMIN", "TEACHER"));
studentReportsRouter.get("/options", asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await service.options(req.authUser!)) });
}));
studentReportsRouter.get("/roster", asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await service.roster(req.authUser!, s.rosterQuery.parse(req.query).classId)) });
}));
studentReportsRouter.post("/periods", asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await service.createPeriod(req.authUser!, s.periodInput.parse(req.body))) });
}));
studentReportsRouter.get("/", asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await service.list(req.authUser!, s.listQuery.parse(req.query))) });
}));
studentReportsRouter.post("/", asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await service.prepare(req.authUser!, s.prepareInput.parse(req.body))) });
}));
studentReportsRouter.get("/:id", asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await service.get(req.authUser!, s.reportId.parse(req.params.id))) });
}));
studentReportsRouter.get("/:id/pdf", asyncHandler(async (req, res) => {
  const row = await service.get(req.authUser!, s.reportId.parse(req.params.id));
  if (row.status === "PUBLISHED" && !row.sourcesCurrent) throw new HttpError(409, "A source assessment was retracted. Retract and refresh this report before downloading.");
  const release = row.status === "PUBLISHED" ? row.releases[0] : undefined;
  const pdf = await reportPdf((release?.snapshot ?? row.draft) as unknown as service.LearningReport,
    release ? `R-${release.id}` : `DRAFT-${row.id}-v${row.revision}`, release?.createdAt);
  res.json({ success: true, data: { fileName: `report-${row.id}.pdf`, contentType: "application/pdf", base64: pdf.toString("base64") } });
}));
studentReportsRouter.post("/:id/draft", asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await service.save(req.authUser!, s.reportId.parse(req.params.id), s.saveInput.parse(req.body))) });
}));
studentReportsRouter.post("/:id/transition", asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await service.transition(req.authUser!, s.reportId.parse(req.params.id), transitionInput.parse(req.body))) });
}));
