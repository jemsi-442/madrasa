import { useEffect, useState } from "react";
import { Navigate } from "react-router-dom";

import {
  exportAttendanceReport,
  exportMonthlyFinanceSummaryReport,
  exportPaymentsReport,
  exportStudentsReport,
  getAttendanceSummaryReport,
  getDashboardReport,
  getMonthlyFinanceSummaryReport,
  type AttendanceSummaryReport,
  type DashboardReport,
  type MonthlyFinanceSummaryReport,
} from "../lib/api";
import { useAuth } from "../lib/auth";
import { formatMoney } from "../lib/format";

type DashboardState = {
  dashboard: DashboardReport | null;
  attendance: AttendanceSummaryReport | null;
  finance: MonthlyFinanceSummaryReport | null;
  loading: boolean;
  error: string | null;
  success: string | null;
};

const currentYear = new Date().getFullYear();

export const DashboardPage = () => {
  const { session } = useAuth();
  const [year, setYear] = useState(currentYear);
  const [state, setState] = useState<DashboardState>({
    dashboard: null,
    attendance: null,
    finance: null,
    loading: true,
    error: null,
    success: null,
  });
  const [exporting, setExporting] = useState<null | "students" | "attendance" | "payments" | "finance">(null);

  useEffect(() => {
    if (!session) {
      return;
    }

    if (session.user.role === "TEACHER" || session.user.role === "PARENT") {
      return;
    }

    let cancelled = false;

    const load = async () => {
      setState((previous) => ({ ...previous, loading: true, error: null }));

      try {
        const [dashboard, attendance, finance] = await Promise.all([
          getDashboardReport(session.accessToken),
          getAttendanceSummaryReport(session.accessToken),
          getMonthlyFinanceSummaryReport(session.accessToken, year),
        ]);

        if (cancelled) {
          return;
        }

        setState({
          dashboard,
          attendance,
          finance,
          loading: false,
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
          error: error instanceof Error ? error.message : "Failed to load dashboard data.",
        }));
      }
    };

    void load();

    return () => {
      cancelled = true;
    };
  }, [session, year]);

  if (!session) {
    return null;
  }

  if (session.user.role === "TEACHER") {
    return <Navigate to="/teacher" replace />;
  }

  if (session.user.role === "PARENT") {
    return <Navigate to="/parent" replace />;
  }

  const { dashboard, attendance, finance, loading, error, success } = state;

  const handleExport = async (key: "students" | "attendance" | "payments" | "finance") => {
    if (!session) {
      return;
    }

    setExporting(key);
    setState((previous) => ({ ...previous, error: null, success: null }));

    try {
      if (key === "students") {
        await exportStudentsReport(session.accessToken, { status: "ACTIVE" });
      } else if (key === "attendance") {
        await exportAttendanceReport(session.accessToken);
      } else if (key === "payments") {
        await exportPaymentsReport(session.accessToken);
      } else {
        await exportMonthlyFinanceSummaryReport(session.accessToken, { year });
      }

      setState((previous) => ({
        ...previous,
        success: "Export download started successfully.",
      }));
    } catch (downloadError) {
      setState((previous) => ({
        ...previous,
        error: downloadError instanceof Error ? downloadError.message : "Failed to export report.",
      }));
    } finally {
      setExporting(null);
    }
  };

  return (
    <section className="page-card">
      <div className="page-heading">
        <p className="eyebrow">{session.user.role === "ACCOUNTANT" ? "Finance Workspace" : "Admin Workspace"}</p>
        <h3>Operational dashboard</h3>
        <p>
          This view is backed by the live reporting APIs for students, attendance, hifdh, and finance.
        </p>
      </div>

      <div className="page-actions">
        <label className="inline-field">
          <span>Finance Year</span>
          <select value={year} onChange={(event) => setYear(Number(event.target.value))}>
            {[currentYear - 1, currentYear, currentYear + 1].map((option) => (
              <option key={option} value={option}>
                {option}
              </option>
            ))}
          </select>
        </label>

        <div className="action-row">
          <button
            type="button"
            className="secondary-button"
            onClick={() => void handleExport("students")}
            disabled={exporting !== null}
          >
            {exporting === "students" ? "Preparing Students..." : "Export Students"}
          </button>
          <button
            type="button"
            className="secondary-button"
            onClick={() => void handleExport("attendance")}
            disabled={exporting !== null}
          >
            {exporting === "attendance" ? "Preparing Attendance..." : "Export Attendance"}
          </button>
          <button
            type="button"
            className="secondary-button"
            onClick={() => void handleExport("payments")}
            disabled={exporting !== null}
          >
            {exporting === "payments" ? "Preparing Payments..." : "Export Payments"}
          </button>
          <button
            type="button"
            className="secondary-button"
            onClick={() => void handleExport("finance")}
            disabled={exporting !== null}
          >
            {exporting === "finance" ? "Preparing Finance..." : `Export Finance ${year}`}
          </button>
        </div>
      </div>

      {error ? <div className="banner error-banner">{error}</div> : null}
      {success ? <div className="banner success-banner">{success}</div> : null}

      <div className="stats-grid">
        <article className="stat-card">
          <span className="feature-label">Students</span>
          <strong className="stat-value">{dashboard?.students.total ?? "--"}</strong>
          <p className="muted">Active: {dashboard?.students.active ?? "--"}</p>
        </article>
        <article className="stat-card">
          <span className="feature-label">Attendance Rate</span>
          <strong className="stat-value">{attendance?.totals.attendanceRate ?? "--"}%</strong>
          <p className="muted">Present records: {attendance?.totals.present ?? "--"}</p>
        </article>
        <article className="stat-card">
          <span className="feature-label">Outstanding Balance</span>
          <strong className="stat-value">
            {dashboard?.finance ? formatMoney(dashboard.finance.invoices.outstandingBalance) : "--"}
          </strong>
          <p className="muted">Collected: {dashboard?.finance ? formatMoney(dashboard.finance.collections.collectedAmount) : "--"}</p>
        </article>
        <article className="stat-card">
          <span className="feature-label">Hifdh Assessments</span>
          <strong className="stat-value">{dashboard?.hifdh.totalAssessments ?? "--"}</strong>
          <p className="muted">Average memorization: {dashboard?.hifdh.averageMemorizationScore ?? "--"}</p>
        </article>
      </div>

      <div className="data-grid">
        <article className="data-panel">
          <div className="panel-header">
            <div>
              <span className="feature-label">Student Status</span>
              <h4>Enrollment overview</h4>
            </div>
          </div>

          <div className="row-list">
            <div className="row-item"><span>Active</span><strong>{dashboard?.students.active ?? "--"}</strong></div>
            <div className="row-item"><span>Inactive</span><strong>{dashboard?.students.inactive ?? "--"}</strong></div>
            <div className="row-item"><span>Suspended</span><strong>{dashboard?.students.suspended ?? "--"}</strong></div>
            <div className="row-item"><span>Graduated</span><strong>{dashboard?.students.graduated ?? "--"}</strong></div>
          </div>
        </article>

        <article className="data-panel">
          <div className="panel-header">
            <div>
              <span className="feature-label">Attendance Window</span>
              <h4>Latest daily mix</h4>
            </div>
          </div>

          <div className="row-list">
            {(attendance?.timeline ?? []).slice(-5).reverse().map((entry) => (
              <div key={entry.date} className="row-item">
                <span>{entry.date}</span>
                <strong>
                  P:{entry.present} A:{entry.absent} L:{entry.late} E:{entry.excused}
                </strong>
              </div>
            ))}
            {!loading && !attendance?.timeline.length ? <p className="empty-state">No attendance records yet.</p> : null}
          </div>
        </article>

        <article className="data-panel data-panel-wide">
          <div className="panel-header">
            <div>
              <span className="feature-label">Finance</span>
              <h4>Monthly summary for {year}</h4>
            </div>
          </div>

          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Month</th>
                  <th>Invoiced</th>
                  <th>Collected</th>
                  <th>Expenses</th>
                  <th>Net Cash Flow</th>
                </tr>
              </thead>
              <tbody>
                {(finance?.months ?? []).map((month) => (
                  <tr key={month.month}>
                    <td>{month.label}</td>
                    <td>{formatMoney(month.invoicedAmount)}</td>
                    <td>{formatMoney(month.collectedAmount)}</td>
                    <td>{formatMoney(month.expenseAmount)}</td>
                    <td>{formatMoney(month.netCashFlow)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {!loading && !finance?.months.length ? <p className="empty-state">No finance rows found for this year.</p> : null}
        </article>
      </div>
    </section>
  );
};
