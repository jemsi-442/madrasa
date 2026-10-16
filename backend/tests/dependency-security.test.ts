import { createRequire } from "node:module";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { loadConfigFromFile } from "@prisma/config";

const requireFromProject = createRequire(resolve("package.json"));

describe("patched dependency regressions", () => {
  it("does not trust arbitrary IPv4 clients through short mapped IPv6 prefixes", () => {
    const proxyaddr = requireFromProject("proxy-addr") as { compile: (value: string) => (ip: string) => boolean };
    expect(proxyaddr.compile("::ffff:10.0.0.0/8")("203.0.113.9")).toBe(false);
    const trusted = proxyaddr.compile("10.0.0.0/8");
    expect(trusted("10.2.3.4")).toBe(true);
    expect(trusted("203.0.113.9")).toBe(false);
  });

  it("loads a Prisma config with the scoped patched merge dependency", async () => {
    const directory = await mkdtemp(join(tmpdir(), "afaq-prisma-config-"));
    try {
      await writeFile(join(directory, "prisma.config.js"),
        'module.exports = { schema: "schema.prisma", migrations: { path: "migrations" } };');
      const result = await loadConfigFromFile({ configRoot: directory });
      expect(result.error).toBeUndefined();
      expect(result.config?.schema).toBe(join(directory, "schema.prisma"));
      expect(result.config?.migrations?.path).toBe(join(directory, "migrations"));
    } finally { await rm(directory, { recursive: true, force: true }); }
  });
});
