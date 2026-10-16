// Separate process: all configuration is provided by the disposable demo runner.
import { createApp } from "../src/app/create-app";
import { prisma } from "../src/shared/db/prisma";

const url = new URL(process.env.DATABASE_URL ?? "");
if (process.env.NODE_ENV !== "development" || url.hostname !== "127.0.0.1"
  || url.pathname !== "/afaq_local_demo" || !url.port || url.port === "3306"
  || process.env.DOTENV_CONFIG_PATH !== "/dev/null") {
  throw new Error("This entry point is restricted to the disposable local demo");
}

// Keep the complete application on loopback, including parent profile routes.
const app = createApp();
// Demo responses should not reuse validators from an earlier API build.
app.disable("etag");
async function start() {
  // Fail before accepting requests if the demo still needs the family migration.
  await prisma.user.findFirst({ select: { authVersion: true } });
  await prisma.familyApplication.findFirst({ select: { id: true } });
  app.listen(4087, "127.0.0.1");
}
start().catch(() => {
  console.error("Demo startup requires the current family-account migrations.");
  process.exitCode = 1;
});
