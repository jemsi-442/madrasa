import { resolve } from "node:path";
import { existsSync } from "node:fs";

const samples = {
  "afaq-demo:video": { file: "video.mp4", kind: "VIDEO" },
  "afaq-demo:audio": { file: "audio.m4a", kind: "AUDIO" },
  "afaq-demo:pdf": { file: "guide.pdf", kind: "PDF" },
  "afaq-demo:text": { file: "checklist.txt", kind: "TEXT" },
} as const;

// Only bundled synthetic samples, never a user-supplied filesystem path.
export function demoMedia(asset: { storageKey: string; storageProvider: string }, environment: string) {
  if (environment !== "development" || asset.storageProvider !== "LOCAL" ||
      !Object.prototype.hasOwnProperty.call(samples, asset.storageKey)) return null;
  const sample = samples[asset.storageKey as keyof typeof samples];
  const roots = ["../../../../frontend/assets/media-preview", "../../../../../frontend/assets/media-preview"];
  const filePath = roots.map(root => resolve(__dirname, root, sample.file)).find(file => existsSync(file));
  return filePath ? { filePath, playerKind: sample.kind } : null;
}
