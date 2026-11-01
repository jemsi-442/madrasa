import { describe, expect, it } from "vitest";
import { demoMedia } from "../src/modules/learning/demo-media";

describe("bundled development media", () => {
  it.each(["video", "audio", "pdf", "text"])("resolves only the bundled %s file", key => {
    const sample = demoMedia({ storageKey: `afaq-demo:${key}`, storageProvider: "LOCAL" }, "development");
    expect(sample?.filePath).toContain("/frontend/assets/media-preview/");
    expect(sample?.playerKind).toBe(key.toUpperCase());
  });
  it.each(["production", "test"])("never serves demo files in %s", env => {
    expect(demoMedia({ storageKey: "afaq-demo:video", storageProvider: "LOCAL" }, env)).toBeNull();
  });
  it.each(["../../.env", "afaq-demo:../../.env", "constructor", "__proto__", "/etc/passwd"])("rejects arbitrary key %s", storageKey => {
    expect(demoMedia({ storageKey, storageProvider: "LOCAL" }, "development")).toBeNull();
  });
});
