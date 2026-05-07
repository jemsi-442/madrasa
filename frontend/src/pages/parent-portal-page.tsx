import { useEffect, useMemo, useState, type FormEvent } from "react";
import { Navigate } from "react-router-dom";

import {
  getParentAnnouncements,
  getParentStudentPayment,
  getParentStudentPaymentReceipt,
  getParentProfile,
  getParentStudentAttendance,
  getParentStudentFinance,
  getParentStudentHifdh,
  initiateParentStudentPayment,
  type ParentAnnouncement,
  type ParentAttendanceRecord,
  type ParentHifdhRecord,
  type ParentInvoice,
  type ParentPaymentReceipt,
  type ParentProfile,
  type ParentStudentPayment,
} from "../lib/api";
import { useAuth } from "../lib/auth";
import { formatDate, formatDateTime, formatMoney } from "../lib/format";

type ParentState = {
  profile: ParentProfile | null;
  announcements: ParentAnnouncement[];
  attendance: ParentAttendanceRecord[];
  finance: ParentInvoice[];
  hifdh: ParentHifdhRecord[];
  selectedInvoiceId: string;
  selectedPayment: ParentStudentPayment | null;
  selectedReceipt: ParentPaymentReceipt | null;
  selectedStudentId: string;
  loading: boolean;
  detailLoading: boolean;
  saving: boolean;
  error: string | null;
  success: string | null;
};

export const ParentPortalPage = () => {
  const { session } = useAuth();
  const [state, setState] = useState<ParentState>({
    profile: null,
    announcements: [],
    attendance: [],
    finance: [],
    hifdh: [],
    selectedInvoiceId: "",
    selectedPayment: null,
    selectedReceipt: null,
    selectedStudentId: "",
    loading: true,
    detailLoading: true,
    saving: false,
    error: null,
    success: null,
  });
  const [paymentForm, setPaymentForm] = useState({
    invoiceId: "",
    payerPhone: "",
    channel: "mpesa" as "mpesa" | "airtel_money" | "tigo_pesa",
  });

  useEffect(() => {
    if (!session || session.user.role !== "PARENT") {
      return;
    }

    let cancelled = false;

    const loadBase = async () => {
      setState((previous) => ({ ...previous, loading: true, error: null }));

      try {
        const [profile, announcements] = await Promise.all([
          getParentProfile(session.accessToken),
          getParentAnnouncements(session.accessToken),
        ]);

        if (cancelled) {
          return;
        }

        const selectedStudentId = profile.students[0]?.id ?? "";
        setState((previous) => ({
          ...previous,
          profile,
          announcements,
          selectedStudentId,
          loading: false,
          detailLoading: Boolean(selectedStudentId),
          saving: false,
          error: null,
          success: null,
        }));
        setPaymentForm((previous) => ({
          ...previous,
          payerPhone: profile.guardian.phone ?? "",
        }));
      } catch (error) {
        if (cancelled) {
          return;
        }

        setState((previous) => ({
          ...previous,
          loading: false,
          detailLoading: false,
          saving: false,
          error: error instanceof Error ? error.message : "Failed to load parent portal.",
        }));
      }
    };

    void loadBase();

    return () => {
      cancelled = true;
    };
  }, [session]);

  useEffect(() => {
    if (!session || session.user.role !== "PARENT" || !state.selectedStudentId) {
      return;
    }

    let cancelled = false;

    const loadStudentDetails = async () => {
      setState((previous) => ({
        ...previous,
        detailLoading: true,
        error: null,
        success: null,
      }));

      try {
        const [attendance, finance, hifdh] = await Promise.all([
          getParentStudentAttendance(session.accessToken, state.selectedStudentId),
          getParentStudentFinance(session.accessToken, state.selectedStudentId),
          getParentStudentHifdh(session.accessToken, state.selectedStudentId),
        ]);

        if (cancelled) {
          return;
        }

        setState((previous) => ({
          ...previous,
          attendance,
          finance,
          hifdh,
          selectedInvoiceId:
            finance.find((invoice) => invoice.status !== "PAID" && invoice.status !== "CANCELLED")?.id ?? "",
          selectedPayment: null,
          selectedReceipt: null,
          detailLoading: false,
          error: null,
        }));
        setPaymentForm((previous) => ({
          ...previous,
          invoiceId:
            finance.find((invoice) => invoice.status !== "PAID" && invoice.status !== "CANCELLED")?.id ?? "",
        }));
      } catch (error) {
        if (cancelled) {
          return;
        }

        setState((previous) => ({
          ...previous,
          detailLoading: false,
          error: error instanceof Error ? error.message : "Failed to load child detail.",
        }));
      }
    };

    void loadStudentDetails();

    return () => {
      cancelled = true;
    };
  }, [session, state.selectedStudentId]);

  if (!session) {
    return null;
  }

  if (session.user.role === "ADMIN" || session.user.role === "ACCOUNTANT") {
    return <Navigate to="/dashboard" replace />;
  }

  if (session.user.role === "TEACHER") {
    return <Navigate to="/teacher" replace />;
  }

  const selectedStudent = state.profile?.students.find((student) => student.id === state.selectedStudentId) ?? null;
  const selectedInvoice = useMemo(
    () => state.finance.find((invoice) => invoice.id === paymentForm.invoiceId || invoice.id === state.selectedInvoiceId) ?? null,
    [paymentForm.invoiceId, state.finance, state.selectedInvoiceId],
  );

  const withSaving = async (work: () => Promise<void>) => {
    setState((previous) => ({
      ...previous,
      saving: true,
      error: null,
      success: null,
    }));

    try {
      await work();
    } catch (error) {
      setState((previous) => ({
        ...previous,
        saving: false,
        error: error instanceof Error ? error.message : "Request failed.",
      }));
      return;
    }

    setState((previous) => ({
      ...previous,
      saving: false,
    }));
  };

  const handleInitiatePayment = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (!session || !state.selectedStudentId || !paymentForm.invoiceId) {
      return;
    }

    await withSaving(async () => {
      const payment = await initiateParentStudentPayment(
        session.accessToken,
        state.selectedStudentId,
        {
          invoiceId: paymentForm.invoiceId,
          payerPhone: paymentForm.payerPhone.trim(),
          channel: paymentForm.channel,
        },
      );

      setState((previous) => ({
        ...previous,
        selectedPayment: payment,
        finance: previous.finance.map((invoice) =>
          invoice.id === payment.invoiceId
            ? {
                ...invoice,
                payments: [
                  {
                    id: payment.id,
                    amount: payment.amount,
                    currency: payment.currency,
                    status: payment.status,
                    channel: payment.channel,
                    reference: payment.reference,
                    externalReference: payment.externalReference,
                    paidAt: payment.paidAt,
                    createdAt: payment.createdAt,
                  },
                  ...invoice.payments,
                ],
              }
            : invoice,
        ),
        success: "Payment request submitted successfully.",
      }));
    });
  };

  const handleViewPayment = async (paymentId: string) => {
    if (!session || !state.selectedStudentId) {
      return;
    }

    await withSaving(async () => {
      const payment = await getParentStudentPayment(
        session.accessToken,
        state.selectedStudentId,
        paymentId,
      );

      setState((previous) => ({
        ...previous,
        selectedPayment: payment,
        selectedReceipt: null,
        success: "Payment detail loaded successfully.",
      }));
    });
  };

  const handleViewReceipt = async (paymentId: string) => {
    if (!session || !state.selectedStudentId) {
      return;
    }

    await withSaving(async () => {
      const receipt = await getParentStudentPaymentReceipt(
        session.accessToken,
        state.selectedStudentId,
        paymentId,
      );

      setState((previous) => ({
        ...previous,
        selectedReceipt: receipt,
        success: "Receipt loaded successfully.",
      }));
    });
  };

  return (
    <section className="page-card">
      <div className="page-heading">
        <p className="eyebrow">Parent Portal</p>
        <h3>Parent-facing workspace</h3>
        <p>
          This view shows live child attendance, finance, announcements, and hifdh progress.
        </p>
      </div>

      {state.error ? <div className="banner error-banner">{state.error}</div> : null}
      {state.success ? <div className="banner success-banner">{state.success}</div> : null}

      <div className="stats-grid">
        <article className="stat-card">
          <span className="feature-label">Guardian</span>
          <strong className="stat-value">{state.profile?.guardian.fullName ?? "--"}</strong>
          <p className="muted">{state.profile?.guardian.relationship ?? "Parent contact"}</p>
        </article>
        <article className="stat-card">
          <span className="feature-label">Children</span>
          <strong className="stat-value">{state.profile?.students.length ?? "--"}</strong>
          <p className="muted">Linked to this account</p>
        </article>
        <article className="stat-card">
          <span className="feature-label">Announcements</span>
          <strong className="stat-value">{state.announcements.length}</strong>
          <p className="muted">Visible to this family</p>
        </article>
        <article className="stat-card">
          <span className="feature-label">Selected Student</span>
          <strong className="stat-value">{selectedStudent?.fullName ?? "--"}</strong>
          <p className="muted">{selectedStudent?.currentClass?.name ?? "No class assigned"}</p>
        </article>
      </div>

      <div className="page-actions">
        <label className="inline-field">
          <span>Child</span>
          <select
            value={state.selectedStudentId}
            onChange={(event) =>
              setState((previous) => ({ ...previous, selectedStudentId: event.target.value }))
            }
          >
            {(state.profile?.students ?? []).map((student) => (
              <option key={student.id} value={student.id}>
                {student.fullName} ({student.admissionNo})
              </option>
            ))}
          </select>
        </label>
      </div>

      <div className="data-grid">
        <article className="data-panel">
          <div className="panel-header">
            <div>
              <span className="feature-label">Attendance</span>
              <h4>Latest attendance records</h4>
            </div>
          </div>

          <div className="row-list">
            {state.attendance.slice(0, 6).map((record) => (
              <div key={record.id} className="row-item stacked-row">
                <div>
                  <strong>{record.date}</strong>
                  <p className="muted">
                    {record.class.name} • marked by {record.markedBy.fullName}
                  </p>
                </div>
                <span className={`status-chip status-${record.status.toLowerCase()}`}>{record.status}</span>
              </div>
            ))}
            {!state.detailLoading && !state.attendance.length ? <p className="empty-state">No attendance records yet.</p> : null}
          </div>
        </article>

        <article className="data-panel">
          <div className="panel-header">
            <div>
              <span className="feature-label">Announcements</span>
              <h4>School communication</h4>
            </div>
          </div>

          <div className="row-list">
            {state.announcements.slice(0, 5).map((announcement) => (
              <div key={announcement.id} className="row-item stacked-row">
                <div>
                  <strong>{announcement.title}</strong>
                  <p className="muted">{announcement.message}</p>
                </div>
                <strong>{formatDateTime(announcement.publishAt)}</strong>
              </div>
            ))}
            {!state.announcements.length ? <p className="empty-state">No announcements available.</p> : null}
          </div>
        </article>

        <article className="data-panel data-panel-wide">
          <div className="panel-header">
            <div>
              <span className="feature-label">Finance</span>
              <h4>Invoices and payment status</h4>
            </div>
          </div>

          <div className="split-panel">
            <form className="form-card compact-form" onSubmit={handleInitiatePayment}>
              <label className="full-span">
                <span>Invoice</span>
                <select
                  value={paymentForm.invoiceId}
                  onChange={(event) =>
                    setPaymentForm((previous) => ({ ...previous, invoiceId: event.target.value }))
                  }
                >
                  <option value="">Choose invoice</option>
                  {state.finance
                    .filter((invoice) => invoice.status !== "PAID" && invoice.status !== "CANCELLED")
                    .map((invoice) => (
                      <option key={invoice.id} value={invoice.id}>
                        {invoice.invoiceNo} • {formatMoney(invoice.balanceRemaining, invoice.currency)}
                      </option>
                    ))}
                </select>
              </label>
              <label>
                <span>Payer Phone</span>
                <input
                  value={paymentForm.payerPhone}
                  onChange={(event) =>
                    setPaymentForm((previous) => ({ ...previous, payerPhone: event.target.value }))
                  }
                  required
                />
              </label>
              <label>
                <span>Channel</span>
                <select
                  value={paymentForm.channel}
                  onChange={(event) =>
                    setPaymentForm((previous) => ({
                      ...previous,
                      channel: event.target.value as typeof previous.channel,
                    }))
                  }
                >
                  <option value="mpesa">M-Pesa</option>
                  <option value="airtel_money">Airtel Money</option>
                  <option value="tigo_pesa">Tigo Pesa</option>
                </select>
              </label>

              <div className="detail-card full-span">
                <span className="feature-label">Selected Invoice</span>
                <h5>{selectedInvoice?.invoiceNo ?? "No invoice selected"}</h5>
                <p className="muted">
                  Balance:{" "}
                  {selectedInvoice
                    ? formatMoney(selectedInvoice.balanceRemaining, selectedInvoice.currency)
                    : "--"}
                </p>
              </div>

              <button
                className="primary-button full-span"
                type="submit"
                disabled={state.saving || !paymentForm.invoiceId}
              >
                {state.saving ? "Submitting..." : "Initiate Payment"}
              </button>
            </form>

            <div className="stack-panel">
              <div className="detail-card">
                <span className="feature-label">Payment Status</span>
                <h5>{state.selectedPayment?.status ?? "No payment selected"}</h5>
                <p className="muted">
                  {state.selectedPayment
                    ? `${formatMoney(state.selectedPayment.amount, state.selectedPayment.currency)} • ${
                        state.selectedPayment.channel ?? "channel not set"
                      }`
                    : "Select or create a payment to inspect status."}
                </p>
                {state.selectedPayment?.reference ? (
                  <p className="muted">Reference: {state.selectedPayment.reference}</p>
                ) : null}
              </div>

              {state.selectedReceipt ? (
                <div className="detail-card">
                  <span className="feature-label">{state.selectedReceipt.receiptNo}</span>
                  <h5>{state.selectedReceipt.student.fullName}</h5>
                  <p className="muted">
                    Paid:{" "}
                    {formatMoney(
                      state.selectedReceipt.payment.amount,
                      state.selectedReceipt.payment.currency,
                    )}
                  </p>
                  <p className="muted">
                    {state.selectedReceipt.payment.paidAt
                      ? formatDateTime(state.selectedReceipt.payment.paidAt)
                      : "Awaiting completion"}
                  </p>
                </div>
              ) : (
                <div className="detail-card">
                  <span className="feature-label">Receipt Preview</span>
                  <h5>Completed payments only</h5>
                  <p className="muted">Open a completed payment below to view the receipt.</p>
                </div>
              )}
            </div>
          </div>

          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Invoice</th>
                  <th>Fee</th>
                  <th>Due</th>
                  <th>Paid</th>
                  <th>Balance</th>
                  <th>Status</th>
                  <th>Payments</th>
                </tr>
              </thead>
              <tbody>
                {state.finance.map((invoice) => (
                  <tr key={invoice.id}>
                    <td>{invoice.invoiceNo}</td>
                    <td>{invoice.feeStructure?.name ?? "General fee"}</td>
                    <td>{formatMoney(invoice.amountDue, invoice.currency)}</td>
                    <td>{formatMoney(invoice.amountPaid, invoice.currency)}</td>
                    <td>{formatMoney(invoice.balanceRemaining, invoice.currency)}</td>
                    <td>{invoice.status}</td>
                    <td>{invoice.payments.length}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {!state.detailLoading && !state.finance.length ? <p className="empty-state">No invoices found for this student.</p> : null}
        </article>

        <article className="data-panel data-panel-wide">
          <div className="panel-header">
            <div>
              <span className="feature-label">Payments</span>
              <h4>Payment requests and receipts</h4>
            </div>
          </div>

          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Invoice</th>
                  <th>Amount</th>
                  <th>Channel</th>
                  <th>Status</th>
                  <th>Created</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {state.finance.flatMap((invoice) =>
                  invoice.payments.map((payment) => (
                    <tr key={payment.id}>
                      <td>{invoice.invoiceNo}</td>
                      <td>{formatMoney(payment.amount, payment.currency)}</td>
                      <td>{payment.channel ?? "--"}</td>
                      <td>{payment.status}</td>
                      <td>{formatDateTime(payment.createdAt)}</td>
                      <td>
                        <div className="action-row">
                          <button
                            type="button"
                            className="secondary-button"
                            onClick={() => void handleViewPayment(payment.id)}
                            disabled={state.saving}
                          >
                            View
                          </button>
                          {payment.status === "COMPLETED" ? (
                            <button
                              type="button"
                              className="secondary-button"
                              onClick={() => void handleViewReceipt(payment.id)}
                              disabled={state.saving}
                            >
                              Receipt
                            </button>
                          ) : null}
                        </div>
                      </td>
                    </tr>
                  )),
                )}
              </tbody>
            </table>
          </div>

          {!state.detailLoading && !state.finance.some((invoice) => invoice.payments.length) ? (
            <p className="empty-state">No payment requests recorded yet.</p>
          ) : null}
        </article>

        <article className="data-panel data-panel-wide">
          <div className="panel-header">
            <div>
              <span className="feature-label">Hifdh</span>
              <h4>Recent progress</h4>
            </div>
          </div>

          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Juz</th>
                  <th>Surah</th>
                  <th>Memorization</th>
                  <th>Revision</th>
                  <th>Teacher</th>
                </tr>
              </thead>
              <tbody>
                {state.hifdh.map((record) => (
                  <tr key={record.id}>
                    <td>{formatDate(record.assessedOn)}</td>
                    <td>{record.juzNumber}</td>
                    <td>{record.surahName}</td>
                    <td>{record.memorizationScore}</td>
                    <td>{record.revisionScore ?? "--"}</td>
                    <td>{record.teacher.fullName}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {!state.detailLoading && !state.hifdh.length ? <p className="empty-state">No hifdh progress recorded yet.</p> : null}
        </article>
      </div>
    </section>
  );
};
