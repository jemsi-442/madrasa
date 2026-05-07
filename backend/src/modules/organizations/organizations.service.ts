import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";

const toOrganizationProfile = (organization: {
  id: bigint;
  name: string;
  code: string;
  status: string;
  plan: string | null;
  branches: Array<{
    id: bigint;
    name: string;
    isMain: boolean;
  }>;
  _count: {
    users: number;
    branches: number;
  };
}) => ({
  id: organization.id.toString(),
  name: organization.name,
  code: organization.code,
  status: organization.status,
  plan: organization.plan,
  stats: {
    totalUsers: organization._count.users,
    totalBranches: organization._count.branches,
  },
  branches: organization.branches.map((branch) => ({
    id: branch.id.toString(),
    name: branch.name,
    isMain: branch.isMain,
  })),
});

export const getOrganizationProfile = async (orgId: string) => {
  const organization = await prisma.organization.findUnique({
    where: {
      id: BigInt(orgId),
    },
    select: {
      id: true,
      name: true,
      code: true,
      status: true,
      plan: true,
      branches: {
        select: {
          id: true,
          name: true,
          isMain: true,
        },
        orderBy: [{ isMain: "desc" }, { name: "asc" }],
      },
      _count: {
        select: {
          users: true,
          branches: true,
        },
      },
    },
  });

  if (!organization) {
    throw new HttpError(404, "Organization not found");
  }

  return toOrganizationProfile(organization);
};

