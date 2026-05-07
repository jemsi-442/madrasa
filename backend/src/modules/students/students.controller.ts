import type { Request, Response } from "express";

import {
  createGuardianSchema,
  createStudentSchema,
  linkGuardianSchema,
  listStudentsQuerySchema,
  setPrimaryGuardianSchema,
  studentGuardianParamsSchema,
  studentIdParamsSchema,
  updateStudentSchema,
} from "./students.schemas";
import {
  createGuardian,
  createStudent,
  getStudentById,
  linkGuardianToStudent,
  listGuardians,
  listStudents,
  setPrimaryGuardian,
  unlinkGuardianFromStudent,
  updateStudent,
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
  const params = studentIdParamsSchema.parse(req.params);
  const student = await getStudentById(req.authUser!.orgId, params.id);

  res.status(200).json({
    success: true,
    message: "Student loaded successfully",
    data: student,
  });
};

export const updateStudentHandler = async (req: Request, res: Response) => {
  const params = studentIdParamsSchema.parse(req.params);
  const input = updateStudentSchema.parse(req.body);
  const student = await updateStudent(req.authUser!.orgId, params.id, input);

  res.status(200).json({
    success: true,
    message: "Student updated successfully",
    data: student,
  });
};

export const linkGuardianToStudentHandler = async (req: Request, res: Response) => {
  const params = studentIdParamsSchema.parse(req.params);
  const input = linkGuardianSchema.parse(req.body);
  const student = await linkGuardianToStudent(req.authUser!.orgId, params.id, input);

  res.status(201).json({
    success: true,
    message: "Guardian linked to student successfully",
    data: student,
  });
};

export const setPrimaryGuardianHandler = async (req: Request, res: Response) => {
  const params = studentIdParamsSchema.parse(req.params);
  const input = setPrimaryGuardianSchema.parse(req.body);
  const student = await setPrimaryGuardian(req.authUser!.orgId, params.id, input);

  res.status(200).json({
    success: true,
    message: "Primary guardian updated successfully",
    data: student,
  });
};

export const unlinkGuardianFromStudentHandler = async (req: Request, res: Response) => {
  const params = studentGuardianParamsSchema.parse(req.params);
  const student = await unlinkGuardianFromStudent(req.authUser!.orgId, params.id, params.guardianId);

  res.status(200).json({
    success: true,
    message: "Guardian unlinked from student successfully",
    data: student,
  });
};
