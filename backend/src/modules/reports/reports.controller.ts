import type { Request, Response } from "express";
import { reportCsvRows, tabularReportPdf } from '../../shared/utils/tabular-report-pdf';

export const pdfReportHandler = (kind: 'students' | 'payments' | 'attendance' | 'finance') => async (req: Request, res: Response) => {
  // Reuse the existing export services: tenant/class scope and role checks remain unchanged.
  const report = kind === 'students' ? await exportStudentsReport(req.authUser!, studentsExportQuerySchema.parse(req.query))
    : kind === 'payments' ? await exportPaymentsReport(req.authUser!, paymentsExportQuerySchema.parse(req.query))
    : kind === 'attendance' ? await exportAttendanceReport(req.authUser!, attendanceExportQuerySchema.parse(req.query))
    : await exportMonthlyFinanceSummaryReport(req.authUser!, monthlyFinanceSummaryQuerySchema.parse(req.query));
  const rows = reportCsvRows(report.content);
  const titles = { students: 'Student directory', payments: 'Payment report', attendance: 'Attendance report', finance: 'Annual financial report' };
  const period = kind === 'finance' ? `Year ${report.fileName.match(/(\d{4})\.csv$/)?.[1] ?? ''} | ` : '';
  const pdf = await tabularReportPdf(titles[kind], `${period}Generated ${new Date().toISOString().slice(0, 10)} | Current authorized school scope`, rows[0] ?? [], rows.slice(1));
  res.setHeader('Cache-Control', 'no-store');
  res.json({ success: true, data: { fileName: report.fileName.replace(/\.csv$/, '.pdf'), base64: pdf.toString('base64') } });
};

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
  getFinanceHomeReport,
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

export const getFinanceHomeReportHandler = async (req: Request, res: Response) => {
  const query = dashboardReportQuerySchema.parse(req.query);
  const report = await getFinanceHomeReport(req.authUser!, query);

  res.status(200).json({
    success: true,
    message: "Finance home report loaded successfully",
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
