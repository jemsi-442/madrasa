import { createApp } from "./app/create-app";
import { env } from "./config/env";
import { prisma } from './shared/db/prisma';
import { startDonationSmsWorker } from './jobs/donation-sms';
import { startManualDonorSmsWorker } from './jobs/manual-donor-sms';

const app = createApp();

app.listen(env.PORT, () => {
  startDonationSmsWorker(prisma);
  startManualDonorSmsWorker(prisma);
  console.log(
    `[${env.APP_NAME}] listening on http://localhost:${env.PORT} in ${env.NODE_ENV} mode`,
  );
});

