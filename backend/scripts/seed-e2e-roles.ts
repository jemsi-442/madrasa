import "dotenv/config";

import bcrypt from "bcryptjs";
import {
  AnnouncementAudience,
  AttendanceStatus,
  BillingCycle,
  EnrollmentStatus,
  InvoiceStatus,
  PrismaClient,
  StudentStatus,
  UserRole,
  UserStatus,
} from "@prisma/client";
import { z } from "zod";

const envSchema = z.object({
  SEED_ORG_CODE: z.string().min(1).default("demo-madrasa"),
  E2E_ACCOUNTANT_FULL_NAME: z.string().min(1).default("Finance Officer"),
  E2E_ACCOUNTANT_EMAIL: z.string().email().default("accountant@example.com"),
  E2E_ACCOUNTANT_PHONE: z.string().min(8).default("255711111111"),
  E2E_ACCOUNTANT_PASSWORD: z.string().min(8).default("ChangeMe123!"),
  E2E_TEACHER_FULL_NAME: z.string().min(1).default("Teacher One"),
  E2E_TEACHER_EMAIL: z.string().email().default("teacher@example.com"),
  E2E_TEACHER_PHONE: z.string().min(8).default("255722222222"),
  E2E_TEACHER_PASSWORD: z.string().min(8).default("ChangeMe123!"),
  E2E_PARENT_FULL_NAME: z.string().min(1).default("Parent One"),
  E2E_PARENT_EMAIL: z.string().email().default("parent@example.com"),
  E2E_PARENT_PHONE: z.string().min(8).default("255733333333"),
  E2E_PARENT_PASSWORD: z.string().min(8).default("ChangeMe123!"),
  E2E_LEARNER_FULL_NAME: z.string().min(1).default("Learner One"),
  E2E_LEARNER_EMAIL: z.string().email().default("learner@example.com"),
  E2E_LEARNER_PHONE: z.string().min(8).default("255744444444"),
  E2E_LEARNER_PASSWORD: z.string().min(8).default("ChangeMe123!"),
  E2E_GUARDIAN_RELATIONSHIP: z.string().min(1).default("Mother"),
  E2E_CLASS_NAME: z.string().min(1).default("Noor One"),
  E2E_CLASS_LEVEL: z.string().min(1).default("Primary"),
  E2E_ACADEMIC_YEAR: z.string().min(1).default("2026"),
  E2E_STUDENT_FULL_NAME: z.string().min(1).default("Ali Hassan"),
  E2E_STUDENT_ADMISSION_NO: z.string().min(1).default("E2E-STD-001"),
  E2E_STUDENT_GENDER: z.enum(["male", "female"]).default("male"),
  E2E_INVOICE_NO: z.string().min(1).default("E2E-INV-001"),
  E2E_FEE_STRUCTURE_NAME: z.string().min(1).default("E2E Tuition"),
});

const env = envSchema.parse(process.env);
const prisma = new PrismaClient();

const today = new Date();
const dateOnly = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate()));

const upsertRoleUser = async ({
  orgId,
  branchId,
  fullName,
  email,
  phone,
  passwordHash,
  role,
}: {
  orgId: bigint;
  branchId: bigint;
  fullName: string;
  email: string;
  phone: string;
  passwordHash: string;
  role: UserRole;
}) => {
  const existingMatches = await prisma.user.findMany({
    where: {
      orgId,
      OR: [{ email }, { phone }],
    },
    select: {
      id: true,
      email: true,
      phone: true,
      role: true,
    },
  });

  if (existingMatches.length > 1) {
    throw new Error(
      `More than one existing user matches ${role.toLowerCase()} seed identity. Resolve duplicate email/phone records first.`,
    );
  }

  if (existingMatches[0]) {
    if (
      existingMatches[0].email !== email ||
      existingMatches[0].phone !== phone ||
      existingMatches[0].role !== role
    ) {
      throw new Error(
        `The ${role.toLowerCase()} seed identity conflicts with an existing account. Use an unused email and phone.`,
      );
    }

    return prisma.user.update({
      where: { id: existingMatches[0].id },
      data: {
        branchId,
        fullName,
        passwordHash,
        status: UserStatus.ACTIVE,
      },
    });
  }

  return prisma.user.create({
    data: {
      orgId,
      branchId,
      fullName,
      email,
      phone,
      passwordHash,
      role,
      status: UserStatus.ACTIVE,
    },
  });
};

const run = async () => {
  if (process.env.NODE_ENV === "production") {
    throw new Error("E2E role seeding is disabled in production");
  }

  const organization = await prisma.organization.findUnique({
    where: { code: env.SEED_ORG_CODE },
    include: { branches: { orderBy: { id: "asc" } } },
  });

  if (!organization) {
    throw new Error(`Organization with code ${env.SEED_ORG_CODE} was not found. Run seed:admin first.`);
  }

  const branch = organization.branches[0];

  if (!branch) {
    throw new Error("No branch exists for the seeded organization.");
  }

  const [accountantPasswordHash, teacherPasswordHash, parentPasswordHash, learnerPasswordHash] = await Promise.all([
    bcrypt.hash(env.E2E_ACCOUNTANT_PASSWORD, 12),
    bcrypt.hash(env.E2E_TEACHER_PASSWORD, 12),
    bcrypt.hash(env.E2E_PARENT_PASSWORD, 12),
    bcrypt.hash(env.E2E_LEARNER_PASSWORD, 12),
  ]);

  const accountant = await upsertRoleUser({
    orgId: organization.id,
    branchId: branch.id,
    fullName: env.E2E_ACCOUNTANT_FULL_NAME,
    email: env.E2E_ACCOUNTANT_EMAIL,
    phone: env.E2E_ACCOUNTANT_PHONE,
    passwordHash: accountantPasswordHash,
    role: UserRole.ACCOUNTANT,
  });

  const teacher = await upsertRoleUser({
    orgId: organization.id,
    branchId: branch.id,
    fullName: env.E2E_TEACHER_FULL_NAME,
    email: env.E2E_TEACHER_EMAIL,
    phone: env.E2E_TEACHER_PHONE,
    passwordHash: teacherPasswordHash,
    role: UserRole.TEACHER,
  });

  const parentUser = await upsertRoleUser({
    orgId: organization.id,
    branchId: branch.id,
    fullName: env.E2E_PARENT_FULL_NAME,
    email: env.E2E_PARENT_EMAIL,
    phone: env.E2E_PARENT_PHONE,
    passwordHash: parentPasswordHash,
    role: UserRole.PARENT,
  });

  const existingGuardian = await prisma.guardian.findFirst({
    where: {
      orgId: organization.id,
      phone: env.E2E_PARENT_PHONE,
    },
  });

  const guardian = existingGuardian
    ? await prisma.guardian.update({
        where: { id: existingGuardian.id },
        data: {
          userId: parentUser.id,
          fullName: env.E2E_PARENT_FULL_NAME,
          email: env.E2E_PARENT_EMAIL,
          relationship: env.E2E_GUARDIAN_RELATIONSHIP,
        },
      })
    : await prisma.guardian.create({
        data: {
          orgId: organization.id,
          userId: parentUser.id,
          fullName: env.E2E_PARENT_FULL_NAME,
          phone: env.E2E_PARENT_PHONE,
          email: env.E2E_PARENT_EMAIL,
          relationship: env.E2E_GUARDIAN_RELATIONSHIP,
        },
      });

  const existingClass = await prisma.class.findFirst({
    where: {
      orgId: organization.id,
      name: env.E2E_CLASS_NAME,
    },
  });

  const taughtClass = existingClass
    ? await prisma.class.update({
        where: { id: existingClass.id },
        data: {
          branchId: branch.id,
          level: env.E2E_CLASS_LEVEL,
          academicYear: env.E2E_ACADEMIC_YEAR,
          teacherId: teacher.id,
        },
      })
    : await prisma.class.create({
        data: {
          orgId: organization.id,
          branchId: branch.id,
          name: env.E2E_CLASS_NAME,
          level: env.E2E_CLASS_LEVEL,
          academicYear: env.E2E_ACADEMIC_YEAR,
          teacherId: teacher.id,
        },
      });

  const student = await prisma.student.upsert({
    where: {
      orgId_admissionNo: {
        orgId: organization.id,
        admissionNo: env.E2E_STUDENT_ADMISSION_NO,
      },
    },
    update: {
      branchId: branch.id,
      fullName: env.E2E_STUDENT_FULL_NAME,
      gender: env.E2E_STUDENT_GENDER,
      status: StudentStatus.ACTIVE,
      classId: taughtClass.id,
      primaryGuardianId: guardian.id,
      joinedOn: dateOnly,
    },
    create: {
      orgId: organization.id,
      branchId: branch.id,
      admissionNo: env.E2E_STUDENT_ADMISSION_NO,
      fullName: env.E2E_STUDENT_FULL_NAME,
      gender: env.E2E_STUDENT_GENDER,
      status: StudentStatus.ACTIVE,
      classId: taughtClass.id,
      primaryGuardianId: guardian.id,
      joinedOn: dateOnly,
    },
  });

  const learnerUser = await upsertRoleUser({
    orgId: organization.id,
    branchId: branch.id,
    fullName: env.E2E_LEARNER_FULL_NAME,
    email: env.E2E_LEARNER_EMAIL,
    phone: env.E2E_LEARNER_PHONE,
    passwordHash: learnerPasswordHash,
    role: UserRole.LEARNER,
  });

  if (student.learnerUserId !== learnerUser.id) {
    await prisma.student.update({
      where: { id: student.id },
      data: {
        learnerUserId: learnerUser.id,
      },
    });
  }

  await prisma.studentGuardian.upsert({
    where: {
      studentId_guardianId: {
        studentId: student.id,
        guardianId: guardian.id,
      },
    },
    update: {
      isPrimary: true,
      orgId: organization.id,
    },
    create: {
      orgId: organization.id,
      studentId: student.id,
      guardianId: guardian.id,
      isPrimary: true,
    },
  });

  await prisma.enrollment.upsert({
    where: {
      studentId_classId_academicYear: {
        studentId: student.id,
        classId: taughtClass.id,
        academicYear: env.E2E_ACADEMIC_YEAR,
      },
    },
    update: {
      orgId: organization.id,
      status: EnrollmentStatus.ACTIVE,
    },
    create: {
      orgId: organization.id,
      studentId: student.id,
      classId: taughtClass.id,
      academicYear: env.E2E_ACADEMIC_YEAR,
      status: EnrollmentStatus.ACTIVE,
    },
  });

  const existingFeeStructure = await prisma.feeStructure.findFirst({
    where: {
      orgId: organization.id,
      name: env.E2E_FEE_STRUCTURE_NAME,
    },
  });

  const feeStructure = existingFeeStructure
    ? await prisma.feeStructure.update({
        where: { id: existingFeeStructure.id },
        data: {
          branchId: branch.id,
          classId: taughtClass.id,
          amount: "50000.00",
          billingCycle: BillingCycle.TERMLY,
          isActive: true,
        },
      })
    : await prisma.feeStructure.create({
        data: {
          orgId: organization.id,
          branchId: branch.id,
          classId: taughtClass.id,
          name: env.E2E_FEE_STRUCTURE_NAME,
          amount: "50000.00",
          billingCycle: BillingCycle.TERMLY,
          isActive: true,
        },
      });

  await prisma.invoice.upsert({
    where: {
      orgId_invoiceNo: {
        orgId: organization.id,
        invoiceNo: env.E2E_INVOICE_NO,
      },
    },
    update: {
      branchId: branch.id,
      studentId: student.id,
      feeStructureId: feeStructure.id,
      amountDue: "50000.00",
      amountPaid: "0.00",
      dueDate: dateOnly,
      status: InvoiceStatus.PENDING,
    },
    create: {
      orgId: organization.id,
      branchId: branch.id,
      studentId: student.id,
      feeStructureId: feeStructure.id,
      invoiceNo: env.E2E_INVOICE_NO,
      amountDue: "50000.00",
      amountPaid: "0.00",
      currency: "TZS",
      dueDate: dateOnly,
      status: InvoiceStatus.PENDING,
    },
  });

  await prisma.attendanceRecord.upsert({
    where: {
      orgId_studentId_date: {
        orgId: organization.id,
        studentId: student.id,
        date: dateOnly,
      },
    },
    update: {
      branchId: branch.id,
      classId: taughtClass.id,
      status: AttendanceStatus.PRESENT,
      markedById: teacher.id,
    },
    create: {
      orgId: organization.id,
      branchId: branch.id,
      classId: taughtClass.id,
      studentId: student.id,
      date: dateOnly,
      status: AttendanceStatus.PRESENT,
      markedById: teacher.id,
    },
  });

  const existingHifdh = await prisma.hifdhProgress.findFirst({
    where: {
      orgId: organization.id,
      studentId: student.id,
      teacherId: teacher.id,
      surahName: "Al-Fatiha",
      assessedOn: dateOnly,
    },
  });

  if (!existingHifdh) {
    await prisma.hifdhProgress.create({
      data: {
        orgId: organization.id,
        studentId: student.id,
        teacherId: teacher.id,
        juzNumber: 1,
        surahName: "Al-Fatiha",
        ayahFrom: 1,
        ayahTo: 7,
        memorizationScore: "92.50",
        revisionScore: "88.00",
        remarks: "Seeded for e2e role coverage",
        assessedOn: dateOnly,
      },
    });
  }

  const existingAnnouncement = await prisma.announcement.findFirst({
    where: {
      orgId: organization.id,
      title: "E2E Family Update",
      audience: AnnouncementAudience.PARENTS,
    },
  });

  if (!existingAnnouncement) {
    await prisma.announcement.create({
      data: {
        orgId: organization.id,
        branchId: branch.id,
        title: "E2E Family Update",
        message: "This seeded announcement supports role-based browser coverage.",
        audience: AnnouncementAudience.PARENTS,
        publishAt: dateOnly,
        createdById: teacher.id,
      },
    });
  }

  console.log("E2E role seed complete");
  console.log(
    JSON.stringify(
      {
        accountantEmail: env.E2E_ACCOUNTANT_EMAIL,
        accountantPhone: env.E2E_ACCOUNTANT_PHONE,
        teacherEmail: env.E2E_TEACHER_EMAIL,
        teacherPhone: env.E2E_TEACHER_PHONE,
        parentEmail: env.E2E_PARENT_EMAIL,
        parentPhone: env.E2E_PARENT_PHONE,
        learnerEmail: env.E2E_LEARNER_EMAIL,
        learnerPhone: env.E2E_LEARNER_PHONE,
        classId: taughtClass.id.toString(),
        studentId: student.id.toString(),
      },
      null,
      2,
    ),
  );
};

run()
  .catch((error) => {
    console.error("E2E role seed failed", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
