import { isIP } from 'node:net';

// Accept Express's resolved peer IP, never a body field or raw forwarded header.
export function sessionIp(value?: string): string | null {
  return value && isIP(value) ? value : null;
}
