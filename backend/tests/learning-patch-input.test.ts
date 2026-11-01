import { describe, expect, it } from 'vitest';
import { createCourseLessonSchema, updateCourseSchema, updateCourseModuleSchema,
  updateCourseLessonSchema, updateLessonAssetSchema } from '../src/modules/learning/learning.schemas';

describe('learning partial updates', () => {
  for (const [name, schema] of Object.entries({
    course: updateCourseSchema, module: updateCourseModuleSchema,
    lesson: updateCourseLessonSchema, asset: updateLessonAssetSchema,
  })) {
    it(`${name} changes only the supplied title`, () => {
      expect(schema.parse({ title: 'Updated title' })).toEqual({ title: 'Updated title' });
    });
    it(`${name} rejects empty or unknown-only changes`, () => {
      expect(schema.safeParse({}).success).toBe(false);
      expect(schema.safeParse({ unknownField: true }).success).toBe(false);
    });
  }
  it('retains explicitly supplied publication and access changes', () => {
    const input = { publicationStatus: 'PUBLISHED', visibility: 'PREVIEW' };
    expect(updateCourseLessonSchema.parse(input)).toEqual(input);
    expect(updateCourseSchema.parse({ isFeatured: false })).toEqual({ isFeatured: false });
    expect(updateLessonAssetSchema.parse({ downloadAllowed: false })).toEqual({ downloadAllowed: false });
  });
  it('still applies safe defaults when creating a lesson', () => {
    expect(createCourseLessonSchema.parse({ title: 'Lesson', slug: 'lesson', position: 1 }))
      .toMatchObject({ publicationStatus: 'DRAFT', visibility: 'LOCKED' });
  });
});
