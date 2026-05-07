import { Router } from "express";

import { announcementsRouter } from "../modules/announcements/announcements.routes";
import { attendanceRouter } from "../modules/attendance/attendance.routes";
import { authRouter } from "../modules/auth/auth.routes";
import { classesRouter, enrollmentsRouter } from "../modules/classes/classes.routes";
import { expensesRouter, feeStructuresRouter, invoicesRouter } from "../modules/finance/finance.routes";
import { hifdhRouter } from "../modules/hifdh/hifdh.routes";
import { organizationsRouter } from "../modules/organizations/organizations.routes";
import { parentPortalRouter } from "../modules/parent-portal/parent-portal.routes";
import { paymentsRouter, webhooksRouter } from "../modules/payments/payments.routes";
import { guardiansRouter, studentsRouter } from "../modules/students/students.routes";
import { usersRouter } from "../modules/users/users.routes";
import { healthRouter } from "./health.route";

export const apiRouter = Router();

apiRouter.use("/health", healthRouter);
apiRouter.use("/announcements", announcementsRouter);
apiRouter.use("/attendance", attendanceRouter);
apiRouter.use("/auth", authRouter);
apiRouter.use("/organizations", organizationsRouter);
apiRouter.use("/hifdh-progress", hifdhRouter);
apiRouter.use("/users", usersRouter);
apiRouter.use("/parent-portal", parentPortalRouter);
apiRouter.use("/students", studentsRouter);
apiRouter.use("/guardians", guardiansRouter);
apiRouter.use("/classes", classesRouter);
apiRouter.use("/enrollments", enrollmentsRouter);
apiRouter.use("/fee-structures", feeStructuresRouter);
apiRouter.use("/invoices", invoicesRouter);
apiRouter.use("/expenses", expensesRouter);
apiRouter.use("/payments", paymentsRouter);
apiRouter.use("/webhooks", webhooksRouter);
