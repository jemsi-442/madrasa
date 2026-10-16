import { expect, it } from 'vitest';
import { curriculumDemoData } from '../scripts/curriculum-demo-data';
import { topicInput } from '../src/modules/platform/curriculum-content';

it('provides six distinct subject-level examples with valid measurable objectives', () => {
  expect(curriculumDemoData).toHaveLength(6);
  expect(new Set(curriculumDemoData.map(d => `${d.subject}:${d.level}`)).size).toBe(6);
  for (const example of curriculumDemoData) {
    expect(example.subject).toContain('(Demo)');
    for (const [index, topic] of example.topics.entries()) {
      const parsed = topicInput.parse({ title: topic.title, position: index + 1,
        objectives: topic.skills.map((description, i) => ({
          code: `${example.prefix}-${index + 1}${i + 1}`, description,
          assessmentMethod: topic.method, criteria: topic.criteria[i],
        })),
      });
      expect(parsed.objectives).toHaveLength(2);
    }
  }
});
