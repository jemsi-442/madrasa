import express from "express";
import request from "supertest";
import { describe, expect, it } from "vitest";
import { requestLog } from "../src/shared/middleware/request-log";

describe("safe HTTP access logs", () => {
  it.each(["courses", "learner"])("omits %s media credentials and referrer URLs", async area => {
    const lines: string[] = [];
    const app = express();
    app.use(requestLog({ write: line => { lines.push(line); } }));
    app.get(`/api/${area}/assets/9/deliver`, (req, res) => {
      // Logging must not strip the token from the actual request.
      expect(req.query.token).toBe("synthetic-secret");
      res.sendStatus(403);
    });
    await request(app).get(`/api/${area}/assets/9/deliver?token=synthetic-secret&email=synthetic-person`)
      .set("Authorization", "Bearer synthetic-access-token")
      .set("Referer", "https://school.test/?token=synthetic-referrer-token")
      .expect(403);
    expect(lines).toHaveLength(1);
    expect(lines[0]).toContain(`GET /api/${area}/assets/9/deliver 403`);
    expect(lines[0]).not.toMatch(/synthetic|token|email|Bearer|\?/);
  });
});
