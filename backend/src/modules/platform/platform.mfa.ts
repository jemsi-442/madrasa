import { createCipheriv, createDecipheriv, createHmac, randomBytes, timingSafeEqual } from "node:crypto";

// RFC 6238: SHA-1, 30-second steps. Eight digits are used only for RFC test vectors.
export function totpCode(secret: Buffer, step: bigint, digits: 6 | 8 = 6): string {
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(step);
  const digest = createHmac("sha1", secret).update(counter).digest();
  const offset = digest[digest.length - 1]! & 15;
  return ((digest.readUInt32BE(offset) & 0x7fffffff) % (10 ** digits)).toString().padStart(digits, "0");
}

export function matchTotpStep(secret: Buffer, code: string, now = Date.now()): bigint | null {
  if (!/^\d{6}$/.test(code)) return null;
  const current = BigInt(Math.floor(now / 30_000));
  for (const step of [current, current - 1n, current + 1n]) {
    if (step >= 0n && timingSafeEqual(Buffer.from(code), Buffer.from(totpCode(secret, step)))) return step;
  }
  return null;
}

export function validMfaKey(key: string): boolean { return /^[a-fA-F0-9]{64}$/.test(key); }

export function encryptMfaSecret(secret: Buffer, accountId: string, key: string): string {
  if (!validMfaKey(key) || secret.length !== 20) throw new Error("Invalid MFA configuration");
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", Buffer.from(key, "hex"), iv);
  cipher.setAAD(Buffer.from(`afaq-platform:${accountId}`));
  const encrypted = Buffer.concat([cipher.update(secret), cipher.final()]);
  return ["v1", iv.toString("hex"), cipher.getAuthTag().toString("hex"), encrypted.toString("hex")].join(":");
}

export function decryptMfaSecret(envelope: string, accountId: string, key: string): Buffer {
  if (!validMfaKey(key) || !/^v1:[a-f0-9]{24}:[a-f0-9]{32}:[a-f0-9]{40}$/.test(envelope)) {
    throw new Error("Invalid MFA configuration");
  }
  const [, iv, tag, encrypted] = envelope.split(":");
  const decipher = createDecipheriv("aes-256-gcm", Buffer.from(key, "hex"), Buffer.from(iv!, "hex"));
  decipher.setAAD(Buffer.from(`afaq-platform:${accountId}`));
  decipher.setAuthTag(Buffer.from(tag!, "hex"));
  return Buffer.concat([decipher.update(Buffer.from(encrypted!, "hex")), decipher.final()]);
}

export function base32Secret(secret: Buffer): string {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  let bits = 0, value = 0, encoded = "";
  for (const byte of secret) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) { bits -= 5; encoded += alphabet[(value >>> bits) & 31]; }
    value &= (1 << bits) - 1;
  }
  if (bits) encoded += alphabet[(value << (5 - bits)) & 31];
  return encoded;
}
