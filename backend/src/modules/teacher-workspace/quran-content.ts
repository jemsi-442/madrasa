import { z } from "zod";
import { HttpError } from "../../shared/errors/http-error";

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

  async chapters() {
    if (!this.config.enabled || !this.config.clientId || !this.config.clientSecret) {
      throw new HttpError(503, "Quran content is not configured");
    }
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
    for (let attempt = 0; attempt < 2; attempt++) {
      const token = await this.accessToken();
      const response = await this.request(`${this.hosts.api}/content/api/v4/chapters`, {
        headers: { "x-auth-token": token, "x-client-id": this.config.clientId },
      });
      if (response.status === 401 && attempt === 0) {
        if (this.token?.value === token) this.token = undefined;
        continue;
      }
      if (!response.ok) throw new HttpError(503, "Quran content is temporarily unavailable");
      const parsed = chaptersSchema.safeParse(await this.json(response));
      if (!parsed.success || new Set(parsed.data.chapters.map(chapter => chapter.id)).size !== parsed.data.chapters.length) {
        throw new HttpError(503, "Quran content is temporarily unavailable");
      }
      return parsed.data.chapters;
    }
    throw new HttpError(503, "Quran content is temporarily unavailable");
  }
}
