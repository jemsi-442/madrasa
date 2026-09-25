import { prisma } from "../db/prisma";
import { HttpError } from "../errors/http-error";
import { asyncHandler } from "../utils/async-handler";

export const requireActiveSchoolAccount = asyncHandler(async (req, _res, next) => {
  const actor = req.authUser;
  if (!actor) throw new HttpError(401, "Please sign in");
  const account = await prisma.user.findFirst({ where: {
    id: BigInt(actor.userId), orgId: BigInt(actor.orgId), role: actor.role, status: "ACTIVE",
    organization: { status: { in: ["ACTIVE", "TRIAL"] } },
  }, select: { branchId: true } });
  if (!account) throw new HttpError(403, "This account is no longer available");
  actor.branchId = account.branchId?.toString() ?? null;
  next();
});
