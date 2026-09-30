import { describe, expect, it } from "vitest";
import { learnerMediaSource } from "../src/modules/learner/learner-media-source";

const source = (storageKey: string, storageProvider = "YOUTUBE", assetType = "VIDEO") =>
  learnerMediaSource({ storageKey, storageProvider, assetType });

describe("learner media sources", () => {
  it.each([
    "https://www.youtube.com/watch?v=abcdefghijk&list=ignored",
    "https://youtu.be/abcdefghijk?t=30",
    "https://m.youtube.com/shorts/abcdefghijk",
    "https://www.youtube-nocookie.com/embed/abcdefghijk",
    "https://www.youtube.com/embed/abcdefghijk",
  ])("normalizes the YouTube source %s", url => {
    expect(source(url)).toEqual({ url: "https://www.youtube-nocookie.com/embed/abcdefghijk", playerKind: "EMBED" });
  });
  it.each([
    "https://evil.test/?v=abcdefghijk", "https://youtube.com.evil.test/watch?v=abcdefghijk",
    "https://evil.test/youtu.be/abcdefghijk", "https://www.youtube.com/watch?v=abc",
    "https://www.youtube.com/watch?v=abcdefghijk%2F..", "https://www.youtube.com:8443/watch?v=abcdefghijk",
    "https://user:secret@www.youtube.com/watch?v=abcdefghijk", "javascript:alert(1)", "not-connected",
  ])("rejects misleading or invalid provider source %s", url => expect(source(url)).toBeNull());
  it("normalizes Vimeo while retaining only its unlisted access hash", () => {
    expect(source("https://vimeo.com/12345/abcdef?autoplay=1", "VIMEO"))
      .toEqual({ url: "https://player.vimeo.com/video/12345?h=abcdef", playerKind: "EMBED" });
    expect(source("https://player.vimeo.com/video/12345?h=abcdef&autoplay=1", "VIMEO"))
      .toEqual({ url: "https://player.vimeo.com/video/12345?h=abcdef", playerKind: "EMBED" });
    expect(source("https://evil.test/vimeo.com/12345", "VIMEO")).toBeNull();
    expect(source("https://vimeo.com/12345?h=evil%2Fpath", "VIMEO")).toBeNull();
  });
  it("requires video assets for embedded providers", () => {
    expect(source("https://youtu.be/abcdefghijk", "YOUTUBE", "PDF")).toBeNull();
    expect(source("https://vimeo.com/12345", "VIMEO", "AUDIO")).toBeNull();
  });
  it.each([
    ["image/png", "https://media.test/asset?signature=x", "IMAGE"],
    ["image/jpeg; charset=binary", "https://media.test/a", "IMAGE"],
    ["application/pdf", "https://media.test/a", "PDF"],
    ["text/plain; charset=utf-8", "https://media.test/a", "TEXT"],
    [null, "https://media.test/a.JPG?signature=x", "IMAGE"],
    ["application/octet-stream", "https://media.test/notes.pdf?signature=x", "PDF"],
    [null, "https://media.test/notes.txt", "TEXT"],
    ["text/html", "https://media.test/disguised.png", "EXTERNAL"],
    ["image/svg+xml", "https://media.test/image.svg", "EXTERNAL"],
    [null, "https://media.test/file.docx", "EXTERNAL"],
    [null, "https://media.test/page.html", "EXTERNAL"],
  ])("classifies attachment %s %s without rendering active documents", (mimeType, storageKey, playerKind) => {
    expect(learnerMediaSource({ storageProvider: "S3", assetType: "ATTACHMENT", storageKey: storageKey!, mimeType }))
      .toEqual({ url: storageKey, playerKind });
  });
  it("keeps direct media URLs without accepting credentials or other schemes", () => {
    expect(source("https://media.test/lesson.mp3?signature=x", "S3", "AUDIO"))
      .toEqual({ url: "https://media.test/lesson.mp3?signature=x", playerKind: "AUDIO" });
    expect(source("http://127.0.0.1/video.webm", "LOCAL"))
      .toEqual({ url: "http://127.0.0.1/video.webm", playerKind: "VIDEO" });
    expect(source("https://a:b@media.test/a", "S3")).toBeNull();
    expect(source("file:///private/file", "LOCAL")).toBeNull();
  });
});
