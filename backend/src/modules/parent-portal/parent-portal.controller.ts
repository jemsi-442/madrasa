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
  resolveParentPortalUserId,
} from "./parent-portal.service";
import {
  initiateParentPaymentSchema,
  parentPortalActorQuerySchema,
  parentPaymentParamsSchema,
  parentStudentAttendanceQuerySchema,
  parentStudentParamsSchema,
} from "./parent-portal.schemas";

export const getParentProfileHandler = async (req: Request, res: Response) => {
  const query = parentPortalActorQuerySchema.parse(req.query);
  const targetParentUserId = resolveParentPortalUserId(req.authUser!, query.parentUserId);
  const profile = await getParentPortalProfile(req.authUser!.orgId, targetParentUserId);

  res.status(200).json({
    success: true,
    message: "Parent profile loaded successfully",
    data: profile,
  });
};

export const listParentStudentsHandler = async (req: Request, res: Response) => {
  const query = parentPortalActorQuerySchema.parse(req.query);
  const targetParentUserId = resolveParentPortalUserId(req.authUser!, query.parentUserId);
  const students = await listParentStudents(req.authUser!.orgId, targetParentUserId);

  res.status(200).json({
    success: true,
    message: "Parent students loaded successfully",
    data: students,
  });
};

export const getParentStudentAttendanceHandler = async (req: Request, res: Response) => {
  const params = parentStudentParamsSchema.parse(req.params);
  const query = parentStudentAttendanceQuerySchema.parse(req.query);
  const targetParentUserId = resolveParentPortalUserId(req.authUser!, query.parentUserId);
  const attendance = await getParentStudentAttendance(
    req.authUser!.orgId,
    targetParentUserId,
    params.studentId,
    {
      dateFrom: query.dateFrom,
      dateTo: query.dateTo,
    },
  );

  res.status(200).json({
    success: true,
    message: "Student attendance loaded successfully",
    data: attendance,
  });
};

export const getParentStudentFinanceHandler = async (req: Request, res: Response) => {
  const params = parentStudentParamsSchema.parse(req.params);
  const query = parentPortalActorQuerySchema.parse(req.query);

  if (!params.studentId) {
    throw new HttpError(400, "Student id parameter is required");
  }

  const targetParentUserId = resolveParentPortalUserId(req.authUser!, query.parentUserId);
  const finance = await getParentStudentFinance(req.authUser!.orgId, targetParentUserId, params.studentId);

  res.status(200).json({
    success: true,
    message: "Student finance loaded successfully",
    data: finance,
  });
};

export const getParentStudentHifdhHandler = async (req: Request, res: Response) => {
  const params = parentStudentParamsSchema.parse(req.params);
  const query = parentPortalActorQuerySchema.parse(req.query);
  const targetParentUserId = resolveParentPortalUserId(req.authUser!, query.parentUserId);
  const records = await getParentStudentHifdhProgress(req.authUser!.orgId, targetParentUserId, params.studentId);

  res.status(200).json({
    success: true,
    message: "Student hifdh progress loaded successfully",
    data: records,
  });
};

export const initiateParentStudentPaymentHandler = async (req: Request, res: Response) => {
  const params = parentStudentParamsSchema.parse(req.params);
  const query = parentPortalActorQuerySchema.parse(req.query);
  const input = initiateParentPaymentSchema.parse(req.body);
  const targetParentUserId = resolveParentPortalUserId(req.authUser!, query.parentUserId);
  const payment = await initiateParentStudentPayment(
    req.authUser!.orgId,
    targetParentUserId,
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
  const query = parentPortalActorQuerySchema.parse(req.query);
  const targetParentUserId = resolveParentPortalUserId(req.authUser!, query.parentUserId);
  const payment = await getParentStudentPaymentById(
    req.authUser!.orgId,
    targetParentUserId,
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
  const query = parentPortalActorQuerySchema.parse(req.query);
  const targetParentUserId = resolveParentPortalUserId(req.authUser!, query.parentUserId);
  const receipt = await getParentStudentPaymentReceipt(
    req.authUser!.orgId,
    targetParentUserId,
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
  const query = parentPortalActorQuerySchema.parse(req.query);
  const targetParentUserId = resolveParentPortalUserId(req.authUser!, query.parentUserId);
  const announcements = await listParentAnnouncements(req.authUser!.orgId, targetParentUserId);

  res.status(200).json({
    success: true,
    message: "Parent announcements loaded successfully",
    data: announcements,
  });
};
