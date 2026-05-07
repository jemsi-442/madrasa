import type { Request, Response } from "express";

import { createUserSchema, listUsersQuerySchema } from "./users.schemas";
import { createUser, listUsers } from "./users.service";

export const createUserHandler = async (req: Request, res: Response) => {
  const input = createUserSchema.parse(req.body);
  const user = await createUser(req.authUser!.orgId, input);

  res.status(201).json({
    success: true,
    message: "User created successfully",
    data: user,
  });
};

export const listUsersHandler = async (req: Request, res: Response) => {
  const query = listUsersQuerySchema.parse(req.query);
  const users = await listUsers(req.authUser!.orgId, query);

  res.status(200).json({
    success: true,
    message: "Users loaded successfully",
    data: users,
  });
};

