import "dotenv/config";

import bcrypt from "bcryptjs";
import { PrismaClient, OrganizationStatus, UserRole, UserStatus } from "@prisma/client";
import { z } from "zod";

const envSchema = z.object({
  SEED_ORG_NAME: z.string().min(1).default("Demo Madrasa"),
  SEED_ORG_CODE: z.string().min(1).default("demo-madrasa"),
  SEED_BRANCH_NAME: z.string().min(1).default("Main Campus"),
  SEED_ADMIN_FULL_NAME: z.string().min(1).default("System Administrator"),
  SEED_ADMIN_EMAIL: z.string().email().default("admin@example.com"),
  SEED_ADMIN_PHONE: z.string().min(8).default("255700000000"),
  SEED_ADMIN_PASSWORD: z.string().min(8).default("ChangeMe123!"),
});

const env = envSchema.parse(process.env);
const prisma = new PrismaClient();

const run = async () => {
  const passwordHash = await bcrypt.hash(env.SEED_ADMIN_PASSWORD, 12);

  const organization = await prisma.organization.upsert({
    where: { code: env.SEED_ORG_CODE },
    update: {
      name: env.SEED_ORG_NAME,
      status: OrganizationStatus.ACTIVE,
    },
    create: {
      name: env.SEED_ORG_NAME,
      code: env.SEED_ORG_CODE,
      status: OrganizationStatus.ACTIVE,
      plan: "starter",
    },
  });

  const branch = await prisma.branch.upsert({
    where: {
      orgId_name: {
        orgId: organization.id,
        name: env.SEED_BRANCH_NAME,
      },
    },
    update: {},
    create: {
      orgId: organization.id,
      name: env.SEED_BRANCH_NAME,
      isMain: true,
    },
  });

  const adminUser = await prisma.user.upsert({
    where: {
      orgId_email: {
        orgId: organization.id,
        email: env.SEED_ADMIN_EMAIL,
      },
    },
    update: {
      fullName: env.SEED_ADMIN_FULL_NAME,
      phone: env.SEED_ADMIN_PHONE,
      passwordHash,
      role: UserRole.ADMIN,
      status: UserStatus.ACTIVE,
      branchId: branch.id,
    },
    create: {
      orgId: organization.id,
      branchId: branch.id,
      fullName: env.SEED_ADMIN_FULL_NAME,
      email: env.SEED_ADMIN_EMAIL,
      phone: env.SEED_ADMIN_PHONE,
      passwordHash,
      role: UserRole.ADMIN,
      status: UserStatus.ACTIVE,
    },
  });

  console.log("Seed complete");
  console.log(
    JSON.stringify(
      {
        organizationId: organization.id.toString(),
        branchId: branch.id.toString(),
        adminUserId: adminUser.id.toString(),
        adminEmail: adminUser.email,
      },
      null,
      2,
    ),
  );
};

run()
  .catch((error) => {
    console.error("Seed failed", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
