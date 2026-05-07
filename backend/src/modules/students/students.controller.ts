import type { Request, Response } from "express";

import { HttpError } from "../../shared/errors/http-error";
import {
  createGuardianSchema,
  createStudentSchema,
  listStudentsQuerySchema,
} from "./students.schemas";
import {
  createGuardian,
  createStudent,
  getStudentById,
  listGuardians,
  listStudents,
} from "./students.service";

export const createGuardianHandler = async (req: Request, res: Response) => {
  const input = createGuardianSchema.parse(req.body);
  const guardian = await createGuardian(req.authUser!.orgId, input);

  res.status(201).json({
    success: true,
    message: "Guardian created successfully",
    data: guardian,
  });
};

export const listGuardiansHandler = async (req: Request, res: Response) => {
  const guardians = await listGuardians(req.authUser!.orgId);

  res.status(200).json({
    success: true,
    message: "Guardians loaded successfully",
    data: guardians,
  });
};

export const createStudentHandler = async (req: Request, res: Response) => {
  const input = createStudentSchema.parse(req.body);
  const student = await createStudent(req.authUser!.orgId, input);

  res.status(201).json({
    success: true,
    message: "Student created successfully",
    data: student,
  });
};

export const listStudentsHandler = async (req: Request, res: Response) => {
  const query = listStudentsQuerySchema.parse(req.query);
  const students = await listStudents(req.authUser!.orgId, query);

  res.status(200).json({
    success: true,
    message: "Students loaded successfully",
    data: students,
  });
};

export const getStudentByIdHandler = async (req: Request, res: Response) => {
  const studentId = req.params.id;

  if (!studentId) {
    throw new HttpError(400, "Student id parameter is required");
  }

  const student = await getStudentById(req.authUser!.orgId, studentId);

  res.status(200).json({
    success: true,
    message: "Student loaded successfully",
    data: student,
  });
};
