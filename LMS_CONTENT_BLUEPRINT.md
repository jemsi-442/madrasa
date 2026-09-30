# MODERN ISLAMIC FOUNDATION LMS Content Blueprint

Last updated: `2026-10-01`

This document defines the recommended architecture for online learning for older students and course learners.

**Current implementation:** Backend subjects, courses, lessons, access grants, course invoices, and signed media-delivery redirects exist. Flutter has a dedicated course catalogue, curriculum, lesson reader, explicit completion and in-app audio/video/provider, PDF, raster-image and plain-text viewers. Lesson resources no longer launch an external browser. Native player code and fake-platform tests exist, but Android/iOS device playback is not verified (Android build is blocked by the local NDK license/setup). Large/resumable video uploads, provider transcoding/adaptive streaming integration, automatic subscription renewal, private streaming and DRM are not delivered. A redirect can reveal its upstream URL; short-lived app tokens alone do not protect a public source URL. See [Learner Portal](LEARNER_PORTAL_ARCHITECTURE.md) for current scope and verification.

It covers:

- course and lesson structure
- video, audio, and PDF delivery
- free and paid content access
- subject and instructor ownership
- learner ownership and entitlement rules
- media protection direction
- rollout order before implementation

## 1. Product Direction

The platform will then have two connected but distinct product layers:

- `Management System`
  - admissions
  - classes
  - attendance
  - finance
  - parent access
- `Learning Platform`
  - learner home
  - course library
  - lesson playback
  - learning progress
  - free and paid content access

Important rule:

- do not mix the learning platform into parent pages or teacher work pages by shortcut
- keep learner learning routes, APIs, and entitlements separate

## 1A. Subject And Teaching Ownership

The learning side may carry many subjects:

- dini / Qur'an / hifdh
- Arabic
- fiqh and aqeedah
- technology and digital skills
- business or vocational subjects later

Do not model all of these as one flat list of generic courses only.

Recommended ownership layers:

- `Subject`
  - the academic family
  - examples:
    - `Qur'an & Hifdh`
    - `Islamic Studies`
    - `Arabic`
    - `Programming`
    - `Design & Media`
- `Course`
  - the actual teachable offering inside a subject
  - examples:
    - `Tajwid Foundations`
    - `Python for Beginners`
    - `Canva Design Basics`
- `Instructor assignment`
  - the teacher responsible for teaching that course
- `Publishing authority`
  - the person allowed to make the course visible to learners

Recommended rule:

- `ADMIN` owns the catalog
- `TEACHER` owns lesson authoring only for assigned courses
- publishing should default to admin approval

This is the safest first model because:

- dini and tech subjects stay under one governance model
- teachers can build real content without owning catalog-wide publishing
- pricing, free/paid visibility, and learner exposure stay under office control

## 2. Content Model

Recommended learning structure:

- `Course`
  - top-level learning product
- `Module`
  - section inside a course
- `Lesson`
  - unit inside a module
- `Asset`
  - media item attached to a lesson

Recommended lesson asset types:

- `VIDEO`
- `AUDIO`
- `PDF`
- `ATTACHMENT`
- `TEXT`

Recommended content visibility states:

- `FREE`
- `PAID`
- `PREVIEW`
- `LOCKED`
- `UNLISTED`

Recommended publication states:

- `DRAFT`
- `PUBLISHED`
- `ARCHIVED`

## 3. Core Access Principle

Access must come from `entitlement`, not from page visibility.

A learner may open content only when one of these is true:

- the content is marked `FREE`
- the content is marked `PREVIEW`
- the learner has an active paid entitlement
- the learner was manually granted access
- the learner belongs to a course enrollment that includes the lesson

Important:

- `FREE` and `PAID` are access states
- they are not enough by themselves without backend entitlement checks

## 4. Recommended Database Direction

Recommended main tables or models:

- `Subject`
  - `id`
  - `slug`
  - `title`
  - `summary`
  - `category`
  - `isActive`
  - `createdByUserId`

- `Course`
  - `id`
  - `subjectId`
  - `slug`
  - `title`
  - `summary`
  - `description`
  - `thumbnailUrl`
  - `coverImageUrl`
  - `programCategory`
  - `deliveryMode`
  - `level`
  - `primaryInstructorUserId`
  - `visibility`
  - `publicationStatus`
  - `isFeatured`
  - `createdByUserId`
  - `publishedByUserId`
  - `publishedAt`

- `CourseModule`
  - `id`
  - `courseId`
  - `title`
  - `position`
  - `summary`

- `CourseLesson`
  - `id`
  - `courseId`
  - `moduleId`
  - `title`
  - `slug`
  - `summary`
  - `position`
  - `visibility`
  - `publicationStatus`
  - `estimatedMinutes`

- `MediaAsset`
  - `id`
  - `courseId`
  - `lessonId`
  - `assetType`
  - `storageProvider`
  - `storageKey`
  - `mimeType`
  - `durationSeconds`
  - `fileSizeBytes`
  - `visibility`
  - `downloadAllowed`
  - `streamingProfile`

- `CourseEnrollment`
  - `id`
  - `courseId`
  - `studentId`
  - `learnerUserId`
  - `status`
  - `startsAt`
  - `endsAt`
  - `grantedByUserId`

- `CoursePurchase`
  - `id`
  - `courseId`
  - `studentId`
  - `learnerUserId`
  - `invoiceId`
  - `paymentId`
  - `status`
  - `purchasedAt`
  - `expiresAt`

- `AccessGrant`
  - `id`
  - `courseId`
  - `lessonId`
  - `learnerUserId`
  - `grantType`
  - `startsAt`
  - `endsAt`
  - `grantedByUserId`

- `LessonProgress`
  - `id`
  - `lessonId`
  - `learnerUserId`
  - `studentId`
  - `watchSeconds`
  - `progressPercent`
  - `completedAt`
  - `lastOpenedAt`

- `AssetAccessLog`
  - `id`
  - `assetId`
  - `learnerUserId`
  - `studentId`
  - `ipAddress`
  - `userAgent`
  - `openedAt`

Recommended future optional tables:

- `CourseInstructor`
- `CourseEditor`
- `LessonNote`
- `LessonQuiz`
- `CourseReview`
- `DownloadAudit`

Recommended course metadata:

- `subjectId`
- `programCategory`
- `deliveryMode`
  - `SELF_PACED`
  - `COHORT`
  - `LIVE_PLUS_LIBRARY`
- `level`
  - `BEGINNER`
  - `INTERMEDIATE`
  - `ADVANCED`
- `language`
- `isReligious`
- `requiresApprovalBeforePublish`

## 5. Free And Paid Commerce Direction

Recommended commerce modes:

- `FREE`
  - no payment required
- `ONE_TIME_PURCHASE`
  - learner pays once for the course
- `SUBSCRIPTION`
  - learner stays active while subscription is active
- `GRANT`
  - office manually grants access

Recommended pricing model on course side:

- `pricingType`
  - `FREE`
  - `PAID`
- `priceAmount`
- `currency`
- `billingMode`
  - `ONE_TIME`
  - `SUBSCRIPTION`

Recommended access flow for paid courses:

1. learner sees course
2. learner opens course detail
3. backend checks entitlement
4. if not entitled, learner sees purchase gate
5. payment creates invoice/payment trail
6. successful payment creates purchase or access grant
7. learner can now request lesson playback

## 6. Media Protection Direction

Important reality:

- no video, audio, or PDF system is perfectly uncopyable once a human may view it

Correct goal:

- make access controlled, traceable, and difficult to abuse

Recommended protection layers:

### Video

- use `HLS` playback where possible
- issue short-lived signed playback URLs
- do not expose permanent storage URLs directly
- log playback access
- optionally add visible watermark overlay later

### Audio

- use signed asset URLs
- short-lived tokens
- audit access

### PDF

- serve through protected viewer routes
- avoid public direct file links
- optionally watermark rendered PDF view with learner identity later

### General content

- entitlement check before asset access
- branch and org validation where relevant
- asset token expiry
- access logs
- optional rate limiting for repeated token requests

Recommended first protection scope:

- signed URLs
- short expiry
- access log
- no public raw links

Recommended later scope:

- watermarking
- segmented streaming
- forensic download tracing

## 7. Recommended API Surface

### Public course discovery

- `GET /api/courses`
  - list published courses
  - supports filters:
    - `programCategory?`
    - `pricingType?`
    - `search?`

- `GET /api/courses/:slug`
  - course detail
  - show only published and visible lessons
  - mark lessons as `FREE`, `PREVIEW`, or `LOCKED`

### Learner self-service

- `GET /api/learner/library`
  - learner course library

- `GET /api/learner/courses/:courseId`
  - owned course detail with learner progress

- `GET /api/learner/lessons/:lessonId`
  - lesson detail with owned access context

- `POST /api/learner/lessons/:lessonId/progress`
  - update watched progress

- `GET /api/learner/finance/courses`
  - learner course billing summary

### Protected media

- `POST /api/learner/assets/:assetId/access`
  - returns short-lived signed playback or view token

- `GET /api/learner/assets/:assetId/stream`
  - optional controlled stream endpoint when direct signed URL is not enough

### Office and content management

- `GET /api/subjects`
- `POST /api/subjects`
- `PATCH /api/subjects/:id`
- `POST /api/courses`
- `PATCH /api/courses/:id`
- `POST /api/courses/:id/instructors`
- `POST /api/courses/:id/publish`
- `POST /api/courses/:id/archive`
- `POST /api/courses/:id/modules`
- `POST /api/modules/:id/lessons`
- `POST /api/lessons/:id/assets`
- `POST /api/courses/:id/grants`
- `GET /api/courses/:id/enrollments`
- `GET /api/courses/:id/analytics`

### Teacher authoring

- `GET /api/teaching/courses`
  - assigned courses only
- `GET /api/teaching/courses/:id`
  - assigned course detail only
- `POST /api/teaching/courses/:id/modules`
  - draft authoring only for assigned course
- `POST /api/teaching/lessons/:id/assets`
  - upload assets only for assigned course lesson
- `PATCH /api/teaching/courses/:id/submit`
  - submit draft for admin review

## 8. Role Direction Around LMS

Recommended role direction:

- `ADMIN`
  - governance, pricing, publishing, grants, analytics oversight
- `ACCOUNTANT`
  - course billing, paid entitlement follow-up, receipts
- `TEACHER`
  - assigned course authoring
  - lesson and asset drafting for assigned courses
  - no catalog-wide publishing by default
- `LEARNER`
  - self-service learning access

Recommended future option:

- add `INSTRUCTOR` only if course-teaching responsibilities become meaningfully different from school-teacher responsibilities

Recommended first governance rule:

- keep `TEACHER` as the instructor role at first
- add `INSTRUCTOR` later only if:
  - many non-school instructors join
  - course teaching becomes separate from school teaching
  - LMS authoring needs full separation from school-teaching flows

## 8A. Recommended Subject Workflow

Recommended workflow when a new subject or course is introduced:

1. `ADMIN` creates the subject family
   - example: `Technology`
2. `ADMIN` creates the course shell
   - example: `Python for Beginners`
3. `ADMIN` assigns the responsible teacher
4. `TEACHER` adds:
   - modules
   - lessons
   - video, audio, PDF, and text assets
5. course remains in `DRAFT`
6. `TEACHER` submits for review
7. `ADMIN` checks:
   - content quality
   - audience
   - free vs paid status
   - pricing if needed
8. `ADMIN` publishes

This should be the default first model.

Later, you may allow:

- trusted teachers to self-publish inside assigned subject families
- but only after moderation and ownership rules are already stable

## 9. Learner UX Direction

Recommended learner surfaces:

- `Learner Home`
- `My Courses`
- `Course Detail`
- `Lesson Player`
- `My Billing`
- `My Receipts`
- `My Updates`

Recommended lesson player behavior:

- left or top lesson navigation
- central player area
- lesson resources tab
- progress saved automatically
- locked lesson clearly marked

Recommended access messaging:

- `Free lesson`
- `Preview lesson`
- `Included in your access`
- `Purchase required`
- avoid technical wording on learner UI

## 10. Recommended Phase Order

### Phase 1

- `LEARNER` auth support
- learner home
- `Subject` model
- course model
- course discovery
- free lessons
- learner announcements

### Phase 2

- paid course purchase gate
- invoices and purchase entitlement
- learner billing and receipts
- protected PDF and audio delivery

### Phase 3

- protected video playback
- lesson progress tracking
- learner library
- basic course analytics

### Phase 4

- subscriptions
- watermarking
- advanced analytics
- instructor dashboards

## 11. Guardrails Before Coding

Before expanding media and subscription delivery:

- choose private media storage and streaming strategy
- define subscription renewal, expiry, and refund behavior
- define how upstream asset URLs remain private after a signed redirect
- add Flutter course and lesson playback pages with access tests
- verify purchase ownership and entitlement revocation rules

Do not start with:

- raw public file links
- unscoped lesson access by `lessonId` only
- complex DRM before entitlement basics exist
- mixing learner course pages into parent portal pages
