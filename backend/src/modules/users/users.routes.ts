import { Router } from "express";

import { asyncHandler } from "../../shared/utils/async-handler";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireRole } from "../../shared/middleware/require-role";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import { createUserHandler, listUsersHandler } from "./users.controller";

export const usersRouter = Router();

usersRouter.use(authenticate, requireTenantContext);

usersRouter.get("/", requireRole("ADMIN"), asyncHandler(listUsersHandler));
usersRouter.post("/", requireRole("ADMIN"), asyncHandler(createUserHandler));

