import { Router } from "express";

import { listPublicAnnouncementsHandler } from "../modules/announcements/announcements.controller";
import { createPublicInquiryHandler } from "../modules/public-inquiries/public-inquiries.controller";
import { asyncHandler } from "../shared/utils/async-handler";

export const publicRouter = Router();

publicRouter.get("/announcements", asyncHandler(listPublicAnnouncementsHandler));
publicRouter.post("/inquiries", asyncHandler(createPublicInquiryHandler));
