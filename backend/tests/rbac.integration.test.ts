import { describe, expect, it } from "vitest";

import {
  api,
  loginAsAccountant,
  loginAsAdmin,
  loginAsLearner,
  loginAsParent,
  loginAsTeacher,
} from "./helpers/api-client";

describe("rbac integration", () => {
  it("enforces role boundaries across core routes", async () => {
    const [adminLogin, accountantLogin, teacherLogin, parentLogin, learnerLogin] = await Promise.all([
      loginAsAdmin(),
      loginAsAccountant(),
      loginAsTeacher(),
      loginAsParent(),
      loginAsLearner(),
    ]);

    expect(adminLogin.status).toBe(200);
    expect(accountantLogin.status).toBe(200);
    expect(teacherLogin.status).toBe(200);
    expect(parentLogin.status).toBe(200);
    expect(learnerLogin.status).toBe(200);

    const adminToken = adminLogin.body.data.accessToken as string;
    const accountantToken = accountantLogin.body.data.accessToken as string;
    const teacherToken = teacherLogin.body.data.accessToken as string;
    const parentToken = parentLogin.body.data.accessToken as string;
    const learnerToken = learnerLogin.body.data.accessToken as string;

    const accountantBlockedFromStudentWrite = await api
      .post("/api/students")
      .set("Authorization", `Bearer ${accountantToken}`)
      .send({
        admissionNo: "RBAC-ACC-001",
        fullName: "Blocked Accountant Student",
        gender: "MALE",
        branchId: "1",
        guardian: {
          fullName: "Guardian Example",
          phone: "255799000001",
        },
      });

    expect(accountantBlockedFromStudentWrite.status).toBe(403);

    const teacherBlockedFromOperationsDashboard = await api
      .get("/api/reports/dashboard")
      .set("Authorization", `Bearer ${teacherToken}`);

    expect(teacherBlockedFromOperationsDashboard.status).toBe(403);

    const accountantBlockedFromOperationsDashboard = await api
      .get("/api/reports/dashboard")
      .set("Authorization", `Bearer ${accountantToken}`);

    expect(accountantBlockedFromOperationsDashboard.status).toBe(403);

    const parentBlockedFromFinanceWorkspace = await api
      .get("/api/invoices")
      .set("Authorization", `Bearer ${parentToken}`);

    expect(parentBlockedFromFinanceWorkspace.status).toBe(403);

    const learnerProfile = await api
      .get("/api/learner/me")
      .set("Authorization", `Bearer ${learnerToken}`);

    expect(learnerProfile.status).toBe(200);
    expect(learnerProfile.body.data.user.role).toBe("LEARNER");
    expect(learnerProfile.body.data.student.id).toBeTruthy();

    const learnerAttendance = await api
      .get("/api/learner/attendance")
      .set("Authorization", `Bearer ${learnerToken}`);

    expect(learnerAttendance.status).toBe(200);

    const learnerFinance = await api
      .get("/api/learner/finance")
      .set("Authorization", `Bearer ${learnerToken}`);

    expect(learnerFinance.status).toBe(200);

    const learnerReceipts = await api
      .get("/api/learner/receipts")
      .set("Authorization", `Bearer ${learnerToken}`);

    expect(learnerReceipts.status).toBe(200);

    const learnerHifdh = await api
      .get("/api/learner/hifdh")
      .set("Authorization", `Bearer ${learnerToken}`);

    expect(learnerHifdh.status).toBe(200);

    const learnerAnnouncements = await api
      .get("/api/learner/announcements")
      .set("Authorization", `Bearer ${learnerToken}`);

    expect(learnerAnnouncements.status).toBe(200);

    const teacherBlockedFromSubjectCreate = await api
      .post("/api/subjects")
      .set("Authorization", `Bearer ${teacherToken}`)
      .send({
        code: "TECH-BLOCKED",
        slug: "tech-blocked",
        name: "Blocked Subject",
        category: "TECHNICAL",
      });

    expect(teacherBlockedFromSubjectCreate.status).toBe(403);

    const accountantBlockedFromSubjects = await api
      .get("/api/subjects")
      .set("Authorization", `Bearer ${accountantToken}`);

    expect(accountantBlockedFromSubjects.status).toBe(403);

    const parentBlockedFromLearnerProfile = await api
      .get("/api/learner/me")
      .set("Authorization", `Bearer ${parentToken}`);

    expect(parentBlockedFromLearnerProfile.status).toBe(403);

    const accountantBlockedFromTeacherDashboard = await api
      .get("/api/reports/teacher-dashboard")
      .set("Authorization", `Bearer ${accountantToken}`);

    expect(accountantBlockedFromTeacherDashboard.status).toBe(403);

    const accountantBlockedFromGuardiansList = await api
      .get("/api/guardians")
      .set("Authorization", `Bearer ${accountantToken}`);

    expect(accountantBlockedFromGuardiansList.status).toBe(403);

    const teacherBlockedFromFinanceReports = await api
      .get("/api/reports/finance/monthly-summary?year=2026")
      .set("Authorization", `Bearer ${teacherToken}`);

    expect(teacherBlockedFromFinanceReports.status).toBe(403);

    const teacherBlockedFromPaymentsOffice = await api
      .get("/api/payments")
      .set("Authorization", `Bearer ${teacherToken}`);

    expect(teacherBlockedFromPaymentsOffice.status).toBe(403);

    const teacherBlockedFromAnnouncementWrite = await api
      .post("/api/announcements")
      .set("Authorization", `Bearer ${teacherToken}`)
      .send({
        title: "Teacher should not publish this",
        message: "Teachers should not create organization announcements directly.",
        audience: "TEACHERS",
        publishAt: new Date().toISOString(),
      });

    expect(teacherBlockedFromAnnouncementWrite.status).toBe(403);

    const accountantBlockedFromClassAttendance = await api
      .get("/api/attendance/class/1")
      .set("Authorization", `Bearer ${accountantToken}`);

    expect(accountantBlockedFromClassAttendance.status).toBe(403);

    const accountantBlockedFromStudentAttendance = await api
      .get("/api/attendance/student/1")
      .set("Authorization", `Bearer ${accountantToken}`);

    expect(accountantBlockedFromStudentAttendance.status).toBe(403);

    const parentBlockedFromAttendanceSummary = await api
      .get("/api/reports/attendance/summary")
      .set("Authorization", `Bearer ${parentToken}`);

    expect(parentBlockedFromAttendanceSummary.status).toBe(403);

    const publicationStamp = Date.now();

    const adminSubjectCreate = await api
      .post("/api/subjects")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({
        code: `TECH-${publicationStamp}`,
        slug: `tech-${publicationStamp}`,
        name: `Technology ${publicationStamp}`,
        summary: "Technology learning catalog",
        category: "TECHNICAL",
        isCore: false,
        isActive: true,
      });

    expect(adminSubjectCreate.status).toBe(201);

    const createdSubjectId = adminSubjectCreate.body.data.id as string;

    const adminCourseCreate = await api
      .post("/api/courses")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({
        subjectId: createdSubjectId,
        slug: `intro-tech-${publicationStamp}`,
        title: `Intro to Technology ${publicationStamp}`,
        summary: "Assigned technology course",
        description: "Teacher-authored course shell for LMS rollout.",
        programCategory: "MADRASA_CHILD",
        deliveryMode: "SELF_PACED",
        visibility: "PAID",
        priceAmount: "25000",
        currency: "TZS",
        billingMode: "ONE_TIME",
        publicationStatus: "PUBLISHED",
        isFeatured: false,
        isReligious: false,
        requiresApprovalBeforePublish: true,
        primaryInstructorUserId: teacherLogin.body.data.user.id as string,
      });

    expect(adminCourseCreate.status).toBe(201);

    const createdCourseId = adminCourseCreate.body.data.id as string;

    const adminUnassignedCourseCreate = await api
      .post("/api/courses")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({
        subjectId: createdSubjectId,
        slug: `office-reference-${publicationStamp}`,
        title: `Office Reference ${publicationStamp}`,
        summary: "Unassigned office-owned course shell",
        description: "Used to verify teacher authoring boundaries.",
        programCategory: "MADRASA_CHILD",
        deliveryMode: "SELF_PACED",
        visibility: "LOCKED",
        publicationStatus: "DRAFT",
        isFeatured: false,
        isReligious: false,
        requiresApprovalBeforePublish: true,
      });

    expect(adminUnassignedCourseCreate.status).toBe(201);

    const unassignedCourseId = adminUnassignedCourseCreate.body.data.id as string;

    const teacherAssignedCourses = await api
      .get("/api/teaching/courses")
      .set("Authorization", `Bearer ${teacherToken}`);

    expect(teacherAssignedCourses.status).toBe(200);
    expect(
      (teacherAssignedCourses.body.data as Array<{ id: string }>).some(
        (course) => course.id === createdCourseId,
      ),
    ).toBe(true);

    const teacherBlockedFromCourseCreate = await api
      .post("/api/courses")
      .set("Authorization", `Bearer ${teacherToken}`)
      .send({
        subjectId: createdSubjectId,
        slug: `teacher-blocked-${publicationStamp}`,
        title: "Teacher Blocked Course",
        summary: "Teacher should not create course shells directly",
      });

    expect(teacherBlockedFromCourseCreate.status).toBe(403);

    const accountantBlockedFromTeachingCourses = await api
      .get("/api/teaching/courses")
      .set("Authorization", `Bearer ${accountantToken}`);

    expect(accountantBlockedFromTeachingCourses.status).toBe(403);

    const teacherModuleCreate = await api
      .post(`/api/courses/${createdCourseId}/modules`)
      .set("Authorization", `Bearer ${teacherToken}`)
      .send({
        title: "Module One",
        position: 1,
        summary: "Opening module for assigned course",
      });

    expect(teacherModuleCreate.status).toBe(201);

    const createdModuleId = teacherModuleCreate.body.data.id as string;

    const teacherModuleList = await api
      .get(`/api/courses/${createdCourseId}/modules`)
      .set("Authorization", `Bearer ${teacherToken}`);

    expect(teacherModuleList.status).toBe(200);
    expect(
      (teacherModuleList.body.data as Array<{ id: string }>).some((moduleRecord) => moduleRecord.id === createdModuleId),
    ).toBe(true);

    const teacherModuleUpdate = await api
      .patch(`/api/courses/modules/${createdModuleId}`)
      .set("Authorization", `Bearer ${teacherToken}`)
      .send({
        title: "Module One Updated",
        summary: "Updated opening module summary",
      });

    expect(teacherModuleUpdate.status).toBe(200);
    expect(teacherModuleUpdate.body.data.title).toBe("Module One Updated");

    const teacherBlockedFromForeignCourseModule = await api
      .post(`/api/courses/${unassignedCourseId}/modules`)
      .set("Authorization", `Bearer ${teacherToken}`)
      .send({
        title: "Blocked Module",
        position: 1,
      });

    expect(teacherBlockedFromForeignCourseModule.status).toBe(403);

    const teacherLessonCreate = await api
      .post(`/api/courses/modules/${createdModuleId}/lessons`)
      .set("Authorization", `Bearer ${teacherToken}`)
      .send({
        title: "Lesson One",
        slug: `lesson-one-${publicationStamp}`,
        summary: "Intro lesson",
        contentText: "Lesson text content",
        position: 1,
        visibility: "PREVIEW",
        publicationStatus: "PUBLISHED",
        estimatedMinutes: 12,
      });

    expect(teacherLessonCreate.status).toBe(201);

    const createdLessonId = teacherLessonCreate.body.data.id as string;

    const teacherPaidLessonCreate = await api
      .post(`/api/courses/modules/${createdModuleId}/lessons`)
      .set("Authorization", `Bearer ${teacherToken}`)
      .send({
        title: "Paid Lesson",
        slug: `paid-lesson-${publicationStamp}`,
        summary: "Locked paid lesson",
        contentText: "Paid lesson content",
        position: 2,
        visibility: "PAID",
        publicationStatus: "PUBLISHED",
        estimatedMinutes: 20,
      });

    expect(teacherPaidLessonCreate.status).toBe(201);

    const createdPaidLessonId = teacherPaidLessonCreate.body.data.id as string;

    const teacherLessonList = await api
      .get(`/api/courses/modules/${createdModuleId}/lessons`)
      .set("Authorization", `Bearer ${teacherToken}`);

    expect(teacherLessonList.status).toBe(200);
    expect(
      (teacherLessonList.body.data as Array<{ id: string }>).some((lesson) => lesson.id === createdLessonId),
    ).toBe(true);

    const teacherLessonUpdate = await api
      .patch(`/api/courses/lessons/${createdLessonId}`)
      .set("Authorization", `Bearer ${teacherToken}`)
      .send({
        summary: "Updated intro lesson summary",
        estimatedMinutes: 14,
      });

    expect(teacherLessonUpdate.status).toBe(200);
    expect(teacherLessonUpdate.body.data.summary).toBe("Updated intro lesson summary");

    const teacherAssetCreate = await api
      .post(`/api/courses/lessons/${createdLessonId}/assets`)
      .set("Authorization", `Bearer ${teacherToken}`)
      .send({
        assetType: "VIDEO",
        storageProvider: "EXTERNAL",
        title: "Lesson One Video",
        storageKey: `https://cdn.example.com/courses/${createdCourseId}/lesson-one.mp4`,
        mimeType: "video/mp4",
        durationSeconds: 360,
        visibility: "PREVIEW",
        downloadAllowed: false,
        streamingProfile: "720p",
      });

    expect(teacherAssetCreate.status).toBe(201);
    const createdAssetId = teacherAssetCreate.body.data.id as string;

    const teacherAssetList = await api
      .get(`/api/courses/lessons/${createdLessonId}/assets`)
      .set("Authorization", `Bearer ${teacherToken}`);

    expect(teacherAssetList.status).toBe(200);
    expect((teacherAssetList.body.data as Array<{ assetType: string }>)[0]?.assetType).toBe("VIDEO");

    const teacherAssetUpdate = await api
      .patch(`/api/courses/assets/${createdAssetId}`)
      .set("Authorization", `Bearer ${teacherToken}`)
      .send({
        title: "Lesson One Video Updated",
        streamingProfile: "1080p",
      });

    expect(teacherAssetUpdate.status).toBe(200);
    expect(teacherAssetUpdate.body.data.title).toBe("Lesson One Video Updated");

    const learnerCourseLibrary = await api
      .get("/api/learner/courses")
      .set("Authorization", `Bearer ${learnerToken}`);

    expect(learnerCourseLibrary.status).toBe(200);
    expect(
      (learnerCourseLibrary.body.data as Array<{ id: string }>).some((course) => course.id === createdCourseId),
    ).toBe(true);

    const learnerCourseDetail = await api
      .get(`/api/learner/courses/${createdCourseId}`)
      .set("Authorization", `Bearer ${learnerToken}`);

    expect(learnerCourseDetail.status).toBe(200);
    expect(learnerCourseDetail.body.data.course.modules.length).toBeGreaterThan(0);

    const learnerPreviewLesson = await api
      .get(`/api/learner/lessons/${createdLessonId}`)
      .set("Authorization", `Bearer ${learnerToken}`);

    expect(learnerPreviewLesson.status).toBe(200);
    expect(learnerPreviewLesson.body.data.lesson.accessState).toBe("PREVIEW");

    const learnerPreviewProgressSave = await api
      .post(`/api/learner/lessons/${createdLessonId}/progress`)
      .set("Authorization", `Bearer ${learnerToken}`)
      .send({
        progressPercent: 60,
        watchSeconds: 420,
      });

    expect(learnerPreviewProgressSave.status).toBe(200);
    expect(learnerPreviewProgressSave.body.data.progressPercent).toBe(60);

    const learnerProgressSnapshot = await api
      .get("/api/learner/progress")
      .set("Authorization", `Bearer ${learnerToken}`);

    expect(learnerProgressSnapshot.status).toBe(200);
    expect(learnerProgressSnapshot.body.data.summary.trackedLessons).toBeGreaterThan(0);
    expect(
      (learnerProgressSnapshot.body.data.items as Array<{ lesson: { id: string }; progressPercent: number }>).some(
        (item) => item.lesson.id === createdLessonId && item.progressPercent === 60,
      ),
    ).toBe(true);

    const learnerPreviewAssetOpen = await api
      .get(`/api/learner/assets/${createdAssetId}/open`)
      .set("Authorization", `Bearer ${learnerToken}`);

    expect(learnerPreviewAssetOpen.status).toBe(200);
    expect(learnerPreviewAssetOpen.body.data.delivery.status).toBe("READY");

    const previewAssetInlineUrl = learnerPreviewAssetOpen.body.data.delivery.inlineUrl as string;
    const previewAssetDeliverPath = new URL(previewAssetInlineUrl).pathname + new URL(previewAssetInlineUrl).search;

    const learnerPreviewAssetDeliver = await api.get(previewAssetDeliverPath);

    expect(learnerPreviewAssetDeliver.status).toBe(302);
    expect(learnerPreviewAssetDeliver.headers.location).toBe(
      `https://cdn.example.com/courses/${createdCourseId}/lesson-one.mp4`,
    );

    const adminLockedCourse = await api
      .patch(`/api/courses/${createdCourseId}`)
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ visibility: "LOCKED" });
    expect(adminLockedCourse.status).toBe(200);

    const lockedPreviewLesson = await api
      .get(`/api/learner/lessons/${createdLessonId}`)
      .set("Authorization", `Bearer ${learnerToken}`);
    expect(lockedPreviewLesson.status).toBe(403);

    const lockedPreviewAsset = await api
      .get(`/api/learner/assets/${createdAssetId}/open`)
      .set("Authorization", `Bearer ${learnerToken}`);
    expect(lockedPreviewAsset.status).toBe(403);
    expect((await api.get(previewAssetDeliverPath)).status).toBe(403);

    const adminUnlockedCourse = await api
      .patch(`/api/courses/${createdCourseId}`)
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ visibility: "PAID" });
    expect(adminUnlockedCourse.status).toBe(200);

    const teacherLockedLesson = await api
      .patch(`/api/courses/lessons/${createdLessonId}`)
      .set("Authorization", `Bearer ${teacherToken}`)
      .send({ visibility: "LOCKED" });
    expect(teacherLockedLesson.status).toBe(200);
    const lockedLessonAsset = await api
      .get(`/api/learner/assets/${createdAssetId}/open`)
      .set("Authorization", `Bearer ${learnerToken}`);
    expect(lockedLessonAsset.status).toBe(403);

    const teacherUnlockedLesson = await api
      .patch(`/api/courses/lessons/${createdLessonId}`)
      .set("Authorization", `Bearer ${teacherToken}`)
      .send({ visibility: "PREVIEW" });
    expect(teacherUnlockedLesson.status).toBe(200);

    const learnerBlockedFromPaidLesson = await api
      .get(`/api/learner/lessons/${createdPaidLessonId}`)
      .set("Authorization", `Bearer ${learnerToken}`);

    expect(learnerBlockedFromPaidLesson.status).toBe(403);

    const learnerBlockedFromPaidLessonProgress = await api
      .post(`/api/learner/lessons/${createdPaidLessonId}/progress`)
      .set("Authorization", `Bearer ${learnerToken}`)
      .send({
        progressPercent: 40,
      });

    expect(learnerBlockedFromPaidLessonProgress.status).toBe(403);

    const learnerCourseAccessRequest = await api
      .post(`/api/courses/${createdCourseId}/access-requests`)
      .set("Authorization", `Bearer ${learnerToken}`)
      .send({
        requestMessage: "Please clear full access for this paid course.",
      });

    expect(learnerCourseAccessRequest.status).toBe(201);
    expect(learnerCourseAccessRequest.body.data.status).toBe("NEW");
    expect(learnerCourseAccessRequest.body.data.course.priceAmount).toBe("25000.00");
    expect(learnerCourseAccessRequest.body.data.invoice?.invoiceNo).toBeTruthy();
    expect(learnerCourseAccessRequest.body.data.invoice?.status).toBe("PENDING");

    const adminCourseAccessRequests = await api
      .get("/api/courses/access-requests")
      .set("Authorization", `Bearer ${adminToken}`);

    expect(adminCourseAccessRequests.status).toBe(200);
    expect(
      (adminCourseAccessRequests.body.data as Array<{ courseId: string; status: string }>).some(
        (request) => request.courseId === createdCourseId && request.status === "NEW",
      ),
    ).toBe(true);

    const accountantCourseAccessReview = await api
      .patch(`/api/courses/access-requests/${learnerCourseAccessRequest.body.data.id as string}/status`)
      .set("Authorization", `Bearer ${accountantToken}`)
      .send({
        status: "REVIEWING",
        officeNote: "Finance office is checking payment confirmation before admin grant.",
      });

    expect(accountantCourseAccessReview.status).toBe(200);
    expect(accountantCourseAccessReview.body.data.status).toBe("REVIEWING");
    expect(accountantCourseAccessReview.body.data.officeNote).toContain("payment confirmation");
    expect(accountantCourseAccessReview.body.data.invoice?.invoiceNo).toBeTruthy();

    const teacherBlockedFromCourseAccessRequests = await api
      .get("/api/courses/access-requests")
      .set("Authorization", `Bearer ${teacherToken}`);

    expect(teacherBlockedFromCourseAccessRequests.status).toBe(403);

    const teacherBlockedFromCourseAccessReview = await api
      .patch(`/api/courses/access-requests/${learnerCourseAccessRequest.body.data.id as string}/status`)
      .set("Authorization", `Bearer ${teacherToken}`)
      .send({
        status: "REVIEWING",
      });

    expect(teacherBlockedFromCourseAccessReview.status).toBe(403);

    const teacherBlockedFromGrantCreate = await api
      .post(`/api/courses/${createdCourseId}/grants`)
      .set("Authorization", `Bearer ${teacherToken}`)
      .send({
        learnerUserId: learnerLogin.body.data.user.id as string,
        grantType: "MANUAL",
      });

    expect(teacherBlockedFromGrantCreate.status).toBe(403);

    const adminBlockedFromUnpaidPaymentGrant = await api
      .post(`/api/courses/${createdCourseId}/grants`)
      .set("Authorization", `Bearer ${adminToken}`)
      .send({
        learnerUserId: learnerLogin.body.data.user.id as string,
        grantType: "PAYMENT",
      });
    expect(adminBlockedFromUnpaidPaymentGrant.status).toBe(409);

    const learnerCoursePayment = await api
      .post(`/api/learner/course-invoices/${learnerCourseAccessRequest.body.data.invoice.id as string}/payments`)
      .set("Authorization", `Bearer ${learnerToken}`)
      .send({
        payerPhone: "255744444444",
        channel: "mpesa",
      });

    expect(learnerCoursePayment.status).toBe(201);
    expect(learnerCoursePayment.body.data.invoice.invoiceScope).toBe("COURSE_ACCESS");
    expect(learnerCoursePayment.body.data.invoice.course.id).toBe(createdCourseId);

    const reconciledLearnerCoursePayment = await api
      .post(`/api/payments/${learnerCoursePayment.body.data.id as string}/reconcile`)
      .set("Authorization", `Bearer ${adminToken}`);

    expect(reconciledLearnerCoursePayment.status).toBe(200);
    expect(reconciledLearnerCoursePayment.body.data.status).toBe("COMPLETED");

    const learnerPaidLessonAfterPayment = await api
      .get(`/api/learner/lessons/${createdPaidLessonId}`)
      .set("Authorization", `Bearer ${learnerToken}`);

    expect(learnerPaidLessonAfterPayment.status).toBe(200);
    expect(learnerPaidLessonAfterPayment.body.data.lesson.accessState).toBe("OPEN");

    const adminCourseAccessRequestsAfterPayment = await api
      .get("/api/courses/access-requests")
      .set("Authorization", `Bearer ${adminToken}`);

    expect(adminCourseAccessRequestsAfterPayment.status).toBe(200);
    expect(
      (adminCourseAccessRequestsAfterPayment.body.data as Array<{ courseId: string; status: string }>).some(
        (request) => request.courseId === createdCourseId && request.status === "APPROVED",
      ),
    ).toBe(true);

    const adminCourseGrant = await api
      .post(`/api/courses/${createdCourseId}/grants`)
      .set("Authorization", `Bearer ${adminToken}`)
      .send({
        learnerUserId: learnerLogin.body.data.user.id as string,
        grantType: "PAYMENT",
      });

    expect(adminCourseGrant.status).toBe(201);

    const expiredGrant = await api
      .post(`/api/courses/${createdCourseId}/grants`)
      .set("Authorization", `Bearer ${adminToken}`)
      .send({
        learnerUserId: learnerLogin.body.data.user.id as string,
        grantType: "MANUAL",
        startsAt: new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString(),
        endsAt: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(),
      });
    expect(expiredGrant.status).toBe(201);

    const renewedRequest = await api
      .post(`/api/courses/${createdCourseId}/access-requests`)
      .set("Authorization", `Bearer ${learnerToken}`)
      .send({});
    expect(renewedRequest.status).toBe(201);
    expect(renewedRequest.body.data.invoice.id).not.toBe(learnerCourseAccessRequest.body.data.invoice.id);
    expect(renewedRequest.body.data.invoice.status).toBe("PENDING");

    const adminBlockedFromOldPaymentGrant = await api
      .post(`/api/courses/${createdCourseId}/grants`)
      .set("Authorization", `Bearer ${adminToken}`)
      .send({ learnerUserId: learnerLogin.body.data.user.id as string, grantType: "PAYMENT" });
    expect(adminBlockedFromOldPaymentGrant.status).toBe(409);

    const adminTeacherAnnouncement = await api
      .post("/api/announcements")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({
        title: `Teacher Notice ${publicationStamp}`,
        message: "Teacher audience only",
        audience: "TEACHERS",
        publishAt: new Date().toISOString(),
      });

    expect(adminTeacherAnnouncement.status).toBe(201);

    const adminAccountantAnnouncement = await api
      .post("/api/announcements")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({
        title: `Accountant Notice ${publicationStamp}`,
        message: "Accountant audience only",
        audience: "ACCOUNTANTS",
        publishAt: new Date().toISOString(),
      });

    expect(adminAccountantAnnouncement.status).toBe(201);

    const financeInquiry = await api.post("/api/public/inquiries").send({
      inquiryType: "FINANCE",
      fullName: "Finance Inquiry Contact",
      phone: "255700900001",
      email: "finance.inquiry@example.com",
      subject: `Finance Inquiry ${publicationStamp}`,
      message: "Need support with fee payment follow-up and receipt review.",
      preferredContact: "phone",
      sourcePage: "contact",
      branchId: "1",
    });

    expect(financeInquiry.status).toBe(201);

    const admissionsInquiry = await api.post("/api/public/inquiries").send({
      inquiryType: "ADMISSIONS",
      fullName: "Admissions Inquiry Contact",
      phone: "255700900002",
      email: "admissions.inquiry@example.com",
      subject: `Admissions Inquiry ${publicationStamp}`,
      message: "Need admissions guidance for a new student application.",
      preferredContact: "email",
      sourcePage: "admissions",
      branchId: "1",
    });

    expect(admissionsInquiry.status).toBe(201);

    const accountantInquiryList = await api
      .get("/api/public-inquiries")
      .set("Authorization", `Bearer ${accountantToken}`);

    expect(accountantInquiryList.status).toBe(200);
    expect(
      (accountantInquiryList.body.data as Array<{ inquiryType: string }>).every((record) => record.inquiryType === "FINANCE"),
    ).toBe(true);

    const accountantBlockedFromAdmissionsInquiries = await api
      .get("/api/public-inquiries?inquiryType=ADMISSIONS")
      .set("Authorization", `Bearer ${accountantToken}`);

    expect(accountantBlockedFromAdmissionsInquiries.status).toBe(403);

    const accountantBlockedFromForeignBranchInquiries = await api
      .get("/api/public-inquiries?branchId=999")
      .set("Authorization", `Bearer ${accountantToken}`);

    expect(accountantBlockedFromForeignBranchInquiries.status).toBe(403);

    const accountantBlockedFromAdmissionsInquiryUpdate = await api
      .patch(`/api/public-inquiries/${admissionsInquiry.body.data.id as string}/status`)
      .set("Authorization", `Bearer ${accountantToken}`)
      .send({ status: "CONTACTED" });

    expect(accountantBlockedFromAdmissionsInquiryUpdate.status).toBe(404);

    const adminUnassignedClass = await api
      .post("/api/classes")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({
        branchId: "1",
        name: `RBAC Scope Class ${publicationStamp}`,
        level: "Form 2",
        academicYear: "2026",
        capacity: 20,
      });

    expect(adminUnassignedClass.status).toBe(201);

    const unassignedClassId = adminUnassignedClass.body.data.id as string;

    const teacherBlockedFromForeignAttendanceSummary = await api
      .get(`/api/reports/attendance/summary?classId=${unassignedClassId}`)
      .set("Authorization", `Bearer ${teacherToken}`);

    expect(teacherBlockedFromForeignAttendanceSummary.status).toBe(403);

    const teacherBlockedFromForeignStudentExport = await api
      .get(`/api/reports/students/export?classId=${unassignedClassId}`)
      .set("Authorization", `Bearer ${teacherToken}`);

    expect(teacherBlockedFromForeignStudentExport.status).toBe(403);

    const teacherBlockedFromForeignEnrollments = await api
      .get(`/api/enrollments?classId=${unassignedClassId}`)
      .set("Authorization", `Bearer ${teacherToken}`);

    expect(teacherBlockedFromForeignEnrollments.status).toBe(403);

    const teacherDashboard = await api
      .get("/api/reports/teacher-dashboard")
      .set("Authorization", `Bearer ${teacherToken}`);

    expect(teacherDashboard.status).toBe(200);

    const teacherClassId = ((teacherDashboard.body.data.classes as Array<{ id: string }> | undefined) ?? [])[0]?.id;
    expect(teacherClassId).toBeTruthy();

    const teacherEnrollments = await api
      .get(`/api/enrollments?classId=${teacherClassId}`)
      .set("Authorization", `Bearer ${teacherToken}`);

    expect(teacherEnrollments.status).toBe(200);

    const teacherStudentId = ((teacherEnrollments.body.data as Array<{ studentId: string }> | undefined) ?? [])[0]?.studentId;
    expect(teacherStudentId).toBeTruthy();

    const adminBlockedFromTeacherAttendanceWrite = await api
      .post("/api/attendance/bulk-mark")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({
        classId: teacherClassId,
        date: "2026-05-24",
        records: [
          {
            studentId: teacherStudentId,
            status: "PRESENT",
          },
        ],
      });

    expect(adminBlockedFromTeacherAttendanceWrite.status).toBe(403);

    const adminBlockedFromTeacherHifdhWrite = await api
      .post("/api/hifdh-progress")
      .set("Authorization", `Bearer ${adminToken}`)
      .send({
        studentId: teacherStudentId,
        teacherId: teacherLogin.body.data.user.id as string,
        juzNumber: 1,
        surahName: "Al-Fatiha",
        ayahFrom: 1,
        ayahTo: 7,
        memorizationScore: "92.50",
        revisionScore: "90.00",
        assessedOn: "2026-05-24",
      });

    expect(adminBlockedFromTeacherHifdhWrite.status).toBe(403);

    const parentProfile = await api
      .get("/api/parent-portal/me")
      .set("Authorization", `Bearer ${parentToken}`);

    expect(parentProfile.status).toBe(200);

    const parentUserId = parentLogin.body.data.user.id as string;
    const parentStudentId = ((parentProfile.body.data.students as Array<{ id: string }> | undefined) ?? [])[0]?.id;
    expect(parentStudentId).toBeTruthy();

    const parentFinance = await api
      .get(`/api/parent-portal/students/${parentStudentId}/finance`)
      .set("Authorization", `Bearer ${parentToken}`);

    expect(parentFinance.status).toBe(200);

    const payableInvoiceId = (
      (parentFinance.body.data as Array<{ id: string; status: string }> | undefined) ?? []
    ).find((invoice) => invoice.status !== "PAID" && invoice.status !== "CANCELLED")?.id;
    expect(payableInvoiceId).toBeTruthy();

    const adminBlockedFromParentPaymentWrite = await api
      .post(`/api/parent-portal/students/${parentStudentId}/payments?parentUserId=${parentUserId}`)
      .set("Authorization", `Bearer ${adminToken}`)
      .send({
        invoiceId: payableInvoiceId,
        payerPhone: "255733333333",
        channel: "mpesa",
      });

    expect(adminBlockedFromParentPaymentWrite.status).toBe(403);

    const accountantBlockedFromForeignBranchInvoices = await api
      .get("/api/invoices?branchId=999")
      .set("Authorization", `Bearer ${accountantToken}`);

    expect(accountantBlockedFromForeignBranchInvoices.status).toBe(403);

    const accountantBlockedFromForeignBranchPayments = await api
      .get("/api/payments?branchId=999")
      .set("Authorization", `Bearer ${accountantToken}`);

    expect(accountantBlockedFromForeignBranchPayments.status).toBe(403);

    const accountantStudents = await api
      .get("/api/students?page=1&pageSize=5")
      .set("Authorization", `Bearer ${accountantToken}`);

    expect(accountantStudents.status).toBe(200);

    const accountantStudent = ((accountantStudents.body.data.items as Array<{
      dob: string | null;
      joinedOn: string | null;
      leftOn: string | null;
      notes: string | null;
      guardians: Array<unknown>;
      primaryGuardian: {
        fullName: string;
        phone: string;
        email: string | null;
        relationship: string | null;
        address: string | null;
      };
    }> | undefined) ?? [])[0];

    if (accountantStudent) {
      expect(accountantStudent.dob).toBeNull();
      expect(accountantStudent.joinedOn).toBeNull();
      expect(accountantStudent.leftOn).toBeNull();
      expect(accountantStudent.notes).toBeNull();
      expect(accountantStudent.guardians).toEqual([]);
      expect(accountantStudent.primaryGuardian.relationship).toBeNull();
      expect(accountantStudent.primaryGuardian.address).toBeNull();
      expect(accountantStudent.primaryGuardian.fullName).toBeTruthy();
      expect(accountantStudent.primaryGuardian.phone).toBeTruthy();
    }

    const accountantClasses = await api
      .get("/api/classes")
      .set("Authorization", `Bearer ${accountantToken}`);

    expect(accountantClasses.status).toBe(200);

    const accountantClassWithTeacher = ((accountantClasses.body.data as Array<{
      teacher: { id: string; fullName: string; email: string | null; phone: string | null } | null;
    }> | undefined) ?? []).find((classRecord) => classRecord.teacher);

    if (accountantClassWithTeacher?.teacher) {
      expect(accountantClassWithTeacher.teacher.email).toBeNull();
      expect(accountantClassWithTeacher.teacher.phone).toBeNull();
    }

    const accountantBlockedFromForeignBranchExpenseWrite = await api
      .post("/api/expenses")
      .set("Authorization", `Bearer ${accountantToken}`)
      .send({
        title: `Foreign Branch Expense ${publicationStamp}`,
        amount: "12000",
        expenseDate: new Date().toISOString().slice(0, 10),
        branchId: "999",
      });

    expect(accountantBlockedFromForeignBranchExpenseWrite.status).toBe(403);

    const teacherAnnouncementList = await api
      .get("/api/announcements")
      .set("Authorization", `Bearer ${teacherToken}`);

    expect(teacherAnnouncementList.status).toBe(200);
    expect(
      (teacherAnnouncementList.body.data as Array<{ audience: string }>).every((record) =>
        ["ALL", "TEACHERS"].includes(record.audience),
      ),
    ).toBe(true);

    const accountantAnnouncementList = await api
      .get("/api/announcements")
      .set("Authorization", `Bearer ${accountantToken}`);

    expect(accountantAnnouncementList.status).toBe(200);
    expect(
      (accountantAnnouncementList.body.data as Array<{ audience: string }>).every((record) =>
        ["ALL", "ACCOUNTANTS"].includes(record.audience),
      ),
    ).toBe(true);

    const teacherAllowedTeacherDashboard = await api
      .get("/api/reports/teacher-dashboard")
      .set("Authorization", `Bearer ${teacherToken}`);

    expect(teacherAllowedTeacherDashboard.status).toBe(200);

    const accountantAllowedFinanceHome = await api
      .get("/api/reports/finance/home")
      .set("Authorization", `Bearer ${accountantToken}`);

    expect(accountantAllowedFinanceHome.status).toBe(200);
    expect(accountantAllowedFinanceHome.body.data.finance).toBeTruthy();

    const adminAllowedOperationsDashboard = await api
      .get("/api/reports/dashboard")
      .set("Authorization", `Bearer ${adminToken}`);

    expect(adminAllowedOperationsDashboard.status).toBe(200);

    const parentAllowedParentProfile = await api
      .get("/api/parent-portal/me")
      .set("Authorization", `Bearer ${parentToken}`);

    expect(parentAllowedParentProfile.status).toBe(200);
  }, 20000);
});
