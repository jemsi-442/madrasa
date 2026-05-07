import cors from "cors";
import express from "express";
import helmet from "helmet";
import morgan from "morgan";

import { env } from "../config/env";
import { apiRouter } from "../routes";
import { errorHandler } from "../shared/middleware/error-handler";
import { notFoundHandler } from "../shared/middleware/not-found";

export const createApp = () => {
  const app = express();

  app.disable("x-powered-by");

  app.use(helmet());
  app.use(cors());
  app.use(morgan(env.NODE_ENV === "production" ? "combined" : "dev"));

  // Snippe webhook signature verification depends on the exact raw body.
  app.use("/api/webhooks/snippe", express.raw({ type: "*/*" }));
  app.use(express.json());
  app.use(express.urlencoded({ extended: true }));

  app.get("/", (_req, res) => {
    res.json({
      success: true,
      message: "MMS backend is running",
      data: {
        app: env.APP_NAME,
        env: env.NODE_ENV,
      },
    });
  });

  app.use("/api", apiRouter);
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
};
