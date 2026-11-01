import { config } from 'dotenv';
import { resolve } from 'node:path';
import { checkRodSms } from '../src/shared/notifications/rodsms-check';

config({ path: resolve(__dirname, '../.env') });
void checkRodSms(process.env).then(result => {
  console.log(JSON.stringify(result, null, 2));
  process.exitCode = result.ok ? 0 : 1;
});
