import type { Prisma } from "@prisma/client";
import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { AuthenticatedUser } from "../../shared/middleware/authenticate";
import { getDashboardReport } from "../reports/reports.service";
import { fundraisingOverview, recentMonths } from "../fundraising/fundraising.service";
import type { DirectoryQuery } from "../fundraising/fundraising.schemas";
import type { EventInput, TeacherDirectoryQuery } from "./admin-panel.schemas";

function tenant(actor: AuthenticatedUser) {
  if (actor.role !== "ADMIN") throw new HttpError(403, "Administration access required");
  return BigInt(actor.orgId);
}

export async function adminOverview(actor: AuthenticatedUser) {
  const orgId = tenant(actor);
  const report = await getDashboardReport(actor, {});
  const fundraising = await fundraisingOverview(actor);
  const academic = await prisma.$transaction(async (tx) => {
    const classes = await tx.class.count({ where: { orgId } });
    const teachers = await tx.user.count({ where: { orgId, role: "TEACHER", status: "ACTIVE" } });
    const subjects = await tx.subject.count({ where: { orgId, isActive: true } });
    const assessedStudents = await tx.student.count({ where: { orgId, hifdhProgress: { some: { orgId } } } });
    const admissions = [];
    for (const month of recentMonths()) {
      admissions.push({ month: month.from.toISOString().slice(0, 7), count: await tx.student.count({
        where: { orgId, createdAt: { gte: month.from, lt: month.to } },
      }) });
    }
    const recentStudents = await tx.student.findMany({ where: { orgId }, orderBy: [{ createdAt: "desc" }, { id: "desc" }], take: 3,
      select: { fullName: true, createdAt: true, currentClass: { select: { name: true } } } });
    const recentDonations = await tx.donation.findMany({ where: { orgId, status: "RECEIVED" }, orderBy: [{ createdAt: "desc" }, { id: "desc" }], take: 3,
      select: { amount: true, createdAt: true, campaign: { select: { title: true } } } });
    const recentTeachers = await tx.user.findMany({ where: { orgId, role: "TEACHER" }, orderBy: [{ createdAt: "desc" }, { id: "desc" }], take: 3,
      select: { fullName: true, createdAt: true } });
    const activities = [
      ...recentStudents.map((s) => ({ title: "Student registered", detail: `${s.fullName}${s.currentClass ? ` - ${s.currentClass.name}` : ""}`, at: s.createdAt, page: "Students" })),
      ...recentTeachers.map((s) => ({ title: "Teacher added", detail: s.fullName, at: s.createdAt, page: "Teachers" })),
      ...recentDonations.map((s) => ({ title: "Donation recorded", detail: `TZS ${s.amount} - ${s.campaign.title}`, at: s.createdAt, page: "Donations" })),
    ].sort((a, b) => b.at.getTime() - a.at.getTime()).slice(0, 6);
    const events = await tx.foundationEvent.findMany({ where: { orgId, cancelledAt: null, endsAt: { gt: new Date() } },
      orderBy: [{ startsAt: "asc" }, { id: "asc" }], take: 5,
      select: { id: true, title: true, location: true, startsAt: true, endsAt: true } });
    return { classes, teachers, subjects, assessedStudents, admissions, activities, events };
  });
  return { ...report, academic, fundraising };
}

export async function teachersDirectory(actor: AuthenticatedUser, query: TeacherDirectoryQuery) {
  const orgId = tenant(actor);
  const where: Prisma.UserWhereInput = { orgId, role: "TEACHER", ...(query.status ? { status: query.status } : {}),
    ...(query.search ? { OR: [{ fullName: { contains: query.search } }, { email: { contains: query.search } }, { phone: { contains: query.search } }] } : {}) };
  return prisma.$transaction(async (tx) => {
    const totalItems = await tx.user.count({ where });
    const items = await tx.user.findMany({ where, skip: (query.page - 1) * query.pageSize, take: query.pageSize,
      orderBy: [{ fullName: "asc" }, { id: "asc" }], select: {
        id: true, fullName: true, email: true, phone: true, status: true, createdAt: true,
        branch: { select: { id: true, name: true } },
        taughtClasses: { select: { id: true, name: true, academicYear: true, _count: { select: { currentStudents: true } } }, orderBy: { name: "asc" } },
        teachingCourses: { select: { id: true, title: true, subject: { select: { id: true, name: true } } }, orderBy: { title: "asc" } },
      } });
    const total = await tx.user.count({ where: { orgId, role: "TEACHER" } });
    const active = await tx.user.count({ where: { orgId, role: "TEACHER", status: "ACTIVE" } });
    const assigned = await tx.user.count({ where: { orgId, role: "TEACHER", OR: [{ taughtClasses: { some: { orgId } } }, { teachingCourses: { some: { orgId } } }] } });
    const subjects = await tx.subject.count({ where: { orgId, courses: { some: { orgId, primaryInstructorUserId: { not: null } } } } });
    return { items, summary: { total, active, assigned, subjects }, meta: { page: query.page, pageSize: query.pageSize, totalItems, totalPages: Math.ceil(totalItems / query.pageSize) } };
  });
}

export async function subjectsDirectory(actor: AuthenticatedUser, query: DirectoryQuery) {
  const orgId = tenant(actor), where = { orgId, OR: [{ name: { contains: query.search } }, { code: { contains: query.search } }] };
  return prisma.$transaction(async (tx) => {
    const totalItems = await tx.subject.count({ where });
    const items = await tx.subject.findMany({ where, skip: (query.page - 1) * query.pageSize, take: query.pageSize,
      orderBy: [{ name: "asc" }, { id: "asc" }], select: {
        id: true, code: true, name: true, summary: true, category: true, isActive: true,
        _count: { select: { courses: true } },
      } });
    const courses = await tx.course.count({ where: { orgId } });
    const total = await tx.subject.count({ where: { orgId } });
    const active = await tx.subject.count({ where: { orgId, isActive: true } });
    const lessons = await tx.courseLesson.count({ where: { orgId } });
    return { items, summary: { total, active, courses, lessons },
      meta: { page: query.page, pageSize: query.pageSize, totalItems, totalPages: Math.ceil(totalItems / query.pageSize) } };
  });
}

export async function createEvent(actor: AuthenticatedUser, input: EventInput) {
  const orgId = tenant(actor);
  return prisma.$transaction(async (tx) => {
    const event = await tx.foundationEvent.create({ data: { orgId, title: input.title, location: input.location,
      startsAt: new Date(input.startsAt), endsAt: new Date(input.endsAt), createdById: BigInt(actor.userId) } });
    await tx.auditLog.create({ data: { orgId, actorUserId: BigInt(actor.userId), action: "event.created", entityType: "FoundationEvent", entityId: event.id.toString() } });
    return event;
  });
}

export async function cancelEvent(actor: AuthenticatedUser, id: string) {
  const orgId = tenant(actor);
  return prisma.$transaction(async (tx) => {
    const event = await tx.foundationEvent.findFirst({ where: { orgId, id: BigInt(id) } });
    if (!event) throw new HttpError(404, "Event not found");
    if (!event.cancelledAt) {
      await tx.foundationEvent.updateMany({ where: { orgId, id: event.id, cancelledAt: null }, data: { cancelledAt: new Date() } });
      await tx.auditLog.create({ data: { orgId, actorUserId: BigInt(actor.userId), action: "event.cancelled", entityType: "FoundationEvent", entityId: id } });
    }
    return { id, cancelled: true };
  });
}

export async function guardianDirectory(actor: AuthenticatedUser, query: DirectoryQuery) {
  const orgId = tenant(actor);
  const where = { orgId, OR: [{ fullName: { contains: query.search } }, { phone: { contains: query.search } }] };
  const [totalItems, items] = await prisma.$transaction([
    prisma.guardian.count({ where }),
    prisma.guardian.findMany({ where, skip: (query.page - 1) * query.pageSize, take: query.pageSize,
      orderBy: [{ fullName: "asc" }, { id: "asc" }], select: { id: true, fullName: true, phone: true } }),
  ]);
  return { items, meta: { page: query.page, pageSize: query.pageSize, totalItems, totalPages: Math.ceil(totalItems / query.pageSize) } };
}

export async function studentDemographics(actor: AuthenticatedUser) {
  const orgId = tenant(actor), current = recentMonths()[5]!;
  return prisma.$transaction(async (tx) => {
    const total = await tx.student.count({ where: { orgId } });
    const male = await tx.student.count({ where: { orgId, gender: "male" } });
    const female = await tx.student.count({ where: { orgId, gender: "female" } });
    const newAdmissions = await tx.student.count({ where: { orgId, createdAt: { gte: current.from, lt: current.to } } });
    return { total, male, female, unspecified: total - male - female, newAdmissions, month: current.from.toISOString().slice(0, 7) };
  });
}
