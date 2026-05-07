import { createApp } from "./app/create-app";
import { env } from "./config/env";

const app = createApp();

app.listen(env.PORT, () => {
  console.log(
    `[${env.APP_NAME}] listening on http://localhost:${env.PORT} in ${env.NODE_ENV} mode`,
  );
});

