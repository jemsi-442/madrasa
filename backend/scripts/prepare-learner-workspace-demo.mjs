import { PrismaClient } from '@prisma/client';
import { fileURLToPath } from 'node:url';
import { developmentEnvironment } from './development-config.mjs';

if (process.argv[2] !== '--confirm-local-development') throw new Error('Local development confirmation required.');
const env = await developmentEnvironment(fileURLToPath(new URL('../.env', import.meta.url)));
const db = new PrismaClient({ datasources: { db: { url: env.DATABASE_URL } } });
try {
  const result = await db.$transaction(async tx => {
    const org = await tx.organization.findUnique({ where: { code: 'demo-madrasa' } });
    if (!org || org.status !== 'ACTIVE') throw new Error('Active demo madrasa required.');
    const slug = 'afaq-learner-workspace-demo';
    const existing = await tx.course.findUnique({ where: { orgId_slug: { orgId: org.id, slug } } });
    if (existing) return { created: false, courseId: String(existing.id) };
    const admin = await tx.user.findFirst({ where: { orgId: org.id, role: 'ADMIN', status: 'ACTIVE' } });
    const subject = await tx.subject.findFirst({ where: { orgId: org.id, code: { startsWith: 'TECH-' }, isActive: true }, orderBy: { id: 'asc' } });
    if (!admin || !subject) throw new Error('Existing demo administrator and technology subject required.');
    const course = await tx.course.create({ data: {
      orgId: org.id, subjectId: subject.id, slug,
      title: 'Digital learning essentials (Demo)',
      summary: 'Practise video lessons, audio and learning resources in your Afaq workspace.',
      description: 'Synthetic demonstration only. This is not assessed or approved religious teaching content.',
      programCategory: 'COURSE_STUDENT', level: 'Getting started',
      createdByUserId: admin.id, publishedByUserId: admin.id,
      publicationStatus: 'PUBLISHED', publishedAt: new Date(), visibility: 'FREE',
    } });
    const module = await tx.courseModule.create({ data: { orgId: org.id, courseId: course.id, title: 'Learning with Afaq', position: 1 } });
    const titles = ['Explore your learning workspace', 'Work with lesson resources', 'Review your learning'];
    for (const [index, title] of titles.entries()) {
      const lesson = await tx.courseLesson.create({ data: {
        orgId: org.id, courseId: course.id, moduleId: module.id,
        slug: `practice-${index + 1}`, title, position: index + 1,
        summary: 'A synthetic practice lesson with local sample media.',
        contentText: 'Try the sample video and supporting resources. The video is silent and the audio uses synthetic tones. Mark this practice lesson complete only when you choose to finish.',
        publicationStatus: 'PUBLISHED', visibility: 'FREE',
      } });
      for (const [assetType, mimeType, key, title] of [
        ['VIDEO', 'video/mp4', 'video', 'Silent sample video'],
        ['AUDIO', 'audio/mp4', 'audio', 'Sample audio tones'],
        ['PDF', 'application/pdf', 'pdf', 'Practice guide'],
        ['TEXT', 'text/plain', 'text', 'Lesson checklist'],
      ]) await tx.mediaAsset.create({ data: {
        orgId: org.id, courseId: course.id, lessonId: lesson.id,
        assetType, mimeType, title, storageKey: `afaq-demo:${key}`,
        storageProvider: 'LOCAL', visibility: 'FREE',
      } });
    }
    return { created: true, courseId: String(course.id) };
  });
  console.log(JSON.stringify(result));
} finally {
  await db.$disconnect();
}
