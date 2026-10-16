// Synthetic lesson-planning examples, not approved teaching material.
export const curriculumDemoData = [
  {
    subject: 'Arabic (Demo)', level: 'Level 1', prefix: 'AR1',
    topics: [
      { title: 'Letter recognition', skills: ['Identify five letters on teacher-provided cards', 'Match a spoken letter with its written form'], criteria: ['Identify four of five letters independently', 'Match four of five spoken letters correctly'], method: 'ORAL' },
      { title: 'Early writing', skills: ['Copy three letters using a teacher-provided model', 'Distinguish letter shapes in a matching exercise'], criteria: ['Copy three model letters legibly with teacher feedback', 'Complete four of five letter-shape matches correctly'], method: 'WRITTEN' },
    ],
  },
  {
    subject: 'Arabic (Demo)', level: 'Level 2', prefix: 'AR2',
    topics: [
      { title: 'Word reading', skills: ['Read five familiar words from a teacher-prepared list', 'Connect a familiar written word with its picture'], criteria: ['Read four of five familiar words clearly', 'Match four of five words to the correct pictures'], method: 'ORAL' },
      { title: 'Short sentences', skills: ['Write a short sentence using a supplied word bank', 'Arrange word cards into a sentence using a checked model'], criteria: ['Write one readable sentence following the supplied model', 'Arrange the cards correctly and explain the order'], method: 'WRITTEN' },
    ],
  },
  {
    subject: 'Akhlaq (Demo)', level: 'Level 1', prefix: 'AK1',
    topics: [
      { title: 'Respectful communication', skills: ['Demonstrate taking turns during a paired conversation', 'Respond respectfully when a classmate has a different view'], criteria: ['Allow the partner to finish speaking in two practice rounds', 'Use a respectful response in a teacher-provided scenario'], method: 'OBSERVATION' },
      { title: 'Care and responsibility', skills: ['Return shared learning materials after an activity', 'Describe a helpful response to a classroom problem'], criteria: ['Return materials safely to their labelled place', 'Suggest one practical action that helps others'], method: 'PRACTICAL' },
    ],
  },
  {
    subject: 'Hadith (Demo)', level: 'Level 1', prefix: 'HD1',
    topics: [
      { title: 'Listening and understanding', skills: ['Listen to a teacher-selected verified text and identify its theme', 'Explain one idea using the education-team-checked explanation'], criteria: ['Identify the theme using the teacher-provided answer guide', 'Explain the idea without adding unsupported claims'], method: 'ORAL' },
      { title: 'Reflection and application', skills: ['Relate a checked teaching example to a daily situation', 'Identify when a question needs guidance from the teacher'], criteria: ['Give one relevant example consistent with the checked explanation', 'Ask a clear question rather than inventing an answer'], method: 'OBSERVATION' },
    ],
  },
  {
    subject: "Qur'an (Demo)", level: 'Level 1', prefix: 'QR1',
    topics: [
      { title: 'Guided recitation preparation', skills: ['Follow a teacher-assigned passage using a verified source', 'Apply feedback during a guided reading attempt'], criteria: ['Follow the assigned passage as checked by the teacher', 'Demonstrate one improvement against the teacher checklist'], method: 'ORAL' },
      { title: 'Revision habits', skills: ['Follow a teacher-planned revision routine', 'Identify a passage requiring additional teacher support'], criteria: ['Complete the practice steps on the teacher-provided plan', 'Identify a specific difficulty for teacher follow-up'], method: 'OBSERVATION' },
    ],
  },
  {
    subject: 'Islamic History (Demo)', level: 'Level 2', prefix: 'IH2',
    topics: [
      { title: 'Working with checked sources', skills: ['Identify the source of a teacher-provided historical account', 'Distinguish information in the source from a personal opinion'], criteria: ['Name the supplied source using its classroom reference', 'Correctly classify three of four teacher-provided examples'], method: 'ORAL' },
      { title: 'Sequence and reflection', skills: ['Order three events from a checked classroom account', 'Summarise one lesson from the account in simple words'], criteria: ['Place the supplied event cards in the documented order', 'Give a short summary consistent with the checked source'], method: 'WRITTEN' },
    ],
  },
] as const;
