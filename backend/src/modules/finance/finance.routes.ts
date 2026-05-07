import { Router } from "express";

import { asyncHandler } from "../../shared/utils/async-handler";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireRole } from "../../shared/middleware/require-role";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import {
  createExpenseHandler,
  createFeeStructureHandler,
  createInvoiceHandler,
  listExpensesHandler,
  listFeeStructuresHandler,
  listInvoicesHandler,
} from "./finance.controller";

export const feeStructuresRouter = Router();
export const invoicesRouter = Router();
export const expensesRouter = Router();

feeStructuresRouter.use(authenticate, requireTenantContext);
invoicesRouter.use(authenticate, requireTenantContext);
expensesRouter.use(authenticate, requireTenantContext);

feeStructuresRouter.get("/", requireRole("ADMIN", "ACCOUNTANT"), asyncHandler(listFeeStructuresHandler));
feeStructuresRouter.post("/", requireRole("ADMIN", "ACCOUNTANT"), asyncHandler(createFeeStructureHandler));

invoicesRouter.get("/", requireRole("ADMIN", "ACCOUNTANT"), asyncHandler(listInvoicesHandler));
invoicesRouter.post("/", requireRole("ADMIN", "ACCOUNTANT"), asyncHandler(createInvoiceHandler));

expensesRouter.get("/", requireRole("ADMIN", "ACCOUNTANT"), asyncHandler(listExpensesHandler));
expensesRouter.post("/", requireRole("ADMIN", "ACCOUNTANT"), asyncHandler(createExpenseHandler));

