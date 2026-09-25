import type { Request, Response } from "express";

import { HttpError } from "../../shared/errors/http-error";
import {
  createCourseAccessGrantSchema,
  createCourseAccessRequestSchema,
  createCourseSchema,
  createCourseLessonSchema,
  createCourseModuleSchema,
  createLessonAssetSchema,
  createSubjectSchema,
  listCourseAccessRequestsQuerySchema,
  listCoursesQuerySchema,
  listSubjectsQuerySchema,
  updateCourseAccessRequestStatusSchema,
  updateCourseLessonSchema,
  updateCourseModuleSchema,
  updateCourseSchema,
  updateLessonAssetSchema,
} from "./learning.schemas";
import {
  createCourseAccessGrant,
  createCourseAccessRequest,
  createCourse,
  createCourseLesson,
  createCourseModule,
  createLessonAsset,
  createSubject,
  listCourseAccessRequests,
  listCourseLessons,
  listCourseModules,
  listLessonAssets,
  listCourses,
  listSubjects,
  updateCourseAccessRequestStatus,
  updateCourseLesson,
  updateCourseModule,
  updateCourse,
  updateLessonAsset,
} from "./learning.service";

export const createSubjectHandler = async (req: Request, res: Response) => {
  const input = createSubjectSchema.parse(req.body);
  const subject = await createSubject(req.authUser!, input);

  res.status(201).json({
    success: true,
    message: "Subject created successfully",
    data: subject,
  });
};

export const listSubjectsHandler = async (req: Request, res: Response) => {
  const query = listSubjectsQuerySchema.parse(req.query);
  const subjects = await listSubjects(req.authUser!, query);

  res.status(200).json({
    success: true,
    message: "Subjects loaded successfully",
    data: subjects,
  });
};

export const createCourseHandler = async (req: Request, res: Response) => {
  const input = createCourseSchema.parse(req.body);
  const course = await createCourse(req.authUser!, input);

  res.status(201).json({
    success: true,
    message: "Course created successfully",
    data: course,
  });
};

export const createCourseAccessGrantHandler = async (req: Request, res: Response) => {
  const courseId = req.params.id;

  if (!courseId) {
    throw new HttpError(400, "Course id parameter is required");
  }

  const input = createCourseAccessGrantSchema.parse(req.body);
  const grant = await createCourseAccessGrant(req.authUser!, courseId, input);

  res.status(201).json({
    success: true,
    message: "Course access granted successfully",
    data: grant,
  });
};

export const createCourseAccessRequestHandler = async (req: Request, res: Response) => {
  const courseId = req.params.id;

  if (!courseId) {
    throw new HttpError(400, "Course id parameter is required");
  }

  const input = createCourseAccessRequestSchema.parse(req.body);
  const request = await createCourseAccessRequest(req.authUser!, courseId, input);

  res.status(201).json({
    success: true,
    message: "Course access request submitted successfully",
    data: request,
  });
};

export const updateCourseHandler = async (req: Request, res: Response) => {
  const courseId = req.params.id;

  if (!courseId) {
    throw new HttpError(400, "Course id parameter is required");
  }

  const input = updateCourseSchema.parse(req.body);
  const course = await updateCourse(req.authUser!, courseId, input);

  res.status(200).json({
    success: true,
    message: "Course updated successfully",
    data: course,
  });
};

export const listCoursesHandler = async (req: Request, res: Response) => {
  const query = listCoursesQuerySchema.parse(req.query);
  const courses = await listCourses(req.authUser!, query);

  res.status(200).json({
    success: true,
    message: "Courses loaded successfully",
    data: courses,
  });
};

export const listCourseAccessRequestsHandler = async (req: Request, res: Response) => {
  const query = listCourseAccessRequestsQuerySchema.parse(req.query);
  const requests = await listCourseAccessRequests(req.authUser!, query);

  res.status(200).json({
    success: true,
    message: "Course access requests loaded successfully",
    data: requests,
  });
};

export const updateCourseAccessRequestStatusHandler = async (req: Request, res: Response) => {
  const requestId = req.params.id;

  if (!requestId) {
    throw new HttpError(400, "Course access request id parameter is required");
  }

  const input = updateCourseAccessRequestStatusSchema.parse(req.body);
  const request = await updateCourseAccessRequestStatus(req.authUser!, requestId, input);

  res.status(200).json({
    success: true,
    message: "Course access request status updated successfully",
    data: request,
  });
};

export const createCourseModuleHandler = async (req: Request, res: Response) => {
  const courseId = req.params.id;

  if (!courseId) {
    throw new HttpError(400, "Course id parameter is required");
  }

  const input = createCourseModuleSchema.parse(req.body);
  const moduleRecord = await createCourseModule(req.authUser!, courseId, input);

  res.status(201).json({
    success: true,
    message: "Course module created successfully",
    data: moduleRecord,
  });
};

export const listCourseModulesHandler = async (req: Request, res: Response) => {
  const courseId = req.params.id;

  if (!courseId) {
    throw new HttpError(400, "Course id parameter is required");
  }

  const modules = await listCourseModules(req.authUser!, courseId);

  res.status(200).json({
    success: true,
    message: "Course modules loaded successfully",
    data: modules,
  });
};

export const updateCourseModuleHandler = async (req: Request, res: Response) => {
  const moduleId = req.params.moduleId;

  if (!moduleId) {
    throw new HttpError(400, "Module id parameter is required");
  }

  const input = updateCourseModuleSchema.parse(req.body);
  const moduleRecord = await updateCourseModule(req.authUser!, moduleId, input);

  res.status(200).json({
    success: true,
    message: "Course module updated successfully",
    data: moduleRecord,
  });
};

export const createCourseLessonHandler = async (req: Request, res: Response) => {
  const moduleId = req.params.moduleId;

  if (!moduleId) {
    throw new HttpError(400, "Module id parameter is required");
  }

  const input = createCourseLessonSchema.parse(req.body);
  const lesson = await createCourseLesson(req.authUser!, moduleId, input);

  res.status(201).json({
    success: true,
    message: "Course lesson created successfully",
    data: lesson,
  });
};

export const listCourseLessonsHandler = async (req: Request, res: Response) => {
  const moduleId = req.params.moduleId;

  if (!moduleId) {
    throw new HttpError(400, "Module id parameter is required");
  }

  const lessons = await listCourseLessons(req.authUser!, moduleId);

  res.status(200).json({
    success: true,
    message: "Course lessons loaded successfully",
    data: lessons,
  });
};

export const updateCourseLessonHandler = async (req: Request, res: Response) => {
  const lessonId = req.params.lessonId;

  if (!lessonId) {
    throw new HttpError(400, "Lesson id parameter is required");
  }

  const input = updateCourseLessonSchema.parse(req.body);
  const lesson = await updateCourseLesson(req.authUser!, lessonId, input);

  res.status(200).json({
    success: true,
    message: "Course lesson updated successfully",
    data: lesson,
  });
};

export const createLessonAssetHandler = async (req: Request, res: Response) => {
  const lessonId = req.params.lessonId;

  if (!lessonId) {
    throw new HttpError(400, "Lesson id parameter is required");
  }

  const input = createLessonAssetSchema.parse(req.body);
  const asset = await createLessonAsset(req.authUser!, lessonId, input);

  res.status(201).json({
    success: true,
    message: "Lesson asset created successfully",
    data: asset,
  });
};

export const listLessonAssetsHandler = async (req: Request, res: Response) => {
  const lessonId = req.params.lessonId;

  if (!lessonId) {
    throw new HttpError(400, "Lesson id parameter is required");
  }

  const assets = await listLessonAssets(req.authUser!, lessonId);

  res.status(200).json({
    success: true,
    message: "Lesson assets loaded successfully",
    data: assets,
  });
};

export const updateLessonAssetHandler = async (req: Request, res: Response) => {
  const assetId = req.params.assetId;

  if (!assetId) {
    throw new HttpError(400, "Asset id parameter is required");
  }

  const input = updateLessonAssetSchema.parse(req.body);
  const asset = await updateLessonAsset(req.authUser!, assetId, input);

  res.status(200).json({
    success: true,
    message: "Lesson asset updated successfully",
    data: asset,
  });
};
