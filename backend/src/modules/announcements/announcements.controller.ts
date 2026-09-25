import type { Request, Response } from "express";

import {
  announcementParamsSchema,
  createAnnouncementSchema,
  listAnnouncementsQuerySchema,
  listPublicAnnouncementsQuerySchema,
} from "./announcements.schemas";
import {
  createAnnouncement,
  getAnnouncementById,
  listAnnouncements,
  listPublicAnnouncements,
} from "./announcements.service";

export const createAnnouncementHandler = async (req: Request, res: Response) => {
  const input = createAnnouncementSchema.parse(req.body);
  const record = await createAnnouncement(req.authUser!, input);

  res.status(201).json({
    success: true,
    message: "Announcement created successfully",
    data: record,
  });
};

export const listAnnouncementsHandler = async (req: Request, res: Response) => {
  const query = listAnnouncementsQuerySchema.parse(req.query);
  const records = await listAnnouncements(req.authUser!, query);

  res.status(200).json({
    success: true,
    message: "Announcements loaded successfully",
    data: records,
  });
};

export const getAnnouncementByIdHandler = async (req: Request, res: Response) => {
  const params = announcementParamsSchema.parse(req.params);
  const record = await getAnnouncementById(req.authUser!, params.id);

  res.status(200).json({
    success: true,
    message: "Announcement loaded successfully",
    data: record,
  });
};

export const listPublicAnnouncementsHandler = async (req: Request, res: Response) => {
  const query = listPublicAnnouncementsQuerySchema.parse(req.query);
  const records = await listPublicAnnouncements(query);

  res.status(200).json({
    success: true,
    message: "Public announcements loaded successfully",
    data: records,
  });
};
