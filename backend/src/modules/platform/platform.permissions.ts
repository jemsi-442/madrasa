import { HttpError } from "../../shared/errors/http-error";

export const platformPermissions = [
  "tenant.application.read",
  "tenant.application.create",
  "tenant.application.review",
  "tenant.provisioning.inspect",
  "tenant.provisioning.create",
  "tenant.activation.approve",
  "platform.audit.read",
  "platform.office-history.read",
  "platform.session.self",
  "tenant.onboarding.read",
  "platform.health.read",
  "platform.account.read",
  "platform.account.disable.it",
  "platform.account.restore.it",
  "platform.overview.read",
] as const;

export type PlatformPermission = (typeof platformPermissions)[number];

const grants: Readonly<Record<string, readonly PlatformPermission[]>> = {
  SUPER_ADMIN: [
    "tenant.application.read", "tenant.application.create", "tenant.application.review",
    "tenant.onboarding.read", "tenant.activation.approve", "platform.office-history.read",
    "platform.session.self", "platform.account.read", "platform.account.disable.it",
    "platform.account.restore.it", "platform.overview.read",
  ],
  IT_SECURITY: ["platform.audit.read", "platform.health.read", "platform.session.self", "tenant.onboarding.read", "tenant.provisioning.inspect", "tenant.provisioning.create"],
};

export function hasPlatformPermission(role: string, permission: PlatformPermission): boolean {
  return Object.hasOwn(grants, role) && grants[role]!.includes(permission);
}

export function assertPlatformPermission(role: string, permission: PlatformPermission): void {
  if (!hasPlatformPermission(role, permission)) {
    throw new HttpError(403, "Platform permission denied");
  }
}
