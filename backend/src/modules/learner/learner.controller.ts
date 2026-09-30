import type { Request, Response } from "express";

import {
  learnerContentId,
  initiateLearnerCoursePaymentSchema,
  learnerAttendanceQuerySchema,
  updateLearnerLessonProgressSchema,
} from "./learner.schemas";
import {
  getLearnerAttendance,
  initiateLearnerCoursePayment,
  openLearnerAsset,
  getLearnerCourseDetail,
  getLearnerFinance,
  getLearnerHifdh,
  getLearnerLessonDetail,
  listLearnerProgress,
  getLearnerProfile,
  getLearnerReceipts,
  listLearnerCourses,
  listLearnerAnnouncements,
  resolveLearnerAssetDelivery,
  updateLearnerLessonProgress,
} from "./learner.service";

export const getLearnerProfileHandler = async (req: Request, res: Response) => {
  const profile = await getLearnerProfile(req.authUser!);

  res.status(200).json({
    success: true,
    message: "Learner profile loaded successfully",
    data: profile,
  });
};

export const listLearnerCoursesHandler = async (req: Request, res: Response) => {
  const courses = await listLearnerCourses(req.authUser!);

  res.status(200).json({
    success: true,
    message: "Learner courses loaded successfully",
    data: courses,
  });
};

export const getLearnerCourseDetailHandler = async (req: Request, res: Response) => {
  const courseId = learnerContentId.parse(req.params.courseId);
  const detail = await getLearnerCourseDetail(req.authUser!, courseId!);

  res.status(200).json({
    success: true,
    message: "Learner course loaded successfully",
    data: detail,
  });
};

export const initiateLearnerCoursePaymentHandler = async (req: Request, res: Response) => {
  const invoiceId = req.params.invoiceId;
  const input = initiateLearnerCoursePaymentSchema.parse(req.body);
  const payment = await initiateLearnerCoursePayment(req.authUser!, invoiceId!, input, req.ip);

  res.status(201).json({
    success: true,
    message: "Course payment request submitted",
    data: payment,
  });
};

export const getLearnerLessonDetailHandler = async (req: Request, res: Response) => {
  const lessonId = learnerContentId.parse(req.params.lessonId);
  const detail = await getLearnerLessonDetail(req.authUser!, lessonId!);

  res.status(200).json({
    success: true,
    message: "Learner lesson loaded successfully",
    data: detail,
  });
};

export const listLearnerProgressHandler = async (req: Request, res: Response) => {
  const detail = await listLearnerProgress(req.authUser!);

  res.status(200).json({
    success: true,
    message: "Learner progress loaded successfully",
    data: detail,
  });
};

export const updateLearnerLessonProgressHandler = async (req: Request, res: Response) => {
  const lessonId = learnerContentId.parse(req.params.lessonId);
  const input = updateLearnerLessonProgressSchema.parse(req.body);
  const detail = await updateLearnerLessonProgress(req.authUser!, lessonId!, input);

  res.status(200).json({
    success: true,
    message: "Learner progress updated successfully",
    data: detail,
  });
};

export const openLearnerAssetHandler = async (req: Request, res: Response) => {
  const assetId = learnerContentId.parse(req.params.assetId);
  const detail = await openLearnerAsset(req.authUser!, assetId!);
  const baseUrl = `${req.protocol}://${req.get("host")}`;
  const inlineUrl =
    detail.delivery.inlineUrl && detail.delivery.inlineUrl.startsWith("/")
      ? new URL(detail.delivery.inlineUrl, baseUrl).toString()
      : detail.delivery.inlineUrl;
  const downloadUrl =
    detail.delivery.downloadUrl && detail.delivery.downloadUrl.startsWith("/")
      ? new URL(detail.delivery.downloadUrl, baseUrl).toString()
      : detail.delivery.downloadUrl;

  res.status(200).json({
    success: true,
    message: "Learner lesson item prepared successfully",
    data: {
      ...detail,
      delivery: {
        ...detail.delivery,
        inlineUrl,
        downloadUrl,
      },
    },
  });
};

export const deliverLearnerAssetHandler = async (req: Request, res: Response) => {
  const assetId = learnerContentId.parse(req.params.assetId);
  const token = typeof req.query.token === "string" ? req.query.token : "";
  const detail = await resolveLearnerAssetDelivery(assetId!, token);

  // The signed redirect is intentionally consumable by the separate web origin.
  res.setHeader("Cross-Origin-Resource-Policy", "cross-origin");
  res.setHeader("Referrer-Policy", "strict-origin");
  res.redirect(302, detail.redirectUrl);
};

export const getLearnerAttendanceHandler = async (req: Request, res: Response) => {
  const query = learnerAttendanceQuerySchema.parse(req.query);
  const records = await getLearnerAttendance(req.authUser!, query);

  res.status(200).json({
    success: true,
    message: "Learner attendance loaded successfully",
    data: records,
  });
};

export const getLearnerFinanceHandler = async (req: Request, res: Response) => {
  const finance = await getLearnerFinance(req.authUser!);

  res.status(200).json({
    success: true,
    message: "Learner finance loaded successfully",
    data: finance,
  });
};

export const getLearnerReceiptsHandler = async (req: Request, res: Response) => {
  const receipts = await getLearnerReceipts(req.authUser!);

  res.status(200).json({
    success: true,
    message: "Learner receipts loaded successfully",
    data: receipts,
  });
};

export const getLearnerHifdhHandler = async (req: Request, res: Response) => {
  const records = await getLearnerHifdh(req.authUser!);

  res.status(200).json({
    success: true,
    message: "Learner hifdh loaded successfully",
    data: records,
  });
};

export const listLearnerAnnouncementsHandler = async (req: Request, res: Response) => {
  const announcements = await listLearnerAnnouncements(req.authUser!);

  res.status(200).json({
    success: true,
    message: "Learner announcements loaded successfully",
    data: announcements,
  });
};
