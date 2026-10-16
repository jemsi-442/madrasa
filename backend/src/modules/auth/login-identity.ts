import type { Prisma } from "@prisma/client";

export function normalizeLogin(value: string): string {
  const login = value.trim();
  return login.includes("@") ? login.toLowerCase() : login.toUpperCase();
}

export function schoolLoginIdentity(value: string): Prisma.UserWhereInput {
  const login = normalizeLogin(value);
  return { OR: [{ email: login }, { phone: login }, { familyLoginId: login, role: "PARENT" }] };
}
