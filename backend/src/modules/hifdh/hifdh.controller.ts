import type { Request, Response } from "express";

import { createHifdhProgressSchema, hifdhProgressParamsSchema, listHifdhProgressQuerySchema } from "./hifdh.schemas";
import { createHifdhProgress, getHifdhProgressById, listHifdhProgress } from "./hifdh.service";

export const createHifdhProgressHandler = async (req: Request, res: Response) => {
  const input = createHifdhProgressSchema.parse(req.body);
  const record = await createHifdhProgress(req.authUser!, input);

  res.status(201).json({
    success: true,
    message: "Hifdh progress recorded successfully",
    data: record,
  });
};

export const listHifdhProgressHandler = async (req: Request, res: Response) => {
  const query = listHifdhProgressQuerySchema.parse(req.query);
  const records = await listHifdhProgress(req.authUser!, query);

  res.status(200).json({
    success: true,
    message: "Hifdh progress loaded successfully",
    data: records,
  });
};

export const getHifdhProgressByIdHandler = async (req: Request, res: Response) => {
  const params = hifdhProgressParamsSchema.parse(req.params);
  const record = await getHifdhProgressById(req.authUser!, params.id);

  res.status(200).json({
    success: true,
    message: "Hifdh progress record loaded successfully",
    data: record,
  });
};
