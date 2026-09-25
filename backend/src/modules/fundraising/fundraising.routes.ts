import { Router, type Request, type Response } from "express";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireRole } from "../../shared/middleware/require-role";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import { asyncHandler } from "../../shared/utils/async-handler";
import { jsonRecord } from "../../shared/utils/json-record";
import * as schema from "./fundraising.schemas";
import * as service from "./fundraising.service";

export const fundraisingRouter = Router();
fundraisingRouter.use(authenticate, requireTenantContext, requireRole("ADMIN"));
const handle = (fn: (req: Request) => Promise<unknown>, status = 200) =>
  asyncHandler(async (req: Request, res: Response) => {
    res.status(status).json({ success: true, data: jsonRecord(await fn(req)) });
  });

fundraisingRouter.get("/overview", handle((req) => service.fundraisingOverview(req.authUser!)));
fundraisingRouter.get("/donors", handle((req) => service.listDonors(req.authUser!, schema.directoryQuerySchema.parse(req.query))));
fundraisingRouter.post("/donors", handle((req) => service.createDonor(req.authUser!, schema.donorSchema.parse(req.body)), 201));
fundraisingRouter.get("/campaigns", handle((req) => service.listCampaigns(req.authUser!, schema.directoryQuerySchema.parse(req.query))));
fundraisingRouter.post("/campaigns", handle((req) => service.createCampaign(req.authUser!, schema.campaignSchema.parse(req.body)), 201));
fundraisingRouter.get("/pledges", handle((req) => service.listPledges(req.authUser!, schema.directoryQuerySchema.parse(req.query))));
fundraisingRouter.post("/pledges", handle((req) => service.createPledge(req.authUser!, schema.pledgeSchema.parse(req.body)), 201));
fundraisingRouter.get("/donations", handle((req) => service.listDonations(req.authUser!, schema.directoryQuerySchema.parse(req.query))));
fundraisingRouter.post("/donations", handle((req) => service.recordDonation(req.authUser!, schema.donationSchema.parse(req.body)), 201));
fundraisingRouter.get("/donations/:id/receipt", handle((req) => service.donationReceipt(req.authUser!, schema.recordId.parse(req.params.id))));
fundraisingRouter.post("/donations/:id/void", handle((req) => service.voidDonation(req.authUser!, schema.recordId.parse(req.params.id), schema.voidDonationSchema.parse(req.body).reason)));
