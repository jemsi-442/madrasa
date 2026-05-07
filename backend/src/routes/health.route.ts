import { Router } from "express";

import { env } from "../config/env";

export const healthRouter = Router();

healthRouter.get("/", (_req, res) => {
  res.status(200).json({
    success: true,
    message: "Service healthy",
    data: {
      app: env.APP_NAME,
      env: env.NODE_ENV,
      timezone: env.TZ,
      timestamp: new Date().toISOString(),
    },
  });
});

