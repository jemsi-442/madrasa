import type { Request, Response } from "express";

import { HttpError } from "../../shared/errors/http-error";
import {
  bulkMarkAttendanceSchema,
  classAttendanceQuerySchema,
  studentAttendanceQuerySchema,
} from "./attendance.schemas";
import {
  bulkMarkAttendance,
  getClassAttendance,
  getStudentAttendance,
} from "./attendance.service";

export const bulkMarkAttendanceHandler = async (req: Request, res: Response) => {
  const input = bulkMarkAttendanceSchema.parse(req.body);
  const result = await bulkMarkAttendance(req.authUser!, input);

  res.status(200).json({
    success: true,
    message: "Attendance saved successfully",
    data: result,
  });
};

export const getClassAttendanceHandler = async (req: Request, res: Response) => {
  const classId = req.params.classId;

  if (!classId) {
    throw new HttpError(400, "classId parameter is required");
  }

  const query = classAttendanceQuerySchema.parse(req.query);
  const result = await getClassAttendance(req.authUser!, classId, query);

  res.status(200).json({
    success: true,
    message: "Class attendance loaded successfully",
    data: result,
  });
};

export const getStudentAttendanceHandler = async (req: Request, res: Response) => {
  const studentId = req.params.studentId;

  if (!studentId) {
    throw new HttpError(400, "studentId parameter is required");
  }

  const query = studentAttendanceQuerySchema.parse(req.query);
  const result = await getStudentAttendance(req.authUser!, studentId, query);

  res.status(200).json({
    success: true,
    message: "Student attendance loaded successfully",
    data: result,
  });
};
