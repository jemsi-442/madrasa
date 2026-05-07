import { useEffect, useMemo, useState } from "react";
import { Link, Navigate, useParams } from "react-router-dom";

import {
  getClassAttendance,
  getClassById,
  listEnrollments,
  type AttendanceRecord,
  type ClassRecord,
  type EnrollmentRecord,
} from "../lib/api";
import { useAuth } from "../lib/auth";
import { formatDate } from "../lib/format";

type ClassDetailState = {
  classRecord: ClassRecord | null;
  enrollments: EnrollmentRecord[];
  attendance: AttendanceRecord[];
  attendanceDate: string;
  loading: boolean;
  detailLoading: boolean;
  error: string | null;
};

const attendanceStatusClassName = (status: AttendanceRecord["status"]) => {
  switch (status) {
    case "PRESENT":
      return "status-chip status-present";
    case "ABSENT":
      return "status-chip status-absent";
    case "LATE":
      return "status-chip status-late";
    case "EXCUSED":
      return "status-chip status-excused";
    default:
      return "status-chip";
  }
};

export const ClassDetailPage = () => {
  const { session } = useAuth();
  const { classId = "" } = useParams();
  const [state, setState] = useState<ClassDetailState>({
    classRecord: null,
    enrollments: [],
    attendance: [],
    attendanceDate: new Date().toISOString().slice(0, 10),
    loading: true,
    detailLoading: true,
    error: null,
  });

  useEffect(() => {
    if (!session || !classId) {
      return;
    }

    if (session.user.role === "PARENT") {
      return;
    }

    let cancelled = false;

    const load = async () => {
      setState((previous) => ({
        ...previous,
        loading: true,
        error: null,
      }));

      try {
        const [classRecord, enrollments, attendance] = await Promise.all([
          getClassById(session.accessToken, classId),
          listEnrollments(session.accessToken, {
            classId,
            status: "ACTIVE",
          }),
          getClassAttendance(session.accessToken, classId, state.attendanceDate),
        ]);

        if (cancelled) {
          return;
        }

        setState((previous) => ({
          ...previous,
          classRecord,
          enrollments,
          attendance,
          loading: false,
          detailLoading: false,
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
          error: error instanceof Error ? error.message : "Failed to load class detail.",
        }));
      }
    };

    void load();

    return () => {
      cancelled = true;
    };
  }, [classId, session, state.attendanceDate]);

  if (!session) {
    return null;
  }

  if (session.user.role === "PARENT") {
    return <Navigate to="/parent" replace />;
  }

  const rosterRows = useMemo(
    () =>
      state.enrollments
        .filter((enrollment) => enrollment.student)
        .map((enrollment) => {
          const attendance = state.attendance.find((record) => record.studentId === enrollment.studentId) ?? null;

          return {
            enrollmentId: enrollment.id,
            studentId: enrollment.studentId,
            fullName: enrollment.student!.fullName,
            admissionNo: enrollment.student!.admissionNo,
            attendance,
          };
        }),
    [state.attendance, state.enrollments],
  );

  const markedCount = state.attendance.length;
  const pendingCount = Math.max(rosterRows.length - markedCount, 0);

  return (
    <section className="page-card">
      <div className="page-heading">
        <p className="eyebrow">Class Detail</p>
        <h3>{state.classRecord ? `${state.classRecord.name} (${state.classRecord.academicYear})` : "Class overview"}</h3>
        <p>
          Single-class operational view for roster, attendance snapshot, and teaching ownership context.
        </p>
      </div>

      <div className="page-actions">
        <Link
          className="secondary-button button-link"
          to={session.user.role === "TEACHER" ? "/teacher" : "/students"}
        >
          Back to workspace
        </Link>

        <label className="inline-field">
          <span>Attendance Date</span>
          <input
            type="date"
            value={state.attendanceDate}
            onChange={(event) =>
              setState((previous) => ({
                ...previous,
                attendanceDate: event.target.value,
                detailLoading: true,
              }))
            }
          />
        </label>
      </div>

      {state.error ? <div className="banner error-banner">{state.error}</div> : null}

      <div className="stats-grid">
        <article className="stat-card">
          <span className="feature-label">Roster</span>
          <strong className="stat-value">{state.classRecord?.stats?.currentStudents ?? rosterRows.length}</strong>
          <p className="muted">Active students in this class</p>
        </article>
        <article className="stat-card">
          <span className="feature-label">Capacity</span>
          <strong className="stat-value">{state.classRecord?.capacity ?? "--"}</strong>
          <p className="muted">Configured class capacity</p>
        </article>
        <article className="stat-card">
          <span className="feature-label">Marked Today</span>
          <strong className="stat-value">{markedCount}</strong>
          <p className="muted">Attendance records for {formatDate(state.attendanceDate)}</p>
        </article>
        <article className="stat-card">
          <span className="feature-label">Pending Today</span>
          <strong className="stat-value">{pendingCount}</strong>
          <p className="muted">Students without saved attendance yet</p>
        </article>
      </div>

      <div className="data-grid">
        <article className="data-panel">
          <div className="panel-header">
            <div>
              <span className="feature-label">Class Profile</span>
              <h4>Teaching and branch context</h4>
            </div>
          </div>

          <div className="row-list">
            <div className="row-item">
              <span>Teacher</span>
              <strong>{state.classRecord?.teacher?.fullName ?? "Unassigned"}</strong>
            </div>
            <div className="row-item">
              <span>Branch</span>
              <strong>{state.classRecord?.branch?.name ?? "--"}</strong>
            </div>
            <div className="row-item">
              <span>Level</span>
              <strong>{state.classRecord?.level ?? "--"}</strong>
            </div>
            <div className="row-item">
              <span>Academic Year</span>
              <strong>{state.classRecord?.academicYear ?? "--"}</strong>
            </div>
          </div>
        </article>

        <article className="data-panel">
          <div className="panel-header">
            <div>
              <span className="feature-label">Attendance Snapshot</span>
              <h4>{formatDate(state.attendanceDate)}</h4>
            </div>
          </div>

          <div className="row-list">
            <div className="row-item">
              <span>Saved Records</span>
              <strong>{markedCount}</strong>
            </div>
            <div className="row-item">
              <span>Pending Students</span>
              <strong>{pendingCount}</strong>
            </div>
          </div>

          {session.user.role === "TEACHER" ? (
            <div className="action-row top-spacing">
              <Link className="secondary-button button-link" to="/teacher">
                Open marking workspace
              </Link>
            </div>
          ) : null}
        </article>

        <article className="data-panel data-panel-wide">
          <div className="panel-header">
            <div>
              <span className="feature-label">Roster</span>
              <h4>Active students</h4>
            </div>
          </div>

          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Student</th>
                  <th>Admission No</th>
                  <th>Attendance</th>
                  <th>Reason</th>
                  <th>Marked By</th>
                </tr>
              </thead>
              <tbody>
                {rosterRows.map((row) => (
                  <tr key={row.enrollmentId}>
                    <td>{row.fullName}</td>
                    <td>{row.admissionNo}</td>
                    <td>
                      {row.attendance ? (
                        <span className={attendanceStatusClassName(row.attendance.status)}>{row.attendance.status}</span>
                      ) : (
                        <span className="muted">Not marked</span>
                      )}
                    </td>
                    <td>{row.attendance?.reason ?? "--"}</td>
                    <td>{row.attendance?.markedBy?.fullName ?? "--"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {!state.loading && !rosterRows.length ? (
            <p className="empty-state">No active students are enrolled in this class yet.</p>
          ) : null}
        </article>
      </div>
    </section>
  );
};
