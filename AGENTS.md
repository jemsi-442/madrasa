# Afaq Project Instructions

- Preserve existing Afaq branding, shared UI components, authentication and unrelated modules.
- Enforce permissions on the server, including institution, madrasa, class and student scope. IT and accountant roles do not grant curriculum-edit access.
- Use synthetic learner data in tests. Never print credentials or real child records.
- Do not deploy or run production migrations without explicit approval.
- Superadmin curriculum flow is Draft -> Published -> Madrasa assignment, without submission or approval. Superadmins may edit any unpublished version and publish directly after validation. Preserve legacy review history; published content and historical learner/report records must not be overwritten.
- Distinguish madrasa availability from active class/teacher adoption, teaching coverage from assessment coverage, and achievement from viewing resources.
- Lessons and learning objectives have a many-to-many relationship. Do not match achievements between versions by name.
- Reuse existing subjects, classes, students, teachers, media, reporting and verified Quran metadata. Never generate Quran text or verse mappings.
- Offline learning events require persistent storage, unique client event IDs and server-side permission rechecks. Publication and assignment changes stay online.
- Build database, API, UI and tests in working increments. Report unfinished integrations explicitly; a working UI alone does not complete the module.
