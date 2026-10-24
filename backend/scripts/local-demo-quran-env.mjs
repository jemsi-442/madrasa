import { parse } from 'dotenv';
import { readFile } from 'node:fs/promises';

export async function prepareDemoEnvironment(args, inherited, file, read = readFile) {
  if (args[0] !== '--start' || inherited.NODE_ENV === 'production') {
    throw new Error('Use --start for a disposable local demo, never production.');
  }
  let source = '';
  try { source = await read(file, 'utf8'); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  return withQuranSettings(inherited, source);
}

// Only provider settings may cross from the normal backend into the demo.
export function withQuranSettings(inherited, source) {
  const values = parse(source);
  const keys = ['QF_ENABLED', 'QF_ENV', 'QF_CLIENT_ID', 'QF_CLIENT_SECRET'];
  if (!keys.some(key => Object.hasOwn(values, key))) return { ...inherited };
  const enabled = values.QF_ENABLED ?? 'false';
  const environment = values.QF_ENV ?? 'prelive';
  if (!['true', 'false'].includes(enabled) ||
      !['prelive', 'production'].includes(environment) ||
      (enabled === 'true' && (!values.QF_CLIENT_ID?.trim() || !values.QF_CLIENT_SECRET?.trim()))) {
    throw new Error('Invalid Quran configuration; values redacted.');
  }
  return {
    ...inherited,
    QF_ENABLED: enabled,
    QF_ENV: environment,
    QF_CLIENT_ID: values.QF_CLIENT_ID ?? '',
    QF_CLIENT_SECRET: values.QF_CLIENT_SECRET ?? '',
  };
}
