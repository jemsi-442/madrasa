import { z } from 'zod';

export const curriculumLessonInput = z.object({
  title: z.string().trim().min(2).max(150),
  position: z.number().int().min(1).max(1000),
  durationMinutes: z.number().int().min(1).max(480),
  activities: z.string().trim().min(10).max(10000),
  objectiveIds: z.array(z.string().min(1).max(30)).min(1).max(50),
}).strict().refine(value => new Set(value.objectiveIds).size === value.objectiveIds.length,
  { path: ['objectiveIds'], message: 'Select each objective only once' });

export const objectiveInput = z.object({
  code: z.string().trim().min(1).max(40).regex(/^[A-Za-z0-9_-]+$/),
  description: z.string().trim().min(10).max(1000),
  assessmentMethod: z.enum(['ORAL', 'WRITTEN', 'PRACTICAL', 'OBSERVATION']),
  criteria: z.string().trim().min(10).max(1000),
}).strict();

export const topicInput = z.object({
  title: z.string().trim().min(2).max(150),
  position: z.number().int().min(1).max(1000),
  objectives: z.array(objectiveInput).min(1).max(50),
}).strict().refine(value => new Set(value.objectives.map(o => o.code.toLowerCase())).size === value.objectives.length,
  { path: ['objectives'], message: 'Objective codes must be unique within this topic' });

export const publicationContent = z.object({
  level: z.string().trim().min(1).max(80),
  topics: z.array(z.object({
    title: z.string().trim().min(2),
    objectives: z.array(objectiveInput.passthrough()).min(1),
  })).min(1),
});
