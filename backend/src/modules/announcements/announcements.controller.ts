import type { Request, Response } from "express";

import { announcementParamsSchema, createAnnouncementSchema, listAnnouncementsQuerySchema } from "./announcements.schemas";
import { createAnnouncement, getAnnouncementById, listAnnouncements } from "./announcements.service";

export const createAnnouncementHandler = async (req: Request, res: Response) => {
  const input = createAnnouncementSchema.parse(req.body);
  const record = await createAnnouncement(req.authUser!.orgId, req.authUser!.userId, input);

  res.status(201).json({
    success: true,
    message: "Announcement created successfully",
    data: record,
  });
};

export const listAnnouncementsHandler = async (req: Request, res: Response) => {
  const query = listAnnouncementsQuerySchema.parse(req.query);
  const records = await listAnnouncements(req.authUser!.orgId, query);

  res.status(200).json({
    success: true,
    message: "Announcements loaded successfully",
    data: records,
  });
};

export const getAnnouncementByIdHandler = async (req: Request, res: Response) => {
  const params = announcementParamsSchema.parse(req.params);
  const record = await getAnnouncementById(req.authUser!.orgId, params.id);

  res.status(200).json({
    success: true,
    message: "Announcement loaded successfully",
    data: record,
  });
};
