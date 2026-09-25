import type { Request, Response } from "express";

import { env } from "../../config/env";
import {
  createPublicInquirySchema,
  listPublicInquiriesQuerySchema,
  publicInquiryParamsSchema,
  updatePublicInquiryStatusSchema,
} from "./public-inquiries.schemas";
import {
  createPublicInquiry,
  listTenantPublicInquiries,
  updateTenantPublicInquiryStatus,
} from "./public-inquiries.service";

export const createPublicInquiryHandler = async (req: Request, res: Response) => {
  const input = createPublicInquirySchema.parse(req.body);
  const record = await createPublicInquiry(env.PUBLIC_SITE_ORG_CODE, input);

  res.status(201).json({
    success: true,
    message: "Inquiry submitted successfully",
    data: record,
  });
};

export const listTenantPublicInquiriesHandler = async (req: Request, res: Response) => {
  const query = listPublicInquiriesQuerySchema.parse(req.query);
  const records = await listTenantPublicInquiries(req.authUser!, query);

  res.status(200).json({
    success: true,
    message: "Public inquiries loaded successfully",
    data: records,
  });
};

export const updateTenantPublicInquiryStatusHandler = async (req: Request, res: Response) => {
  const params = publicInquiryParamsSchema.parse(req.params);
  const input = updatePublicInquiryStatusSchema.parse(req.body);
  const record = await updateTenantPublicInquiryStatus(req.authUser!, params.id, input);

  res.status(200).json({
    success: true,
    message: "Public inquiry status updated successfully",
    data: record,
  });
};
