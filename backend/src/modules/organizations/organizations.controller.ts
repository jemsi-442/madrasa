import type { Request, Response } from "express";

import { getOrganizationProfile } from "./organizations.service";

export const getMyOrganizationHandler = async (req: Request, res: Response) => {
  const organization = await getOrganizationProfile(req.authUser!.orgId);

  res.status(200).json({
    success: true,
    message: "Organization profile loaded",
    data: organization,
  });
};

