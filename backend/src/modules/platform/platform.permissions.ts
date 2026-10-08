import { HttpError } from "../../shared/errors/http-error";

export const platformPermissions = [
  "tenant.application.read",
  "tenant.application.create",
  "tenant.application.review",
  "tenant.provisioning.inspect",
  "tenant.provisioning.create",
  "tenant.activation.approve",
  "platform.audit.read",
  "platform.health.read",
  "platform.account.read",
  "platform.account.disable.it",
  "platform.account.restore.it",
  "platform.overview.read",
] as const;

export type PlatformPermission = (typeof platformPermissions)[number];

const grants: Readonly<Record<string, readonly PlatformPermission[]>> = {
  SUPER_ADMIN: platformPermissions.filter((permission) => permission !== "tenant.provisioning.create"),
  IT_SECURITY: ["platform.audit.read", "platform.health.read", "tenant.provisioning.inspect", "tenant.provisioning.create"],
};

export function hasPlatformPermission(role: string, permission: PlatformPermission): boolean {
  return Object.hasOwn(grants, role) && grants[role]!.includes(permission);
}

export function assertPlatformPermission(role: string, permission: PlatformPermission): void {
  if (!hasPlatformPermission(role, permission)) {
    throw new HttpError(403, "Platform permission denied");
  }
}
