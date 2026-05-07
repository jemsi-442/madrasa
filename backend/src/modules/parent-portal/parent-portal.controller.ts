import type { Request, Response } from "express";

import { HttpError } from "../../shared/errors/http-error";
import {
  getParentPortalProfile,
  getParentStudentHifdhProgress,
  getParentStudentPaymentById,
  getParentStudentPaymentReceipt,
  getParentStudentAttendance,
  getParentStudentFinance,
  initiateParentStudentPayment,
  listParentAnnouncements,
  listParentStudents,
} from "./parent-portal.service";
import {
  initiateParentPaymentSchema,
  parentPaymentParamsSchema,
  parentStudentAttendanceQuerySchema,
  parentStudentParamsSchema,
} from "./parent-portal.schemas";

export const getParentProfileHandler = async (req: Request, res: Response) => {
  const profile = await getParentPortalProfile(req.authUser!.orgId, req.authUser!.userId);

  res.status(200).json({
    success: true,
    message: "Parent profile loaded successfully",
    data: profile,
  });
};

export const listParentStudentsHandler = async (req: Request, res: Response) => {
  const students = await listParentStudents(req.authUser!.orgId, req.authUser!.userId);

  res.status(200).json({
    success: true,
    message: "Parent students loaded successfully",
    data: students,
  });
};

export const getParentStudentAttendanceHandler = async (req: Request, res: Response) => {
  const params = parentStudentParamsSchema.parse(req.params);
  const query = parentStudentAttendanceQuerySchema.parse(req.query);
  const attendance = await getParentStudentAttendance(
    req.authUser!.orgId,
    req.authUser!.userId,
    params.studentId,
    query,
  );

  res.status(200).json({
    success: true,
    message: "Student attendance loaded successfully",
    data: attendance,
  });
};

export const getParentStudentFinanceHandler = async (req: Request, res: Response) => {
  const params = parentStudentParamsSchema.parse(req.params);

  if (!params.studentId) {
    throw new HttpError(400, "Student id parameter is required");
  }

  const finance = await getParentStudentFinance(req.authUser!.orgId, req.authUser!.userId, params.studentId);

  res.status(200).json({
    success: true,
    message: "Student finance loaded successfully",
    data: finance,
  });
};

export const getParentStudentHifdhHandler = async (req: Request, res: Response) => {
  const params = parentStudentParamsSchema.parse(req.params);
  const records = await getParentStudentHifdhProgress(req.authUser!.orgId, req.authUser!.userId, params.studentId);

  res.status(200).json({
    success: true,
    message: "Student hifdh progress loaded successfully",
    data: records,
  });
};

export const initiateParentStudentPaymentHandler = async (req: Request, res: Response) => {
  const params = parentStudentParamsSchema.parse(req.params);
  const input = initiateParentPaymentSchema.parse(req.body);
  const payment = await initiateParentStudentPayment(
    req.authUser!.orgId,
    req.authUser!.userId,
    params.studentId,
    input,
    req.ip,
  );

  res.status(201).json({
    success: true,
    message: "Parent payment request submitted",
    data: payment,
  });
};

export const getParentStudentPaymentHandler = async (req: Request, res: Response) => {
  const params = parentPaymentParamsSchema.parse(req.params);
  const payment = await getParentStudentPaymentById(
    req.authUser!.orgId,
    req.authUser!.userId,
    params.studentId,
    params.paymentId,
  );

  res.status(200).json({
    success: true,
    message: "Student payment loaded successfully",
    data: payment,
  });
};

export const getParentStudentPaymentReceiptHandler = async (req: Request, res: Response) => {
  const params = parentPaymentParamsSchema.parse(req.params);
  const receipt = await getParentStudentPaymentReceipt(
    req.authUser!.orgId,
    req.authUser!.userId,
    params.studentId,
    params.paymentId,
  );

  res.status(200).json({
    success: true,
    message: "Student payment receipt loaded successfully",
    data: receipt,
  });
};

export const listParentAnnouncementsHandler = async (req: Request, res: Response) => {
  const announcements = await listParentAnnouncements(req.authUser!.orgId, req.authUser!.userId);

  res.status(200).json({
    success: true,
    message: "Parent announcements loaded successfully",
    data: announcements,
  });
};
