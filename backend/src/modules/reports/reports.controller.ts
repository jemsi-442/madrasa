import type { Request, Response } from "express";

import {
  attendanceSummaryQuerySchema,
  attendanceExportQuerySchema,
  dashboardReportQuerySchema,
  monthlyFinanceSummaryQuerySchema,
  paymentsExportQuerySchema,
  studentsExportQuerySchema,
  teacherDashboardQuerySchema,
} from "./reports.schemas";
import {
  exportMonthlyFinanceSummaryReport,
  exportAttendanceReport,
  exportPaymentsReport,
  exportStudentsReport,
  getAttendanceSummaryReport,
  getDashboardReport,
  getMonthlyFinanceSummaryReport,
  getTeacherDashboardReport,
} from "./reports.service";

export const getDashboardReportHandler = async (req: Request, res: Response) => {
  const query = dashboardReportQuerySchema.parse(req.query);
  const report = await getDashboardReport(req.authUser!, query);

  res.status(200).json({
    success: true,
    message: "Dashboard report loaded successfully",
    data: report,
  });
};

export const exportStudentsReportHandler = async (req: Request, res: Response) => {
  const query = studentsExportQuerySchema.parse(req.query);
  const report = await exportStudentsReport(req.authUser!, query);

  res.setHeader("Content-Type", report.contentType);
  res.setHeader("Content-Disposition", `attachment; filename=\"${report.fileName}\"`);
  res.status(200).send(report.content);
};

export const exportPaymentsReportHandler = async (req: Request, res: Response) => {
  const query = paymentsExportQuerySchema.parse(req.query);
  const report = await exportPaymentsReport(req.authUser!, query);

  res.setHeader("Content-Type", report.contentType);
  res.setHeader("Content-Disposition", `attachment; filename=\"${report.fileName}\"`);
  res.status(200).send(report.content);
};

export const exportAttendanceReportHandler = async (req: Request, res: Response) => {
  const query = attendanceExportQuerySchema.parse(req.query);
  const report = await exportAttendanceReport(req.authUser!, query);

  res.setHeader("Content-Type", report.contentType);
  res.setHeader("Content-Disposition", `attachment; filename=\"${report.fileName}\"`);
  res.status(200).send(report.content);
};

export const getMonthlyFinanceSummaryReportHandler = async (req: Request, res: Response) => {
  const query = monthlyFinanceSummaryQuerySchema.parse(req.query);
  const report = await getMonthlyFinanceSummaryReport(req.authUser!, query);

  res.status(200).json({
    success: true,
    message: "Monthly finance summary loaded successfully",
    data: report,
  });
};

export const exportMonthlyFinanceSummaryReportHandler = async (req: Request, res: Response) => {
  const query = monthlyFinanceSummaryQuerySchema.parse(req.query);
  const report = await exportMonthlyFinanceSummaryReport(req.authUser!, query);

  res.setHeader("Content-Type", report.contentType);
  res.setHeader("Content-Disposition", `attachment; filename=\"${report.fileName}\"`);
  res.status(200).send(report.content);
};

export const getAttendanceSummaryReportHandler = async (req: Request, res: Response) => {
  const query = attendanceSummaryQuerySchema.parse(req.query);
  const report = await getAttendanceSummaryReport(req.authUser!, query);

  res.status(200).json({
    success: true,
    message: "Attendance summary loaded successfully",
    data: report,
  });
};

export const getTeacherDashboardReportHandler = async (req: Request, res: Response) => {
  const query = teacherDashboardQuerySchema.parse(req.query);
  const report = await getTeacherDashboardReport(req.authUser!, query);

  res.status(200).json({
    success: true,
    message: "Teacher dashboard report loaded successfully",
    data: report,
  });
};
