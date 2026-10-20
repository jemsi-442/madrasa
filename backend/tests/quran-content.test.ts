import { expect, it, vi } from "vitest";
import { QuranContentClient } from "../src/modules/teacher-workspace/quran-content";

const config = { enabled: true, environment: "prelive" as const,
  clientId: "synthetic-client", clientSecret: "synthetic-secret" };
const payload = { chapters: [
  { id: 1, name_simple: "Synthetic metadata", name_arabic: "Synthetic label", verses_count: 7 },
] };
const token = () => new Response(JSON.stringify({ access_token: "synthetic-token", expires_in: 3600 }));
const content = () => new Response(JSON.stringify(payload));

it("keeps credentials server-side and caches concurrent chapter requests", async () => {
  const http = vi.fn<typeof fetch>().mockResolvedValueOnce(token()).mockResolvedValueOnce(content());
  const client = new QuranContentClient(config, http);
  const [first, second] = await Promise.all([client.chapters(), client.chapters()]);
  expect(first).toEqual(second);
  expect(first).toMatchObject({ environment: "prelive", limitedContent: true, chapters: payload.chapters });
  expect(http).toHaveBeenCalledTimes(2);
  expect(http.mock.calls[0]![0]).toBe("https://prelive-oauth2.quran.foundation/oauth2/token");
  expect(http.mock.calls[0]![1]).toMatchObject({
    method: "POST", redirect: "error", body: "grant_type=client_credentials&scope=content",
  });
  expect(http.mock.calls[1]![1]).toMatchObject({
    headers: { "x-client-id": config.clientId, "x-auth-token": "synthetic-token" },
  });
  expect(JSON.stringify(first)).not.toMatch(/synthetic-token|synthetic-secret/);
  first.chapters.length = 0;
  expect((await client.chapters()).chapters).toHaveLength(1);
});

for (const invalid of [{ ...config, enabled: false }, { ...config, clientSecret: "" }, { ...config, clientId: "" }]) {
  it("does not contact the provider without enabled credentials", async () => {
    const http = vi.fn<typeof fetch>();
    await expect(new QuranContentClient(invalid, http).chapters()).rejects.toMatchObject({ statusCode: 503 });
    expect(http).not.toHaveBeenCalled();
  });
}
it("renews near-expiry tokens and pairs production hosts", async () => {
  let now = 0;
  const http = vi.fn<typeof fetch>()
    .mockResolvedValueOnce(token()).mockResolvedValueOnce(content())
    .mockResolvedValueOnce(token()).mockResolvedValueOnce(content());
  const client = new QuranContentClient({ ...config, environment: "production" }, http, () => now);
  expect((await client.chapters()).limitedContent).toBe(false);
  now = 3540000;
  await client.chapters();
  expect(http.mock.calls.map(call => call[0])).toEqual([
    "https://oauth2.quran.foundation/oauth2/token", "https://apis.quran.foundation/content/api/v4/chapters",
    "https://oauth2.quran.foundation/oauth2/token", "https://apis.quran.foundation/content/api/v4/chapters",
  ]);
});
it("renews on a content 401 once without an endless retry", async () => {
  const http = vi.fn<typeof fetch>()
    .mockResolvedValueOnce(token()).mockResolvedValueOnce(new Response("", { status: 401 }))
    .mockResolvedValueOnce(token()).mockResolvedValueOnce(new Response("", { status: 401 }));
  await expect(new QuranContentClient(config, http).chapters()).rejects.toMatchObject({ statusCode: 503 });
  expect(http).toHaveBeenCalledTimes(4);
});
it("recovers from one expired upstream token", async () => {
  const http = vi.fn<typeof fetch>()
    .mockResolvedValueOnce(token()).mockResolvedValueOnce(new Response("", { status: 401 }))
    .mockResolvedValueOnce(token()).mockResolvedValueOnce(content());
  expect((await new QuranContentClient(config, http).chapters()).chapters).toHaveLength(1);
});
for (const status of [403, 429, 500]) {
  it(`does not leak or repeatedly retry upstream ${status}`, async () => {
    const http = vi.fn<typeof fetch>().mockResolvedValueOnce(token())
      .mockResolvedValueOnce(new Response("private provider details", { status }));
    await expect(new QuranContentClient(config, http).chapters()).rejects.toMatchObject({
      statusCode: 503, message: "Quran content is temporarily unavailable",
    });
    expect(http).toHaveBeenCalledTimes(2);
  });
}
it("rejects malformed chapter data without caching it", async () => {
  const http = vi.fn<typeof fetch>().mockResolvedValueOnce(token())
    .mockResolvedValueOnce(new Response(JSON.stringify({ chapters: [{ id: 115 }] })))
    .mockResolvedValueOnce(content());
  const client = new QuranContentClient(config, http);
  await expect(client.chapters()).rejects.toMatchObject({ statusCode: 503 });
  expect((await client.chapters()).chapters).toHaveLength(1);
  expect(http).toHaveBeenCalledTimes(3);
});
it("sanitises transport errors and clears failed token requests", async () => {
  const http = vi.fn<typeof fetch>().mockRejectedValueOnce(new Error("private transport detail"))
    .mockResolvedValueOnce(token()).mockResolvedValueOnce(content());
  const client = new QuranContentClient(config, http);
  await expect(client.chapters()).rejects.toMatchObject({
    message: "Quran content is temporarily unavailable",
  });
  expect((await client.chapters()).chapters).toHaveLength(1);
  expect(http.mock.calls[0]![1]?.signal).toBeInstanceOf(AbortSignal);
});
