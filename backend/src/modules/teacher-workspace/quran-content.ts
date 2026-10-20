import { z } from "zod";
import { HttpError } from "../../shared/errors/http-error";
import catalog from "./quran-catalog.json";

type Config = {
  enabled: boolean;
  environment: "prelive" | "production";
  clientId: string;
  clientSecret: string;
};
const tokenSchema = z.object({
  access_token: z.string().min(1),
  expires_in: z.number().int().positive().max(86400),
});
const chaptersSchema = z.object({
  chapters: z.array(z.object({
    id: z.number().int().min(1).max(114),
    name_simple: z.string().min(1),
    name_arabic: z.string().min(1),
    verses_count: z.number().int().positive(),
  })).min(1).max(114),
});
type Chapters = z.infer<typeof chaptersSchema>["chapters"];
const verseQuery = z.object({
  page: z.coerce.number().int().positive().max(286).default(1),
  per_page: z.coerce.number().int().min(1).max(50).default(10),
}).strict();
const versesSchema = z.object({
  verses: z.array(z.object({
    id: z.number().int().positive(),
    verse_number: z.number().int().positive(),
    verse_key: z.string(),
    text_uthmani: z.string().min(1).max(10000)
      .refine(text => text.trim().length > 0 && !/[<>]/.test(text)),
  })).min(1).max(50),
  pagination: z.object({
    current_page: z.number().int().positive(),
    per_page: z.number().int().positive(),
    next_page: z.number().int().positive().nullable(),
    total_pages: z.number().int().positive(),
    total_records: z.number().int().positive(),
  }),
});

/** Content only: no school identities, learner records or user OAuth tokens. */
export class QuranContentClient {
  private token: { value: string; until: number } | undefined;
  private tokenRequest: Promise<string> | undefined;
  private cached: { chapters: Chapters; until: number } | undefined;
  private chaptersRequest: Promise<Chapters> | undefined;

  constructor(
    private readonly config: Config,
    private readonly http: typeof fetch = fetch,
    private readonly now: () => number = Date.now,
  ) {}

  private get hosts() {
    return this.config.environment === "production"
      ? { auth: "https://oauth2.quran.foundation", api: "https://apis.quran.foundation" }
      : { auth: "https://prelive-oauth2.quran.foundation", api: "https://apis-prelive.quran.foundation" };
  }

  private async request(url: string, init: RequestInit) {
    try {
      return await this.http(url, {
        ...init, redirect: "error", signal: AbortSignal.timeout(10000),
      });
    } catch {
      throw new HttpError(503, "Quran content is temporarily unavailable");
    }
  }

  private async json(response: Response): Promise<unknown> {
    try { return await response.json(); }
    catch { throw new HttpError(503, "Quran content is temporarily unavailable"); }
  }

  private async accessToken(): Promise<string> {
    if (this.token && this.now() < this.token.until) return this.token.value;
    if (this.tokenRequest) return this.tokenRequest;
    this.tokenRequest = (async () => {
      const started = this.now();
      const response = await this.request(`${this.hosts.auth}/oauth2/token`, {
        method: "POST",
        headers: {
          Authorization: `Basic ${Buffer.from(`${this.config.clientId}:${this.config.clientSecret}`).toString("base64")}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: "grant_type=client_credentials&scope=content",
      });
      if (!response.ok) throw new HttpError(503, "Quran content is temporarily unavailable");
      const parsed = tokenSchema.safeParse(await this.json(response));
      if (!parsed.success) throw new HttpError(503, "Quran content is temporarily unavailable");
      const { access_token: value, expires_in: seconds } = parsed.data;
      this.token = { value, until: started + Math.max(0, seconds - 60) * 1000 };
      return value;
    })();
    try { return await this.tokenRequest; }
    finally { this.tokenRequest = undefined; }
  }

  private assertConfigured() {
    if (!this.config.enabled || !this.config.clientId || !this.config.clientSecret) {
      throw new HttpError(503, "Quran content is not configured");
    }
  }

  async chapters() {
    this.assertConfigured();
    if (!this.cached || this.now() >= this.cached.until) {
      this.chaptersRequest ??= this.loadChapters();
      try {
        const chapters = await this.chaptersRequest;
        this.cached = { chapters, until: this.now() + 60000 };
      } finally {
        this.chaptersRequest = undefined;
      }
    }
    return {
      provider: "Quran Foundation",
      environment: this.config.environment,
      // Pre-live is a limited content dataset, never claim full Quran availability.
      limitedContent: this.config.environment === "prelive",
      chapters: structuredClone(this.cached.chapters),
    };
  }

  private async loadChapters(): Promise<Chapters> {
    const parsed = chaptersSchema.safeParse(await this.content("/chapters"));
    if (!parsed.success || new Set(parsed.data.chapters.map(chapter => chapter.id)).size !== parsed.data.chapters.length) {
      throw new HttpError(503, "Quran content is temporarily unavailable");
    }
    return parsed.data.chapters;
  }

  async verses(chapterInput: unknown, input: unknown = {}) {
    const chapter = z.coerce.number().int().min(1).max(114).parse(chapterInput);
    const query = verseQuery.parse(input);
    const total = catalog.chapters[chapter - 1]!.ayahCount;
    const totalPages = Math.ceil(total / query.per_page);
    if (query.page > totalPages) throw new HttpError(422, "Page is outside this surah");
    this.assertConfigured();
    if (this.config.environment === "prelive" && chapter > 2) {
      throw new HttpError(503, "This surah is unavailable in the Quran test environment");
    }
    const params = new URLSearchParams({
      page: String(query.page), per_page: String(query.per_page),
      fields: "text_uthmani", words: "false",
    });
    const parsed = versesSchema.safeParse(
      await this.content(`/verses/by_chapter/${chapter}?${params}`),
    );
    if (!parsed.success) throw new HttpError(503, "Quran content is temporarily unavailable");
    const { verses, pagination } = parsed.data;
    const offset = (query.page - 1) * query.per_page;
    const next = query.page < totalPages ? query.page + 1 : null;
    // Fail closed on gaps, duplicates or wrong mappings; never reconstruct Quran text.
    if (pagination.current_page !== query.page || pagination.per_page !== query.per_page ||
        pagination.total_records !== total || pagination.total_pages !== totalPages ||
        pagination.next_page !== next || verses.length !== Math.min(query.per_page, total - offset) ||
        new Set(verses.map(verse => verse.id)).size !== verses.length ||
        verses.some((verse, index) => verse.verse_number !== offset + index + 1 ||
          verse.verse_key !== `${chapter}:${verse.verse_number}`)) {
      throw new HttpError(503, "Quran content is temporarily unavailable");
    }
    return {
      provider: "Quran Foundation", environment: this.config.environment,
      limitedContent: this.config.environment === "prelive",
      chapterId: chapter, script: "text_uthmani", verses, pagination,
    };
  }

  private async content(path: string): Promise<unknown> {
    for (let attempt = 0; attempt < 2; attempt++) {
      const token = await this.accessToken();
      const response = await this.request(`${this.hosts.api}/content/api/v4${path}`, {
        headers: { "x-auth-token": token, "x-client-id": this.config.clientId },
      });
      if (response.status === 401 && attempt === 0) {
        if (this.token?.value === token) this.token = undefined;
        continue;
      }
      if (!response.ok) throw new HttpError(503, "Quran content is temporarily unavailable");
      return this.json(response);
    }
    throw new HttpError(503, "Quran content is temporarily unavailable");
  }
}
