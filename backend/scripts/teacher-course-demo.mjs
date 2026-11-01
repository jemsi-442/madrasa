export const teacherDemoSlug = 'afaq-teacher-media-demo';

export async function ensureTeacherCourseDemo(db) {
  return db.$transaction(async tx => {
    const org = await tx.organization.findUnique({ where: { code: 'demo-madrasa' } });
    if (!org || org.status !== 'ACTIVE') throw new Error('Active demo madrasa required.');
    const teacher = await tx.user.findFirst({ where: { orgId: org.id,
      email: 'quran.teacher@afaq.test', role: 'TEACHER', status: 'ACTIVE' } });
    if (!teacher) throw new Error('Active demo teacher required.');
    const existing = await tx.course.findUnique({ where: { orgId_slug: { orgId: org.id, slug: teacherDemoSlug } } });
    if (existing) {
      if (existing.primaryInstructorUserId !== teacher.id) throw new Error('Demo course assignment differs; nothing was overwritten.');
      return { created: false, courseId: existing.id.toString() };
    }
    // Reuse an existing synthetic technology subject instead of making duplicates.
    const subject = await tx.subject.findFirst({ where: { orgId: org.id, code: { startsWith: 'TECH-' } }, orderBy: { id: 'asc' } });
    if (!subject) throw new Error('Existing demo technology subject required.');
    const course = await tx.course.create({ data: { orgId: org.id, subjectId: subject.id,
      slug: teacherDemoSlug, title: 'Teacher media practice (Demo)',
      summary: 'Synthetic player practice only, not Quran or approved teaching content.',
      primaryInstructorUserId: teacher.id, createdByUserId: teacher.id,
      publicationStatus: 'DRAFT', visibility: 'UNLISTED', isReligious: false } });
    const module = await tx.courseModule.create({ data: { orgId: org.id, courseId: course.id,
      title: 'Practice the lesson player', position: 1 } });
    const lessons = [
      { slug: 'video-and-audio', title: 'Video and audio practice',
        content: 'Demo only. Try play, pause and seeking. The video has no sound; the audio is synthetic tones, not Quran recitation.',
        assets: [['VIDEO', 'video/mp4', 'afaq-demo:video', 'Silent sample video'], ['AUDIO', 'audio/mp4', 'afaq-demo:audio', 'Synthetic sample tones']] },
      { slug: 'documents', title: 'Document practice',
        content: 'Demo only. Open the guide and checklist. Viewing these samples does not record learner achievement.',
        assets: [['PDF', 'application/pdf', 'afaq-demo:pdf', 'Player guide'], ['TEXT', 'text/plain', 'afaq-demo:text', 'Practice checklist']] },
    ];
    for (const [index, item] of lessons.entries()) {
      const lesson = await tx.courseLesson.create({ data: { orgId: org.id, courseId: course.id,
        moduleId: module.id, slug: item.slug, title: item.title, contentText: item.content,
        position: index + 1, publicationStatus: 'DRAFT', visibility: 'UNLISTED' } });
      for (const [assetType, mimeType, storageKey, title] of item.assets) {
        await tx.mediaAsset.create({ data: { orgId: org.id, courseId: course.id, lessonId: lesson.id,
          assetType, mimeType, storageKey, title, storageProvider: 'LOCAL', visibility: 'UNLISTED' } });
      }
    }
    return { created: true, courseId: course.id.toString() };
  });
}
