import type { Request, Response } from "express";

import { HttpError } from "../../shared/errors/http-error";
import {
  createClassSchema,
  createEnrollmentSchema,
  listClassesQuerySchema,
  listEnrollmentsQuerySchema,
} from "./classes.schemas";
import {
  createClass,
  createEnrollment,
  getClassById,
  listClasses,
  listEnrollments,
} from "./classes.service";

export const createClassHandler = async (req: Request, res: Response) => {
  const input = createClassSchema.parse(req.body);
  const classRecord = await createClass(req.authUser!.orgId, input);

  res.status(201).json({
    success: true,
    message: "Class created successfully",
    data: classRecord,
  });
};

export const listClassesHandler = async (req: Request, res: Response) => {
  const query = listClassesQuerySchema.parse(req.query);
  const classes = await listClasses(req.authUser!.orgId, query);

  res.status(200).json({
    success: true,
    message: "Classes loaded successfully",
    data: classes,
  });
};

export const getClassByIdHandler = async (req: Request, res: Response) => {
  const classId = req.params.id;

  if (!classId) {
    throw new HttpError(400, "Class id parameter is required");
  }

  const classRecord = await getClassById(req.authUser!.orgId, classId);

  res.status(200).json({
    success: true,
    message: "Class loaded successfully",
    data: classRecord,
  });
};

export const createEnrollmentHandler = async (req: Request, res: Response) => {
  const input = createEnrollmentSchema.parse(req.body);
  const enrollment = await createEnrollment(req.authUser!.orgId, input);

  res.status(201).json({
    success: true,
    message: "Enrollment created successfully",
    data: enrollment,
  });
};

export const listEnrollmentsHandler = async (req: Request, res: Response) => {
  const query = listEnrollmentsQuerySchema.parse(req.query);
  const enrollments = await listEnrollments(req.authUser!.orgId, query);

  res.status(200).json({
    success: true,
    message: "Enrollments loaded successfully",
    data: enrollments,
  });
};

