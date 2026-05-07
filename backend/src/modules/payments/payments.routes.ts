import { Router } from "express";

import { asyncHandler } from "../../shared/utils/async-handler";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireRole } from "../../shared/middleware/require-role";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import {
  getPaymentByIdHandler,
  getPaymentReceiptHandler,
  initiatePaymentHandler,
  listPaymentsHandler,
  reconcilePaymentHandler,
  snippeWebhookHandler,
} from "./payments.controller";

export const paymentsRouter = Router();
export const webhooksRouter = Router();

paymentsRouter.use(authenticate, requireTenantContext);

paymentsRouter.get("/", requireRole("ADMIN", "ACCOUNTANT"), asyncHandler(listPaymentsHandler));
paymentsRouter.post("/", requireRole("ADMIN", "ACCOUNTANT"), asyncHandler(initiatePaymentHandler));
paymentsRouter.get("/:id/receipt", requireRole("ADMIN", "ACCOUNTANT"), asyncHandler(getPaymentReceiptHandler));
paymentsRouter.post("/:id/reconcile", requireRole("ADMIN", "ACCOUNTANT"), asyncHandler(reconcilePaymentHandler));
paymentsRouter.get("/:id", requireRole("ADMIN", "ACCOUNTANT"), asyncHandler(getPaymentByIdHandler));
paymentsRouter.get("/status/:id", requireRole("ADMIN", "ACCOUNTANT"), asyncHandler(getPaymentByIdHandler));

webhooksRouter.post("/snippe", asyncHandler(snippeWebhookHandler));
