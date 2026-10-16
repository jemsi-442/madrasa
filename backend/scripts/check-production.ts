import { readFile } from "node:fs/promises";
import { parse } from "dotenv";
import { productionPreflight } from "../src/config/production-preflight";

async function main() {
  const args = process.argv.slice(2);
  if (args.length !== 2 || args[0] !== "--env-file" || !args[1]) {
    console.error("Usage: npm run deployment:check -- --env-file <configuration-file>");
    process.exitCode = 2;
    return;
  }
  // Explicit file only: do not merge development secrets or import runtime env/DB modules.
  const report = productionPreflight(parse(await readFile(args[1], "utf8")));
  console.log("Afaq production preflight (offline; values redacted)");
  for (const item of report.checks) console.log(`[${item.status}] ${item.id}: ${item.message}`);
  console.log(report.configurationPassed
    ? "Configuration checks passed. Deployment is NOT verified; complete all MANUAL checks."
    : "Configuration blocked. Resolve BLOCKED checks before deployment; MANUAL checks also remain.");
  process.exitCode = report.configurationPassed ? 0 : 1;
}

main().catch(() => {
  console.error("Could not check the configuration file. No values were printed and no services were contacted.");
  process.exitCode = 2;
});
