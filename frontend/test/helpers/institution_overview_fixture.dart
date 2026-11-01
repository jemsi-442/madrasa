Map<String, dynamic> institutionOverviewFixture({bool empty = false}) => {
  'checkedAt': '2026-10-08T00:00:00Z',
  'awaitingYourReview': 7,
  'onboarding': {'awaitingSetup': 2, 'pendingActivation': 1},
  'institution': {
    'month': '2026-10',
    'summary': {
      'madrasas': empty ? 0 : 6,
      'learners': empty ? 0 : 520,
      'teachers': empty ? 0 : 30,
      'withLearningRecords': empty ? 0 : 4,
      'openSupportNotes': empty ? 0 : 5,
      'lessonsTaught': empty ? 0 : 18,
      'quranObservations': empty ? 0 : 19,
    },
    'madrasas': [
      if (!empty)
        {
          'name': 'Synthetic Madrasa',
          'code': 'AFQ-000001',
          'learners': 120,
          'teachers': 7,
          'hasLearningRecords': true,
        },
    ],
    'receipts': <dynamic>[],
    'pledges': <dynamic>[],
  },
};
