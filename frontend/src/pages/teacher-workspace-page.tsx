import { useEffect, useMemo, useState } from "react";
import { Link, Navigate } from "react-router-dom";

import {
  bulkMarkAttendance,
  createHifdhProgress,
  exportAttendanceReport,
  exportStudentsReport,
  getClassAttendance,
  getAttendanceSummaryReport,
  getTeacherDashboardReport,
  listHifdhProgress,
  listEnrollments,
  listUsers,
  type AttendanceRecord,
  type AttendanceSummaryReport,
  type EnrollmentRecord,
  type HifdhRecord,
  type TeacherDashboardReport,
  type UserRecord,
} from "../lib/api";
import { InlineEmptyState, LoadingRowList, LoadingStatsGrid, LoadingTable } from "../components/ui-states";
import { useAuth } from "../lib/auth";
import { formatDate } from "../lib/format";
import { useNotifyOnMessage } from "../lib/notifications";
import { usePwa } from "../lib/pwa";

type TeacherState = {
  teachers: UserRecord[];
  dashboard: TeacherDashboardReport | null;
  attendance: AttendanceSummaryReport | null;
  enrollments: EnrollmentRecord[];
  classAttendance: AttendanceRecord[];
  hifdhRecords: HifdhRecord[];
  selectedTeacherId: string;
  selectedClassId: string;
  attendanceDate: string;
  selectedHifdhStudentId: string;
  loading: boolean;
  detailLoading: boolean;
  saving: boolean;
  exporting: null | "attendance" | "roster";
  error: string | null;
  success: string | null;
};

export const TeacherWorkspacePage = () => {
  const { session } = useAuth();
  const { isOnline } = usePwa();
  const [state, setState] = useState<TeacherState>({
    teachers: [],
    dashboard: null,
    attendance: null,
    enrollments: [],
    classAttendance: [],
    hifdhRecords: [],
    selectedTeacherId: "",
    selectedClassId: "",
    attendanceDate: new Date().toISOString().slice(0, 10),
    selectedHifdhStudentId: "",
    loading: true,
    detailLoading: true,
    saving: false,
    exporting: null,
    error: null,
    success: null,
  });
  const [draftStatuses, setDraftStatuses] = useState<
    Record<string, { status: "PRESENT" | "ABSENT" | "LATE" | "EXCUSED"; reason: string }>
  >({});
  const [hifdhForm, setHifdhForm] = useState({
    studentId: "",
    juzNumber: 1,
    surahName: "",
    ayahFrom: "",
    ayahTo: "",
    memorizationScore: "",
    revisionScore: "",
    remarks: "",
    assessedOn: new Date().toISOString().slice(0, 10),
  });

  useNotifyOnMessage(state.error, state.success);

  useEffect(() => {
    if (!session || (session.user.role !== "TEACHER" && session.user.role !== "ADMIN")) {
      return;
    }

    let cancelled = false;

    const bootstrap = async () => {
      setState((previous) => ({ ...previous, loading: true, error: null }));

      try {
        const [attendance, teachers] = await Promise.all([
          getAttendanceSummaryReport(session.accessToken),
          session.user.role === "ADMIN"
            ? listUsers(session.accessToken, { role: "TEACHER", status: "ACTIVE" })
            : Promise.resolve([] as UserRecord[]),
        ]);

        if (cancelled) {
          return;
        }

        setState({
          teachers,
          dashboard: null,
          attendance,
          enrollments: [],
          classAttendance: [],
          hifdhRecords: [],
          selectedTeacherId: session.user.role === "ADMIN" ? (teachers[0]?.id ?? "") : session.user.id,
          selectedClassId: "",
          attendanceDate: new Date().toISOString().slice(0, 10),
          selectedHifdhStudentId: "",
          loading: session.user.role === "ADMIN" ? Boolean(teachers[0]?.id) : true,
          detailLoading: false,
          saving: false,
          exporting: null,
          error: null,
          success: null,
        });
      } catch (error) {
        if (cancelled) {
          return;
        }

        setState((previous) => ({
          ...previous,
          loading: false,
          detailLoading: false,
          error: error instanceof Error ? error.message : "Failed to load teacher workspace.",
        }));
      }
    };

    void bootstrap();

    return () => {
      cancelled = true;
    };
  }, [session]);

  useEffect(() => {
    if (!session || (session.user.role !== "TEACHER" && session.user.role !== "ADMIN")) {
      return;
    }

    if (!state.selectedTeacherId) {
      setState((previous) => ({
        ...previous,
        dashboard: null,
        enrollments: [],
        classAttendance: [],
        hifdhRecords: [],
        selectedClassId: "",
        selectedHifdhStudentId: "",
        loading: false,
        detailLoading: false,
      }));
      return;
    }

    let cancelled = false;

    const loadTeacherDashboard = async () => {
      setState((previous) => ({
        ...previous,
        loading: true,
        detailLoading: false,
        error: null,
        success: null,
      }));

      try {
        const dashboard = await getTeacherDashboardReport(
          session.accessToken,
          session.user.role === "ADMIN" ? state.selectedTeacherId : undefined,
        );

        if (cancelled) {
          return;
        }

        const selectedClassId = dashboard.classes[0]?.id ?? "";
        setState((previous) => ({
          ...previous,
          dashboard,
          enrollments: [],
          classAttendance: [],
          hifdhRecords: [],
          selectedClassId,
          selectedHifdhStudentId: "",
          loading: false,
          detailLoading: Boolean(selectedClassId),
          error: null,
        }));
      } catch (error) {
        if (cancelled) {
          return;
        }

        setState((previous) => ({
          ...previous,
          loading: false,
          detailLoading: false,
          error: error instanceof Error ? error.message : "Failed to load teacher dashboard.",
        }));
      }
    };

    void loadTeacherDashboard();

    return () => {
      cancelled = true;
    };
  }, [session, state.selectedTeacherId]);

  useEffect(() => {
    if (!session || (session.user.role !== "TEACHER" && session.user.role !== "ADMIN") || !state.selectedClassId) {
      return;
    }

    let cancelled = false;

    const loadClassData = async () => {
      setState((previous) => ({
        ...previous,
        detailLoading: true,
        error: null,
        success: null,
      }));

      try {
        const [enrollments, classAttendance] = await Promise.all([
          listEnrollments(session.accessToken, {
            classId: state.selectedClassId,
            status: "ACTIVE",
          }),
          getClassAttendance(session.accessToken, state.selectedClassId, state.attendanceDate),
        ]);

        if (cancelled) {
          return;
        }

        setState((previous) => ({
          ...previous,
          enrollments,
          classAttendance,
          selectedHifdhStudentId: enrollments[0]?.studentId ?? "",
          detailLoading: false,
        }));
        setHifdhForm((previous) => ({
          ...previous,
          studentId: enrollments[0]?.studentId ?? "",
        }));

        setDraftStatuses(
          Object.fromEntries(
            enrollments.map((enrollment) => {
              const existingRecord = classAttendance.find(
                (attendanceRecord) => attendanceRecord.studentId === enrollment.studentId,
              );

              return [
                enrollment.studentId,
                {
                  status: existingRecord?.status ?? "PRESENT",
                  reason: existingRecord?.reason ?? "",
                },
              ];
            }),
          ),
        );
      } catch (error) {
        if (cancelled) {
          return;
        }

        setState((previous) => ({
          ...previous,
          detailLoading: false,
          error: error instanceof Error ? error.message : "Failed to load class attendance.",
        }));
      }
    };

    void loadClassData();

    return () => {
      cancelled = true;
    };
  }, [session, state.selectedClassId, state.attendanceDate]);

  useEffect(() => {
    if (!session || (session.user.role !== "TEACHER" && session.user.role !== "ADMIN") || !state.selectedHifdhStudentId) {
      return;
    }

    let cancelled = false;

    const loadHifdhHistory = async () => {
      try {
        const records = await listHifdhProgress(session.accessToken, {
          studentId: state.selectedHifdhStudentId,
          teacherId: session.user.role === "ADMIN" ? state.selectedTeacherId : undefined,
        });

        if (cancelled) {
          return;
        }

        setState((previous) => ({
          ...previous,
          hifdhRecords: records,
        }));
      } catch (error) {
        if (cancelled) {
          return;
        }

        setState((previous) => ({
          ...previous,
          error: error instanceof Error ? error.message : "Failed to load hifdh history.",
        }));
      }
    };

    void loadHifdhHistory();

    return () => {
      cancelled = true;
    };
  }, [session, state.selectedTeacherId, state.selectedHifdhStudentId]);

  if (!session) {
    return null;
  }

  if (session.user.role === "ACCOUNTANT") {
    return <Navigate to="/dashboard" replace />;
  }

  if (session.user.role === "PARENT") {
    return <Navigate to="/parent" replace />;
  }

  const {
    dashboard,
    attendance,
    teachers,
    enrollments,
    classAttendance,
    hifdhRecords,
    error,
    success,
    selectedTeacherId,
    selectedClassId,
    attendanceDate,
    selectedHifdhStudentId,
  } =
    state;

  const selectedClass = dashboard?.classes.find((classRecord) => classRecord.id === selectedClassId) ?? null;
  const selectedTeacher = teachers.find((teacher) => teacher.id === selectedTeacherId) ?? null;
  const markedCount = classAttendance.length;
  const presentCount = classAttendance.filter((record) => record.status === "PRESENT").length;
  const absentCount = classAttendance.filter((record) => record.status === "ABSENT").length;
  const lateCount = classAttendance.filter((record) => record.status === "LATE").length;
  const excusedCount = classAttendance.filter((record) => record.status === "EXCUSED").length;
  const pendingAttendanceCount = Math.max(enrollments.length - markedCount, 0);
  const rosterRows = useMemo(
    () =>
      enrollments.filter((enrollment) => enrollment.student).map((enrollment) => ({
        enrollmentId: enrollment.id,
        studentId: enrollment.studentId,
        fullName: enrollment.student!.fullName,
        admissionNo: enrollment.student!.admissionNo,
        draft: draftStatuses[enrollment.studentId] ?? {
          status: "PRESENT",
          reason: "",
        },
      })),
    [draftStatuses, enrollments],
  );
  const hifdhStudents = useMemo(
    () =>
      enrollments
        .filter((enrollment) => enrollment.student)
        .map((enrollment) => ({
          id: enrollment.studentId,
          fullName: enrollment.student!.fullName,
          admissionNo: enrollment.student!.admissionNo,
        })),
    [enrollments],
  );

  const handleStatusChange = (
    studentId: string,
    field: "status" | "reason",
    value: "PRESENT" | "ABSENT" | "LATE" | "EXCUSED" | string,
  ) => {
    setDraftStatuses((previous) => ({
      ...previous,
      [studentId]: {
        status:
          field === "status"
            ? (value as "PRESENT" | "ABSENT" | "LATE" | "EXCUSED")
            : (previous[studentId]?.status ?? "PRESENT"),
        reason: field === "reason" ? value : (previous[studentId]?.reason ?? ""),
      },
    }));
  };

  const handleSubmitAttendance = async () => {
    if (!session || !selectedClassId || rosterRows.length === 0) {
      return;
    }

    setState((previous) => ({
      ...previous,
      saving: true,
      error: null,
      success: null,
    }));

    try {
      const saved = await bulkMarkAttendance(session.accessToken, {
        classId: selectedClassId,
        date: attendanceDate,
        records: rosterRows.map((row) => ({
          studentId: row.studentId,
          status: row.draft.status,
          reason: row.draft.reason.trim() || undefined,
        })),
      });

      setState((previous) => ({
        ...previous,
        classAttendance: saved,
        saving: false,
        success: "Attendance saved successfully.",
      }));
    } catch (submitError) {
      setState((previous) => ({
        ...previous,
        saving: false,
        error: submitError instanceof Error ? submitError.message : "Failed to save attendance.",
      }));
    }
  };

  const handleSubmitHifdh = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (!session || !hifdhForm.studentId) {
      return;
    }

    setState((previous) => ({
      ...previous,
      saving: true,
      error: null,
      success: null,
    }));

    try {
      const created = await createHifdhProgress(session.accessToken, {
        studentId: hifdhForm.studentId,
        juzNumber: hifdhForm.juzNumber,
        surahName: hifdhForm.surahName.trim(),
        ayahFrom: hifdhForm.ayahFrom ? Number(hifdhForm.ayahFrom) : undefined,
        ayahTo: hifdhForm.ayahTo ? Number(hifdhForm.ayahTo) : undefined,
        memorizationScore: hifdhForm.memorizationScore.trim(),
        revisionScore: hifdhForm.revisionScore.trim() || undefined,
        remarks: hifdhForm.remarks.trim() || undefined,
        assessedOn: hifdhForm.assessedOn,
        teacherId: session.user.role === "ADMIN" ? selectedTeacherId : undefined,
      });
      const createdSummaryRecord = {
        id: created.id,
        assessedOn: created.assessedOn,
        juzNumber: created.juzNumber,
        surahName: created.surahName,
        memorizationScore: created.memorizationScore,
        revisionScore: created.revisionScore ?? "--",
        student: created.student ?? {
          id: created.studentId,
          fullName: "Student",
          admissionNo: "",
        },
      };

      setState((previous) => ({
        ...previous,
        hifdhRecords: [created, ...previous.hifdhRecords],
        dashboard: previous.dashboard
          ? {
              ...previous.dashboard,
              summary: {
                ...previous.dashboard.summary,
                hifdhAssessmentsThisWeek: previous.dashboard.summary.hifdhAssessmentsThisWeek + 1,
              },
              recentHifdh: [createdSummaryRecord, ...previous.dashboard.recentHifdh].slice(0, 5),
            }
          : previous.dashboard,
        saving: false,
        success: "Hifdh progress recorded successfully.",
      }));
      setHifdhForm((previous) => ({
        ...previous,
        surahName: "",
        ayahFrom: "",
        ayahTo: "",
        memorizationScore: "",
        revisionScore: "",
        remarks: "",
      }));
    } catch (submitError) {
      setState((previous) => ({
        ...previous,
        saving: false,
        error: submitError instanceof Error ? submitError.message : "Failed to record hifdh progress.",
      }));
    }
  };

  const handleExport = async (kind: "attendance" | "roster") => {
    if (!session || !selectedClassId) {
      return;
    }

    setState((previous) => ({
      ...previous,
      exporting: kind,
      error: null,
      success: null,
    }));

    try {
      if (kind === "attendance") {
        await exportAttendanceReport(session.accessToken, {
          classId: selectedClassId,
          dateFrom: attendanceDate,
          dateTo: attendanceDate,
        });
      } else {
        await exportStudentsReport(session.accessToken, {
          classId: selectedClassId,
          status: "ACTIVE",
        });
      }

      setState((previous) => ({
        ...previous,
        exporting: null,
        success: "Export download started successfully.",
      }));
    } catch (downloadError) {
      setState((previous) => ({
        ...previous,
        exporting: null,
        error: downloadError instanceof Error ? downloadError.message : "Failed to export report.",
      }));
    }
  };

  return (
    <section className="page-card">
      <div className="workspace-header">
        <div className="page-heading">
          <p className="eyebrow">Daily Operations</p>
          <h3>Class attendance and hifdh</h3>
          <p>Record class attendance, review teaching scope, and capture memorization progress.</p>
        </div>

        {session.user.role === "ADMIN" ? (
          <div className="page-actions filters-grid">
            <label className="inline-field">
              <span>Teacher</span>
              <select
                value={selectedTeacherId}
                onChange={(event) =>
                  setState((previous) => ({
                    ...previous,
                    selectedTeacherId: event.target.value,
                  }))
                }
              >
                {!teachers.length ? <option value="">No teachers available</option> : null}
                {teachers.map((teacher) => (
                  <option key={teacher.id} value={teacher.id}>
                    {teacher.fullName}
                  </option>
                ))}
              </select>
            </label>
          </div>
        ) : null}

        {session.user.role === "ADMIN" && selectedTeacher ? (
          <div className="workspace-context-strip">
            <span className="context-chip">Preview Mode</span>
            <div className="context-summary">
              <strong>{selectedTeacher.fullName}</strong>
              <span>{selectedTeacher.email || selectedTeacher.phone || "Active teacher account"}</span>
            </div>
          </div>
        ) : null}
      </div>

      {error ? <div className="banner error-banner">{error}</div> : null}
      {success ? <div className="banner success-banner">{success}</div> : null}

      {session.user.role === "ADMIN" && !teachers.length && !state.loading ? (
        <InlineEmptyState message="No active teacher accounts are available for this workspace." />
      ) : null}

      {session.user.role === "ADMIN" && teachers.length > 0 && !selectedTeacherId ? (
        <InlineEmptyState message="Choose a teacher account to load this workspace." />
      ) : null}

      {state.loading ? (
        <LoadingStatsGrid />
      ) : !dashboard ? null : (
        <div className="stats-grid">
          <article className="stat-card">
            <span className="feature-label">Assigned Classes</span>
            <strong className="stat-value">{dashboard?.summary.assignedClasses ?? "--"}</strong>
          </article>
          <article className="stat-card">
            <span className="feature-label">Assigned Students</span>
            <strong className="stat-value">{dashboard?.summary.assignedStudents ?? "--"}</strong>
          </article>
          <article className="stat-card">
            <span className="feature-label">Attendance Today</span>
            <strong className="stat-value">{dashboard?.summary.attendanceMarkedToday ?? "--"}</strong>
          </article>
          <article className="stat-card">
            <span className="feature-label">Hifdh This Week</span>
            <strong className="stat-value">{dashboard?.summary.hifdhAssessmentsThisWeek ?? "--"}</strong>
          </article>
        </div>
      )}

      <div className="data-grid">
        <article className="data-panel">
          <div className="panel-header">
            <div className="panel-copy">
              <span className="feature-label">Attendance Entry</span>
              <h4>Mark class attendance</h4>
              <p className="panel-note">Choose a class, review the day sheet, then save attendance in bulk.</p>
            </div>
            {selectedClass ? <span className="panel-meta">{selectedClass.stats.currentStudents} students</span> : null}
          </div>

          <div className="page-actions filters-grid">
            <label className="inline-field">
              <span>Class</span>
              <select
                value={selectedClassId}
                onChange={(event) =>
                  setState((previous) => ({
                    ...previous,
                    selectedClassId: event.target.value,
                  }))
                }
              >
                {(dashboard?.classes ?? []).map((classRecord) => (
                  <option key={classRecord.id} value={classRecord.id}>
                    {classRecord.name} ({classRecord.academicYear})
                  </option>
                ))}
              </select>
            </label>

            <label className="inline-field">
              <span>Date</span>
              <input
                type="date"
                value={attendanceDate}
                onChange={(event) =>
                  setState((previous) => ({
                    ...previous,
                    attendanceDate: event.target.value,
                  }))
                }
              />
            </label>

            <div className="action-row inline-actions">
              <button
                type="button"
                className="secondary-button"
                onClick={() => void handleExport("roster")}
                disabled={!selectedClassId || state.exporting !== null || !isOnline}
              >
                {!isOnline ? "Offline" : state.exporting === "roster" ? "Preparing Roster..." : "Export Class Roster"}
              </button>
              <button
                type="button"
                className="secondary-button"
                onClick={() => void handleExport("attendance")}
                disabled={!selectedClassId || state.exporting !== null || !isOnline}
              >
                {!isOnline ? "Offline" : state.exporting === "attendance" ? "Preparing Attendance..." : "Export Daily Attendance"}
              </button>
            </div>
          </div>

          {selectedClass ? (
            <div className="detail-card">
              <span className="feature-label">Selected Class</span>
              <h5>{selectedClass.name}</h5>
              <p className="muted">
                {selectedClass.level} • {selectedClass.branch.name} • {selectedClass.stats.currentStudents} students
              </p>
              <p className="muted">
                {markedCount} records already saved for {formatDate(attendanceDate)}
              </p>
              <div className="action-row top-spacing-small">
                <span className="panel-meta">{presentCount} present</span>
                <span className="panel-meta">{absentCount} absent</span>
                <span className="panel-meta">{lateCount} late</span>
                <span className="panel-meta">{excusedCount} excused</span>
                <span className="panel-meta">{pendingAttendanceCount} pending</span>
              </div>
              <div className="action-row top-spacing">
                <Link className="secondary-button button-link" to={`/classes/${selectedClass.id}`}>
                  Open Class Detail
                </Link>
              </div>
            </div>
          ) : null}
        </article>

        <article className="data-panel">
          <div className="panel-header">
            <div className="panel-copy">
              <span className="feature-label">Hifdh Entry</span>
              <h4>Record memorization progress</h4>
              <p className="panel-note">Capture assessment results for the selected student and teaching scope.</p>
            </div>
            <span className="panel-meta">{hifdhStudents.length} students</span>
          </div>

          <form className="form-card compact-form" onSubmit={handleSubmitHifdh}>
            <label className="full-span">
              <span>Student</span>
              <select
                value={selectedHifdhStudentId}
                onChange={(event) => {
                  const nextStudentId = event.target.value;
                  setState((previous) => ({
                    ...previous,
                    selectedHifdhStudentId: nextStudentId,
                  }));
                  setHifdhForm((previous) => ({
                    ...previous,
                    studentId: nextStudentId,
                  }));
                }}
              >
                <option value="">Choose student</option>
                {hifdhStudents.map((student) => (
                  <option key={student.id} value={student.id}>
                    {student.fullName} ({student.admissionNo})
                  </option>
                ))}
              </select>
            </label>
            <label>
              <span>Juz</span>
              <input
                type="number"
                min="1"
                max="30"
                value={hifdhForm.juzNumber}
                onChange={(event) =>
                  setHifdhForm((previous) => ({
                    ...previous,
                    juzNumber: Number(event.target.value),
                  }))
                }
              />
            </label>
            <label>
              <span>Assessed On</span>
              <input
                type="date"
                value={hifdhForm.assessedOn}
                onChange={(event) =>
                  setHifdhForm((previous) => ({
                    ...previous,
                    assessedOn: event.target.value,
                  }))
                }
              />
            </label>
            <label className="full-span">
              <span>Surah Name</span>
              <input
                value={hifdhForm.surahName}
                onChange={(event) =>
                  setHifdhForm((previous) => ({
                    ...previous,
                    surahName: event.target.value,
                  }))
                }
                required
              />
            </label>
            <label>
              <span>Ayah From</span>
              <input
                type="number"
                min="1"
                value={hifdhForm.ayahFrom}
                onChange={(event) =>
                  setHifdhForm((previous) => ({
                    ...previous,
                    ayahFrom: event.target.value,
                  }))
                }
              />
            </label>
            <label>
              <span>Ayah To</span>
              <input
                type="number"
                min="1"
                value={hifdhForm.ayahTo}
                onChange={(event) =>
                  setHifdhForm((previous) => ({
                    ...previous,
                    ayahTo: event.target.value,
                  }))
                }
              />
            </label>
            <label>
              <span>Memorization Score</span>
              <input
                value={hifdhForm.memorizationScore}
                onChange={(event) =>
                  setHifdhForm((previous) => ({
                    ...previous,
                    memorizationScore: event.target.value,
                  }))
                }
                placeholder="92.50"
                required
              />
            </label>
            <label>
              <span>Revision Score</span>
              <input
                value={hifdhForm.revisionScore}
                onChange={(event) =>
                  setHifdhForm((previous) => ({
                    ...previous,
                    revisionScore: event.target.value,
                  }))
                }
                placeholder="88.00"
              />
            </label>
            <label className="full-span">
              <span>Remarks</span>
              <textarea
                rows={3}
                value={hifdhForm.remarks}
                onChange={(event) =>
                  setHifdhForm((previous) => ({
                    ...previous,
                    remarks: event.target.value,
                  }))
                }
              />
            </label>
            <button
              className="primary-button full-span"
              type="submit"
              disabled={state.saving || !selectedHifdhStudentId || !isOnline}
            >
              {!isOnline ? "Offline" : state.saving ? "Saving..." : "Record Hifdh"}
            </button>
          </form>
        </article>

        <article className="data-panel data-panel-wide">
          <div className="panel-header">
            <div className="panel-copy">
              <span className="feature-label">Roster</span>
              <h4>Daily attendance sheet</h4>
              <p className="panel-note">Update status and notes for each student before saving the daily register.</p>
            </div>
            <span className="panel-meta">
              {rosterRows.length} rows • {pendingAttendanceCount} pending
            </span>
          </div>

          {state.detailLoading ? (
            <LoadingTable columns={4} rows={5} />
          ) : (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Student</th>
                    <th>Admission No</th>
                    <th>Status</th>
                    <th>Reason</th>
                  </tr>
                </thead>
                <tbody>
                  {rosterRows.map((row) => (
                    <tr key={row.studentId}>
                      <td>{row.fullName}</td>
                      <td>{row.admissionNo}</td>
                      <td>
                        <select
                          value={row.draft.status}
                          onChange={(event) =>
                            handleStatusChange(
                              row.studentId,
                              "status",
                              event.target.value as "PRESENT" | "ABSENT" | "LATE" | "EXCUSED",
                            )
                          }
                        >
                          <option value="PRESENT">PRESENT</option>
                          <option value="ABSENT">ABSENT</option>
                          <option value="LATE">LATE</option>
                          <option value="EXCUSED">EXCUSED</option>
                        </select>
                      </td>
                      <td>
                        <input
                          value={row.draft.reason}
                          onChange={(event) =>
                            handleStatusChange(row.studentId, "reason", event.target.value)
                          }
                          placeholder="Optional reason"
                        />
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          <div className="action-row top-spacing">
            <button
              type="button"
              className="primary-button"
              onClick={() => void handleSubmitAttendance()}
              disabled={state.saving || state.detailLoading || rosterRows.length === 0 || !isOnline}
            >
              {!isOnline ? "Offline" : state.saving ? "Saving..." : "Save Attendance"}
            </button>
          </div>

          {!state.detailLoading && !rosterRows.length ? (
            <InlineEmptyState message="No active enrollments found for this class." />
          ) : null}
        </article>

        <article className="data-panel data-panel-wide">
          <div className="panel-header">
            <div className="panel-copy">
              <span className="feature-label">Attendance Trend</span>
              <h4>Recent daily totals</h4>
              <p className="panel-note">Short recent window to spot consistency and missed attendance activity.</p>
            </div>
            <span className="panel-meta">{attendance?.timeline.length ?? 0} days</span>
          </div>

          {state.loading ? (
            <LoadingRowList rows={4} />
          ) : (
            <div className="row-list">
              {(attendance?.timeline ?? []).slice(-7).reverse().map((entry) => (
                <div key={entry.date} className="row-item">
                  <span>{formatDate(entry.date)}</span>
                  <strong>
                    {entry.present}/{entry.totalRecords} present
                  </strong>
                </div>
              ))}
              {!attendance?.timeline.length ? <InlineEmptyState message="No attendance trend data yet." /> : null}
            </div>
          )}
        </article>

        <article className="data-panel data-panel-wide">
          <div className="panel-header">
            <div className="panel-copy">
              <span className="feature-label">Student Hifdh History</span>
              <h4>Recent records for selected student</h4>
              <p className="panel-note">Detailed memorization history for the current student selection.</p>
            </div>
            <span className="panel-meta">{hifdhRecords.length} records</span>
          </div>

          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Juz</th>
                  <th>Surah</th>
                  <th>Ayah Range</th>
                  <th>Memorization</th>
                  <th>Revision</th>
                </tr>
              </thead>
              <tbody>
                {hifdhRecords.map((record) => (
                  <tr key={record.id}>
                    <td>{formatDate(record.assessedOn)}</td>
                    <td>{record.juzNumber}</td>
                    <td>{record.surahName}</td>
                    <td>
                      {record.ayahFrom && record.ayahTo
                        ? `${record.ayahFrom} - ${record.ayahTo}`
                        : "--"}
                    </td>
                    <td>{record.memorizationScore}</td>
                    <td>{record.revisionScore ?? "--"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {!hifdhRecords.length ? (
            <InlineEmptyState message="No hifdh records exist yet for the selected student." />
          ) : null}
        </article>

        <article className="data-panel data-panel-wide">
          <div className="panel-header">
            <div className="panel-copy">
              <span className="feature-label">Recent Hifdh</span>
              <h4>Latest assessments</h4>
              <p className="panel-note">Most recent hifdh entries recorded across this teacher workspace.</p>
            </div>
            <span className="panel-meta">{dashboard?.recentHifdh.length ?? 0} records</span>
          </div>

          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Student</th>
                  <th>Juz</th>
                  <th>Surah</th>
                  <th>Memorization</th>
                  <th>Revision</th>
                </tr>
              </thead>
              <tbody>
                {(dashboard?.recentHifdh ?? []).map((record) => (
                  <tr key={record.id}>
                    <td>{formatDate(record.assessedOn)}</td>
                    <td>{record.student.fullName}</td>
                    <td>{record.juzNumber}</td>
                    <td>{record.surahName}</td>
                    <td>{record.memorizationScore}</td>
                    <td>{record.revisionScore}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {!dashboard?.recentHifdh.length ? (
            <InlineEmptyState message="No hifdh assessments have been recorded in this workspace yet." />
          ) : null}
        </article>
      </div>
    </section>
  );
};
