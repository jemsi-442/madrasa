import { parse } from 'dotenv';

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
