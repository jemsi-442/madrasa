import { randomUUID } from "node:crypto";
import { existsSync } from "node:fs";
import { mkdir, writeFile, unlink } from "node:fs/promises";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import { env } from "../../config/env";

export const lessonMediaRoot = () => resolve(env.LESSON_MEDIA_DIR || join(homedir(), ".afaq", "lesson-media"));
const root = lessonMediaRoot;

export async function storeLessonText(orgId: string, text: string) {
  if (!/^[1-9][0-9]*$/.test(orgId)) throw new Error("Invalid media organization");
  const name = `${randomUUID()}.txt`;
  const directory = join(root(), orgId);
  await mkdir(directory, { recursive: true, mode: 0o700 });
  const filePath = join(directory, name);
  await writeFile(filePath, text, { encoding: "utf8", mode: 0o600, flag: "wx" });
  return {
    storageKey: `afaq-text:${orgId}/${name}`,
    fileSizeBytes: Buffer.byteLength(text, "utf8"),
    remove: () => unlink(filePath),
  };
}

// Opaque, organization-bound keys only. Never interpret arbitrary storage keys as paths.
export function localLessonMedia(asset: {
  orgId: bigint; storageProvider: string; storageKey: string; assetType: string;
}) {
  if (asset.storageProvider !== "LOCAL") return null;
  const binary = /^afaq-file:([1-9][0-9]*)\/([0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(pdf|png|jpg|mp4|mp3|wav))$/.exec(asset.storageKey);
  if (binary) {
    const kinds = { pdf: "PDF", png: "IMAGE", jpg: "IMAGE", mp4: "VIDEO", mp3: "AUDIO", wav: "AUDIO" } as const;
    const kind = kinds[binary[3] as keyof typeof kinds];
    const assetType = kind === "IMAGE" ? "ATTACHMENT" : kind;
    if (binary[1] !== String(asset.orgId) || assetType !== asset.assetType) return null;
    const filePath = join(root(), binary[1]!, binary[2]!);
    return existsSync(filePath) ? { filePath, playerKind: kind } : null;
  }
  if (asset.assetType !== "TEXT") return null;
  const match = /^afaq-text:([1-9][0-9]*)\/([0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.txt)$/.exec(asset.storageKey);
  if (!match || match[1] !== String(asset.orgId)) return null;
  const filePath = join(root(), match[1]!, match[2]!);
  return existsSync(filePath) ? { filePath, playerKind: "TEXT" as const } : null;
}
