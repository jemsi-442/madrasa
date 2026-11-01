import jwt from "jsonwebtoken";
import { z } from "zod";
import { env } from "../../config/env";
import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import { learnerMediaSource } from "../learner/learner-media-source";
import { demoMedia } from "./demo-media";

const id = z.string().regex(/^[1-9][0-9]*$/).max(20);
const tokenSchema = z.object({
  type: z.literal("teacher-media"), userId: id, orgId: id, assetId: id,
  ver: z.number().int().nonnegative(),
});
const audience = "teacher-media-delivery";

async function loadAccess(user: AuthenticatedUser, assetId: string, version?: number) {
  id.parse(assetId);
  if (user.role !== "TEACHER") throw new HttpError(403, "Teacher access required");
  const account = await prisma.user.findFirst({
    where: { id: BigInt(user.userId), orgId: BigInt(user.orgId), role: "TEACHER", status: "ACTIVE",
      organization: { status: { in: ["ACTIVE", "TRIAL"] } } },
    select: { authVersion: true },
  });
  if (!account || (version !== undefined && version !== account.authVersion)) {
    throw new HttpError(403, "This teacher media link is no longer available");
  }
  const asset = await prisma.mediaAsset.findFirst({
    where: { id: BigInt(assetId), orgId: BigInt(user.orgId),
      course: { orgId: BigInt(user.orgId), primaryInstructorUserId: BigInt(user.userId) },
      lesson: { orgId: BigInt(user.orgId), course: {
        orgId: BigInt(user.orgId), primaryInstructorUserId: BigInt(user.userId),
      } } },
    include: { lesson: { select: { courseId: true } } },
  });
  if (!asset || asset.courseId !== asset.lesson.courseId) {
    throw new HttpError(404, "Resource not found in your assigned courses");
  }
  return { asset, version: account.authVersion };
}

export async function openTeacherMedia(user: AuthenticatedUser, assetId: string) {
  const { asset, version } = await loadAccess(user, assetId);
  const source = demoMedia(asset, env.NODE_ENV) ?? learnerMediaSource(asset);
  const token = jwt.sign({ type: "teacher-media", userId: user.userId, orgId: user.orgId,
    assetId, ver: version }, env.JWT_SECRET, { algorithm: "HS256", audience, expiresIn: 300 });
  return {
    asset: { id: assetId, title: asset.title, downloadAllowed: false },
    delivery: { status: source ? "READY" : "PENDING_SOURCE", playerKind: source?.playerKind ?? "PLACEHOLDER",
      inlineUrl: source ? `/api/courses/assets/${assetId}/deliver?token=${encodeURIComponent(token)}` : null,
      downloadUrl: null, expiresAt: new Date(Date.now() + 300000).toISOString() },
  };
}

export async function deliverTeacherMedia(assetId: string, token: string) {
  let payload: z.infer<typeof tokenSchema>;
  try {
    payload = tokenSchema.parse(jwt.verify(token, env.JWT_SECRET, { algorithms: ["HS256"], audience }));
    if (payload.assetId !== assetId) throw new Error("Asset mismatch");
  } catch {
    throw new HttpError(401, "This media link expired or is invalid. Reload the player.");
  }
  const { asset } = await loadAccess({ userId: payload.userId, orgId: payload.orgId, role: "TEACHER" }, assetId, payload.ver);
  const sample = demoMedia(asset, env.NODE_ENV);
  if (sample) return { filePath: sample.filePath };
  const source = learnerMediaSource(asset);
  if (!source) throw new HttpError(409, "The resource source is not connected yet");
  return source.url;
}
