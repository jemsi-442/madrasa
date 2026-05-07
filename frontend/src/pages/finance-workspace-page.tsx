import { useEffect, useMemo, useState, type FormEvent } from "react";
import { Navigate, useSearchParams } from "react-router-dom";

import {
  createExpense,
  createFeeStructure,
  createInvoice,
  getOrganizationProfile,
  getPaymentReceipt,
  initiatePayment,
  listClasses,
  listExpenses,
  listFeeStructures,
  listInvoices,
  listPayments,
  listStudents,
  reconcilePayment,
  type ClassRecord,
  type ExpenseRecord,
  type FeeStructureRecord,
  type InvoiceRecord,
  type OrganizationProfile,
  type PaymentReceipt,
  type PaymentRecord,
  type StudentRecord,
} from "../lib/api";
import { useAuth } from "../lib/auth";
import { formatDate, formatDateTime, formatMoney } from "../lib/format";

type FinanceState = {
  organization: OrganizationProfile | null;
  classes: ClassRecord[];
  students: StudentRecord[];
  feeStructures: FeeStructureRecord[];
  feeStructuresMeta: {
    page: number;
    pageSize: number;
    totalItems: number;
    totalPages: number;
  } | null;
  invoices: InvoiceRecord[];
  invoicesMeta: {
    page: number;
    pageSize: number;
    totalItems: number;
    totalPages: number;
  } | null;
  payments: PaymentRecord[];
  paymentsMeta: {
    page: number;
    pageSize: number;
    totalItems: number;
    totalPages: number;
  } | null;
  expenses: ExpenseRecord[];
  expensesMeta: {
    page: number;
    pageSize: number;
    totalItems: number;
    totalPages: number;
  } | null;
  selectedInvoiceId: string;
  selectedReceipt: PaymentReceipt | null;
  loading: boolean;
  saving: boolean;
  error: string | null;
  success: string | null;
};

type FinanceFilters = {
  search: string;
  branchId: string;
  invoiceStatus: string;
  paymentStatus: string;
  invoicePage: number;
  paymentPage: number;
};

type FeeStructureForm = {
  name: string;
  amount: string;
  billingCycle: "ONE_TIME" | "MONTHLY" | "TERMLY";
  branchId: string;
  classId: string;
};

type InvoiceForm = {
  studentId: string;
  feeMode: "structure" | "custom";
  feeStructureId: string;
  amountDue: string;
  dueDate: string;
};

type PaymentForm = {
  invoiceId: string;
  payerPhone: string;
  channel: "mpesa" | "airtel_money" | "tigo_pesa";
  firstname: string;
  lastname: string;
  email: string;
};

type ExpenseForm = {
  title: string;
  description: string;
  amount: string;
  expenseDate: string;
  branchId: string;
};

const splitFullName = (fullName: string) => {
  const parts = fullName.trim().split(/\s+/).filter(Boolean);
  return {
    firstname: parts[0] ?? "",
    lastname: parts.slice(1).join(" ") || parts[0] || "",
  };
};

const parsePositivePage = (value: string | null, fallback = 1) => {
  const parsed = Number(value);

  if (!Number.isInteger(parsed) || parsed < 1) {
    return fallback;
  }

  return parsed;
};

export const FinanceWorkspacePage = () => {
  const { session } = useAuth();
  const [searchParams, setSearchParams] = useSearchParams();
  const initialFilters: FinanceFilters = {
    search: searchParams.get("search") ?? "",
    branchId: searchParams.get("branchId") ?? "",
    invoiceStatus: searchParams.get("invoiceStatus") ?? "",
    paymentStatus: searchParams.get("paymentStatus") ?? "",
    invoicePage: parsePositivePage(searchParams.get("invoicePage")),
    paymentPage: parsePositivePage(searchParams.get("paymentPage")),
  };
  const today = new Date().toISOString().slice(0, 10);
  const [state, setState] = useState<FinanceState>({
    organization: null,
    classes: [],
    students: [],
    feeStructures: [],
    feeStructuresMeta: null,
    invoices: [],
    invoicesMeta: null,
    payments: [],
    paymentsMeta: null,
    expenses: [],
    expensesMeta: null,
    selectedInvoiceId: "",
    selectedReceipt: null,
    loading: true,
    saving: false,
    error: null,
    success: null,
  });
  const [filters, setFilters] = useState<FinanceFilters>(initialFilters);
  const [searchInput, setSearchInput] = useState(initialFilters.search);
  const [feeStructureForm, setFeeStructureForm] = useState<FeeStructureForm>({
    name: "",
    amount: "",
    billingCycle: "TERMLY",
    branchId: "",
    classId: "",
  });
  const [invoiceForm, setInvoiceForm] = useState<InvoiceForm>({
    studentId: "",
    feeMode: "structure",
    feeStructureId: "",
    amountDue: "",
    dueDate: today,
  });
  const [paymentForm, setPaymentForm] = useState<PaymentForm>({
    invoiceId: "",
    payerPhone: "",
    channel: "mpesa",
    firstname: "",
    lastname: "",
    email: "",
  });
  const [expenseForm, setExpenseForm] = useState<ExpenseForm>({
    title: "",
    description: "",
    amount: "",
    expenseDate: today,
    branchId: "",
  });

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setFilters((previous) =>
        previous.search === searchInput
          ? previous
          : {
              ...previous,
              search: searchInput,
              invoicePage: 1,
              paymentPage: 1,
            },
      );
    }, 350);

    return () => {
      window.clearTimeout(timer);
    };
  }, [searchInput]);

  useEffect(() => {
    const nextParams = new URLSearchParams();

    if (filters.search.trim()) {
      nextParams.set("search", filters.search.trim());
    }

    if (filters.branchId) {
      nextParams.set("branchId", filters.branchId);
    }

    if (filters.invoiceStatus) {
      nextParams.set("invoiceStatus", filters.invoiceStatus);
    }

    if (filters.paymentStatus) {
      nextParams.set("paymentStatus", filters.paymentStatus);
    }

    if (filters.invoicePage > 1) {
      nextParams.set("invoicePage", String(filters.invoicePage));
    }

    if (filters.paymentPage > 1) {
      nextParams.set("paymentPage", String(filters.paymentPage));
    }

    setSearchParams(nextParams, { replace: true });
  }, [filters, setSearchParams]);

  useEffect(() => {
    if (!session || (session.user.role !== "ADMIN" && session.user.role !== "ACCOUNTANT")) {
      return;
    }

    let cancelled = false;

    const load = async () => {
      setState((previous) => ({ ...previous, loading: true, error: null }));

      try {
        const [
          organization,
          classes,
          studentsResponse,
          feeStructuresResponse,
          invoicesResponse,
          paymentsResponse,
          expensesResponse,
        ] = await Promise.all([
          getOrganizationProfile(session.accessToken),
          listClasses(session.accessToken),
          listStudents(session.accessToken, {
            page: "1",
            pageSize: "100",
          }),
          listFeeStructures(session.accessToken, {
            branchId: filters.branchId || undefined,
            search: filters.search.trim() || undefined,
            page: "1",
            pageSize: "100",
          }),
          listInvoices(session.accessToken, {
            branchId: filters.branchId || undefined,
            status: filters.invoiceStatus || undefined,
            search: filters.search.trim() || undefined,
            page: String(filters.invoicePage),
            pageSize: "8",
          }),
          listPayments(session.accessToken, {
            branchId: filters.branchId || undefined,
            status: filters.paymentStatus || undefined,
            search: filters.search.trim() || undefined,
            page: String(filters.paymentPage),
            pageSize: "8",
          }),
          listExpenses(session.accessToken, {
            branchId: filters.branchId || undefined,
            search: filters.search.trim() || undefined,
            page: "1",
            pageSize: "20",
          }),
        ]);

        if (cancelled) {
          return;
        }

        const students = studentsResponse.items;
        const feeStructures = feeStructuresResponse.items;
        const invoices = invoicesResponse.items;
        const payments = paymentsResponse.items;
        const expenses = expensesResponse.items;
        const firstBranchId = organization.branches[0]?.id ?? "";
        const firstStudentId = students[0]?.id ?? "";
        const firstStructureId = feeStructures[0]?.id ?? "";
        const openInvoiceId =
          invoices.find((invoice) => invoice.status !== "PAID" && invoice.status !== "CANCELLED")?.id ?? "";

        setState({
          organization,
          classes,
          students,
          feeStructures,
          feeStructuresMeta: feeStructuresResponse.meta,
          invoices,
          invoicesMeta: invoicesResponse.meta,
          payments,
          paymentsMeta: paymentsResponse.meta,
          expenses,
          expensesMeta: expensesResponse.meta,
          selectedInvoiceId: openInvoiceId,
          selectedReceipt: null,
          loading: false,
          saving: false,
          error: null,
          success: null,
        });
        setFeeStructureForm((previous) => ({
          ...previous,
          branchId: firstBranchId,
        }));
        setInvoiceForm({
          studentId: firstStudentId,
          feeMode: firstStructureId ? "structure" : "custom",
          feeStructureId: firstStructureId,
          amountDue: "",
          dueDate: today,
        });
        setExpenseForm((previous) => ({
          ...previous,
          branchId: firstBranchId,
        }));
      } catch (error) {
        if (cancelled) {
          return;
        }

        setState((previous) => ({
          ...previous,
          loading: false,
          error: error instanceof Error ? error.message : "Failed to load finance workspace.",
        }));
      }
    };

    void load();

    return () => {
      cancelled = true;
    };
  }, [
    filters.branchId,
    filters.invoicePage,
    filters.invoiceStatus,
    filters.paymentPage,
    filters.paymentStatus,
    filters.search,
    session,
    today,
  ]);

  const selectedStudent = useMemo(
    () => state.students.find((student) => student.id === invoiceForm.studentId) ?? null,
    [invoiceForm.studentId, state.students],
  );

  const filteredClassOptions = useMemo(
    () => state.classes.filter((classRecord) => classRecord.branchId === feeStructureForm.branchId),
    [feeStructureForm.branchId, state.classes],
  );

  const invoiceSummary = useMemo(
    () => ({
      total: state.invoices.length,
      outstanding: state.invoices.filter((invoice) => invoice.status !== "PAID" && invoice.status !== "CANCELLED").length,
      amountDue: state.invoices.reduce((sum, invoice) => sum + Number(invoice.amountDue), 0),
      amountPaid: state.invoices.reduce((sum, invoice) => sum + Number(invoice.amountPaid), 0),
    }),
    [state.invoices],
  );

  const paymentsSummary = useMemo(
    () => ({
      total: state.payments.length,
      pending: state.payments.filter((payment) => payment.status === "PENDING").length,
      completedAmount: state.payments
        .filter((payment) => payment.status === "COMPLETED")
        .reduce((sum, payment) => sum + Number(payment.amount), 0),
    }),
    [state.payments],
  );
  const totalInvoicePages = state.invoicesMeta?.totalPages ?? 1;
  const totalPaymentPages = state.paymentsMeta?.totalPages ?? 1;

  const syncPaymentCustomerFromInvoice = (invoiceId: string) => {
    const invoice = state.invoices.find((entry) => entry.id === invoiceId);

    if (!invoice) {
      return;
    }

    const student = state.students.find((entry) => entry.id === invoice.studentId);
    const guardianName = student?.primaryGuardian?.fullName ?? invoice.student?.fullName ?? "";
    const names = splitFullName(guardianName);

    setPaymentForm((previous) => ({
      ...previous,
      invoiceId,
      firstname: names.firstname || previous.firstname,
      lastname: names.lastname || previous.lastname,
      email: student?.primaryGuardian.email ?? previous.email,
      payerPhone: student?.primaryGuardian.phone ?? previous.payerPhone,
    }));
  };

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

  const handleCreateFeeStructure = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (!session) {
      return;
    }

    await withSaving(async () => {
      const created = await createFeeStructure(session.accessToken, {
        name: feeStructureForm.name.trim(),
        amount: feeStructureForm.amount.trim(),
        billingCycle: feeStructureForm.billingCycle,
        branchId: feeStructureForm.branchId || undefined,
        classId: feeStructureForm.classId || undefined,
      });

      setState((previous) => ({
        ...previous,
        feeStructures: [created, ...previous.feeStructures],
        success: "Fee structure created successfully.",
      }));
      setFeeStructureForm((previous) => ({
        ...previous,
        name: "",
        amount: "",
        classId: "",
      }));
      setInvoiceForm((previous) => ({
        ...previous,
        feeMode: "structure",
        feeStructureId: created.id,
      }));
    });
  };

  const handleCreateInvoice = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (!session) {
      return;
    }

    await withSaving(async () => {
      const created = await createInvoice(session.accessToken, {
        studentId: invoiceForm.studentId,
        feeStructureId: invoiceForm.feeMode === "structure" ? invoiceForm.feeStructureId : undefined,
        amountDue: invoiceForm.feeMode === "custom" ? invoiceForm.amountDue.trim() : undefined,
        dueDate: invoiceForm.dueDate,
        currency: "TZS",
      });

      setState((previous) => ({
        ...previous,
        invoices: [created, ...previous.invoices],
        selectedInvoiceId: created.id,
        success: "Invoice created successfully.",
      }));
      syncPaymentCustomerFromInvoice(created.id);
    });
  };

  const handleInitiatePayment = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (!session) {
      return;
    }

    await withSaving(async () => {
      const created = await initiatePayment(session.accessToken, {
        invoiceId: paymentForm.invoiceId,
        payerPhone: paymentForm.payerPhone.trim(),
        channel: paymentForm.channel,
        customer: {
          firstname: paymentForm.firstname.trim(),
          lastname: paymentForm.lastname.trim(),
          email: paymentForm.email.trim() || undefined,
        },
      });

      setState((previous) => ({
        ...previous,
        payments: [created, ...previous.payments],
        success: "Payment request submitted successfully.",
      }));
    });
  };

  const handleCreateExpense = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (!session) {
      return;
    }

    await withSaving(async () => {
      const created = await createExpense(session.accessToken, {
        title: expenseForm.title.trim(),
        description: expenseForm.description.trim() || undefined,
        amount: expenseForm.amount.trim(),
        expenseDate: expenseForm.expenseDate,
        branchId: expenseForm.branchId || undefined,
        currency: "TZS",
      });

      setState((previous) => ({
        ...previous,
        expenses: [created, ...previous.expenses],
        success: "Expense recorded successfully.",
      }));
      setExpenseForm((previous) => ({
        ...previous,
        title: "",
        description: "",
        amount: "",
      }));
    });
  };

  const handleReconcilePayment = async (paymentId: string) => {
    if (!session) {
      return;
    }

    await withSaving(async () => {
      const updated = await reconcilePayment(session.accessToken, paymentId);

      setState((previous) => ({
        ...previous,
        payments: previous.payments.map((payment) => (payment.id === updated.id ? updated : payment)),
        invoices: previous.invoices.map((invoice) =>
          invoice.id === updated.invoiceId
            ? {
                ...invoice,
                amountPaid:
                  updated.status === "COMPLETED"
                    ? (
                        Number(invoice.amountPaid) +
                        Number(updated.amount)
                      ).toFixed(2)
                    : invoice.amountPaid,
              }
            : invoice,
        ),
        success: "Payment reconciled successfully.",
      }));
    });
  };

  const handleLoadReceipt = async (paymentId: string) => {
    if (!session) {
      return;
    }

    await withSaving(async () => {
      const receipt = await getPaymentReceipt(session.accessToken, paymentId);

      setState((previous) => ({
        ...previous,
        selectedReceipt: receipt,
        success: "Receipt loaded successfully.",
      }));
    });
  };

  if (!session) {
    return null;
  }

  if (session.user.role === "TEACHER") {
    return <Navigate to="/teacher" replace />;
  }

  if (session.user.role === "PARENT") {
    return <Navigate to="/parent" replace />;
  }

  return (
    <section className="page-card">
      <div className="page-heading">
        <p className="eyebrow">Finance Workspace</p>
        <h3>Billing, payments, and expenses</h3>
        <p>
          This workspace runs on the live fee structure, invoicing, payment, and expense APIs.
        </p>
      </div>

      {state.error ? <div className="banner error-banner">{state.error}</div> : null}
      {state.success ? <div className="banner success-banner">{state.success}</div> : null}

      <div className="stats-grid">
        <article className="stat-card">
          <span className="feature-label">Invoices</span>
          <strong className="stat-value">{invoiceSummary.total}</strong>
          <p className="muted">Outstanding: {invoiceSummary.outstanding}</p>
        </article>
        <article className="stat-card">
          <span className="feature-label">Invoiced Amount</span>
          <strong className="stat-value">{formatMoney(invoiceSummary.amountDue)}</strong>
          <p className="muted">Collected: {formatMoney(invoiceSummary.amountPaid)}</p>
        </article>
        <article className="stat-card">
          <span className="feature-label">Payments</span>
          <strong className="stat-value">{state.payments.length}</strong>
          <p className="muted">Pending: {paymentsSummary.pending}</p>
        </article>
        <article className="stat-card">
          <span className="feature-label">Expenses</span>
          <strong className="stat-value">{state.expenses.length}</strong>
          <p className="muted">Cash in: {formatMoney(paymentsSummary.completedAmount)}</p>
        </article>
      </div>

      <div className="page-actions">
        <label className="inline-field">
          <span>Search</span>
          <input
            value={searchInput}
            onChange={(event) => setSearchInput(event.target.value)}
            placeholder="Invoice, student, payment reference..."
          />
        </label>
        <label className="inline-field">
          <span>Branch</span>
          <select
            value={filters.branchId}
            onChange={(event) =>
              setFilters((previous) => ({
                ...previous,
                branchId: event.target.value,
                invoicePage: 1,
                paymentPage: 1,
              }))
            }
          >
            <option value="">All branches</option>
            {(state.organization?.branches ?? []).map((branch) => (
              <option key={branch.id} value={branch.id}>
                {branch.name}
              </option>
            ))}
          </select>
        </label>
        <label className="inline-field">
          <span>Invoice Status</span>
          <select
            value={filters.invoiceStatus}
            onChange={(event) =>
              setFilters((previous) => ({
                ...previous,
                invoiceStatus: event.target.value,
                invoicePage: 1,
              }))
            }
          >
            <option value="">All invoices</option>
            <option value="PENDING">PENDING</option>
            <option value="PARTIALLY_PAID">PARTIALLY_PAID</option>
            <option value="PAID">PAID</option>
            <option value="OVERDUE">OVERDUE</option>
            <option value="CANCELLED">CANCELLED</option>
          </select>
        </label>
        <label className="inline-field">
          <span>Payment Status</span>
          <select
            value={filters.paymentStatus}
            onChange={(event) =>
              setFilters((previous) => ({
                ...previous,
                paymentStatus: event.target.value,
                paymentPage: 1,
              }))
            }
          >
            <option value="">All payments</option>
            <option value="PENDING">PENDING</option>
            <option value="COMPLETED">COMPLETED</option>
            <option value="FAILED">FAILED</option>
            <option value="VOIDED">VOIDED</option>
            <option value="EXPIRED">EXPIRED</option>
          </select>
        </label>
      </div>

      <div className="data-grid">
        <article className="data-panel">
          <div className="panel-header">
            <div>
              <span className="feature-label">Fee Structure</span>
              <h4>Create pricing template</h4>
            </div>
          </div>

          <form className="form-card compact-form" onSubmit={handleCreateFeeStructure}>
            <label>
              <span>Name</span>
              <input
                value={feeStructureForm.name}
                onChange={(event) => setFeeStructureForm((previous) => ({ ...previous, name: event.target.value }))}
                required
              />
            </label>
            <label>
              <span>Amount</span>
              <input
                value={feeStructureForm.amount}
                onChange={(event) => setFeeStructureForm((previous) => ({ ...previous, amount: event.target.value }))}
                placeholder="50000"
                required
              />
            </label>
            <label>
              <span>Billing Cycle</span>
              <select
                value={feeStructureForm.billingCycle}
                onChange={(event) =>
                  setFeeStructureForm((previous) => ({
                    ...previous,
                    billingCycle: event.target.value as FeeStructureForm["billingCycle"],
                  }))
                }
              >
                <option value="ONE_TIME">ONE_TIME</option>
                <option value="MONTHLY">MONTHLY</option>
                <option value="TERMLY">TERMLY</option>
              </select>
            </label>
            <label>
              <span>Branch</span>
              <select
                value={feeStructureForm.branchId}
                onChange={(event) =>
                  setFeeStructureForm((previous) => ({
                    ...previous,
                    branchId: event.target.value,
                    classId: "",
                  }))
                }
              >
                <option value="">All branches</option>
                {(state.organization?.branches ?? []).map((branch) => (
                  <option key={branch.id} value={branch.id}>
                    {branch.name}
                  </option>
                ))}
              </select>
            </label>
            <label className="full-span">
              <span>Class Scope</span>
              <select
                value={feeStructureForm.classId}
                onChange={(event) => setFeeStructureForm((previous) => ({ ...previous, classId: event.target.value }))}
              >
                <option value="">All classes in branch</option>
                {filteredClassOptions.map((classRecord) => (
                  <option key={classRecord.id} value={classRecord.id}>
                    {classRecord.name} ({classRecord.academicYear})
                  </option>
                ))}
              </select>
            </label>
            <button className="primary-button full-span" type="submit" disabled={state.saving}>
              {state.saving ? "Saving..." : "Create Fee Structure"}
            </button>
          </form>
        </article>

        <article className="data-panel">
          <div className="panel-header">
            <div>
              <span className="feature-label">Invoice</span>
              <h4>Issue student invoice</h4>
            </div>
          </div>

          <form className="form-card compact-form" onSubmit={handleCreateInvoice}>
            <label className="full-span">
              <span>Student</span>
              <select
                value={invoiceForm.studentId}
                onChange={(event) => setInvoiceForm((previous) => ({ ...previous, studentId: event.target.value }))}
              >
                {state.students.map((student) => (
                  <option key={student.id} value={student.id}>
                    {student.fullName} ({student.admissionNo})
                  </option>
                ))}
              </select>
            </label>
            <label>
              <span>Invoice Mode</span>
              <select
                value={invoiceForm.feeMode}
                onChange={(event) =>
                  setInvoiceForm((previous) => ({
                    ...previous,
                    feeMode: event.target.value as InvoiceForm["feeMode"],
                  }))
                }
              >
                <option value="structure">Use fee structure</option>
                <option value="custom">Custom amount</option>
              </select>
            </label>
            <label>
              <span>Due Date</span>
              <input
                type="date"
                value={invoiceForm.dueDate}
                onChange={(event) => setInvoiceForm((previous) => ({ ...previous, dueDate: event.target.value }))}
                required
              />
            </label>

            {invoiceForm.feeMode === "structure" ? (
              <label className="full-span">
                <span>Fee Structure</span>
                <select
                  value={invoiceForm.feeStructureId}
                  onChange={(event) =>
                    setInvoiceForm((previous) => ({ ...previous, feeStructureId: event.target.value }))
                  }
                >
                  {state.feeStructures.map((structure) => (
                    <option key={structure.id} value={structure.id}>
                      {structure.name} ({formatMoney(structure.amount)})
                    </option>
                  ))}
                </select>
              </label>
            ) : (
              <label className="full-span">
                <span>Amount Due</span>
                <input
                  value={invoiceForm.amountDue}
                  onChange={(event) => setInvoiceForm((previous) => ({ ...previous, amountDue: event.target.value }))}
                  placeholder="50000"
                  required
                />
              </label>
            )}

            <div className="detail-card full-span">
              <span className="feature-label">Selected Student</span>
              <h5>{selectedStudent?.fullName ?? "No student selected"}</h5>
              <p className="muted">
                {selectedStudent?.branch.name ?? ""} {selectedStudent?.currentClass ? `• ${selectedStudent.currentClass.name}` : ""}
              </p>
            </div>

            <button className="primary-button full-span" type="submit" disabled={state.saving}>
              {state.saving ? "Saving..." : "Create Invoice"}
            </button>
          </form>
        </article>

        <article className="data-panel">
          <div className="panel-header">
            <div>
              <span className="feature-label">Payment Request</span>
              <h4>Initiate Snippe collection</h4>
            </div>
          </div>

          <form className="form-card compact-form" onSubmit={handleInitiatePayment}>
            <label className="full-span">
              <span>Invoice</span>
              <select
                value={paymentForm.invoiceId}
                onChange={(event) => syncPaymentCustomerFromInvoice(event.target.value)}
              >
                <option value="">Choose invoice</option>
                {state.invoices
                  .filter((invoice) => invoice.status !== "PAID" && invoice.status !== "CANCELLED")
                  .map((invoice) => (
                    <option key={invoice.id} value={invoice.id}>
                      {invoice.invoiceNo} • {invoice.student?.fullName} • {formatMoney(invoice.amountDue)}
                    </option>
                  ))}
              </select>
            </label>
            <label>
              <span>Payer Phone</span>
              <input
                value={paymentForm.payerPhone}
                onChange={(event) => setPaymentForm((previous) => ({ ...previous, payerPhone: event.target.value }))}
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
                    channel: event.target.value as PaymentForm["channel"],
                  }))
                }
              >
                <option value="mpesa">M-Pesa</option>
                <option value="airtel_money">Airtel Money</option>
                <option value="tigo_pesa">Tigo Pesa</option>
              </select>
            </label>
            <label>
              <span>First Name</span>
              <input
                value={paymentForm.firstname}
                onChange={(event) => setPaymentForm((previous) => ({ ...previous, firstname: event.target.value }))}
                required
              />
            </label>
            <label>
              <span>Last Name</span>
              <input
                value={paymentForm.lastname}
                onChange={(event) => setPaymentForm((previous) => ({ ...previous, lastname: event.target.value }))}
                required
              />
            </label>
            <label className="full-span">
              <span>Email</span>
              <input
                type="email"
                value={paymentForm.email}
                onChange={(event) => setPaymentForm((previous) => ({ ...previous, email: event.target.value }))}
              />
            </label>
            <button className="primary-button full-span" type="submit" disabled={state.saving || !paymentForm.invoiceId}>
              {state.saving ? "Submitting..." : "Initiate Payment"}
            </button>
          </form>
        </article>

        <article className="data-panel">
          <div className="panel-header">
            <div>
              <span className="feature-label">Expense</span>
              <h4>Record school spending</h4>
            </div>
          </div>

          <form className="form-card compact-form" onSubmit={handleCreateExpense}>
            <label>
              <span>Title</span>
              <input
                value={expenseForm.title}
                onChange={(event) => setExpenseForm((previous) => ({ ...previous, title: event.target.value }))}
                required
              />
            </label>
            <label>
              <span>Amount</span>
              <input
                value={expenseForm.amount}
                onChange={(event) => setExpenseForm((previous) => ({ ...previous, amount: event.target.value }))}
                placeholder="25000"
                required
              />
            </label>
            <label>
              <span>Expense Date</span>
              <input
                type="date"
                value={expenseForm.expenseDate}
                onChange={(event) => setExpenseForm((previous) => ({ ...previous, expenseDate: event.target.value }))}
                required
              />
            </label>
            <label>
              <span>Branch</span>
              <select
                value={expenseForm.branchId}
                onChange={(event) => setExpenseForm((previous) => ({ ...previous, branchId: event.target.value }))}
              >
                <option value="">No branch scope</option>
                {(state.organization?.branches ?? []).map((branch) => (
                  <option key={branch.id} value={branch.id}>
                    {branch.name}
                  </option>
                ))}
              </select>
            </label>
            <label className="full-span">
              <span>Description</span>
              <textarea
                rows={3}
                value={expenseForm.description}
                onChange={(event) => setExpenseForm((previous) => ({ ...previous, description: event.target.value }))}
              />
            </label>
            <button className="primary-button full-span" type="submit" disabled={state.saving}>
              {state.saving ? "Saving..." : "Record Expense"}
            </button>
          </form>
        </article>

        <article className="data-panel data-panel-wide">
          <div className="panel-header">
            <div>
              <span className="feature-label">Invoices</span>
              <h4>Current billing records</h4>
            </div>
          </div>

          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Invoice</th>
                  <th>Student</th>
                  <th>Fee</th>
                  <th>Due</th>
                  <th>Paid</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {state.invoices.map((invoice) => (
                  <tr key={invoice.id}>
                    <td>{invoice.invoiceNo}</td>
                    <td>{invoice.student?.fullName ?? "--"}</td>
                    <td>{invoice.feeStructure?.name ?? "Custom"}</td>
                    <td>{formatMoney(invoice.amountDue, invoice.currency)}</td>
                    <td>{formatMoney(invoice.amountPaid, invoice.currency)}</td>
                    <td>{invoice.status}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {(state.invoicesMeta?.totalPages ?? 1) > 1 ? (
            <div className="pagination-bar">
              <button
                type="button"
                className="secondary-button"
                onClick={() =>
                  setFilters((previous) => ({
                    ...previous,
                    invoicePage: Math.max(1, previous.invoicePage - 1),
                  }))
                }
                disabled={filters.invoicePage === 1}
              >
                Previous
              </button>
              <span className="pagination-text">
                Page {state.invoicesMeta?.page ?? filters.invoicePage} of {totalInvoicePages}
              </span>
              <button
                type="button"
                className="secondary-button"
                onClick={() =>
                  setFilters((previous) => ({
                    ...previous,
                    invoicePage: Math.min(totalInvoicePages, previous.invoicePage + 1),
                  }))
                }
                disabled={filters.invoicePage === totalInvoicePages}
              >
                Next
              </button>
            </div>
          ) : null}
        </article>

        <article className="data-panel data-panel-wide">
          <div className="panel-header">
            <div>
              <span className="feature-label">Payments</span>
              <h4>Collections lifecycle</h4>
            </div>
          </div>

          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Invoice</th>
                  <th>Student</th>
                  <th>Amount</th>
                  <th>Channel</th>
                  <th>Status</th>
                  <th>Created</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {state.payments.map((payment) => (
                  <tr key={payment.id}>
                    <td>{payment.invoice.invoiceNo}</td>
                    <td>{payment.invoice.student?.fullName ?? "--"}</td>
                    <td>{formatMoney(payment.amount, payment.currency)}</td>
                    <td>{payment.channel ?? "--"}</td>
                    <td>{payment.status}</td>
                    <td>{formatDateTime(payment.createdAt)}</td>
                    <td>
                      <div className="action-row">
                        {payment.status !== "COMPLETED" ? (
                          <button
                            type="button"
                            className="secondary-button"
                            onClick={() => void handleReconcilePayment(payment.id)}
                            disabled={state.saving}
                          >
                            Reconcile
                          </button>
                        ) : null}
                        {payment.status === "COMPLETED" ? (
                          <button
                            type="button"
                            className="secondary-button"
                            onClick={() => void handleLoadReceipt(payment.id)}
                            disabled={state.saving}
                          >
                            Receipt
                          </button>
                        ) : null}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {(state.paymentsMeta?.totalPages ?? 1) > 1 ? (
            <div className="pagination-bar">
              <button
                type="button"
                className="secondary-button"
                onClick={() =>
                  setFilters((previous) => ({
                    ...previous,
                    paymentPage: Math.max(1, previous.paymentPage - 1),
                  }))
                }
                disabled={filters.paymentPage === 1}
              >
                Previous
              </button>
              <span className="pagination-text">
                Page {state.paymentsMeta?.page ?? filters.paymentPage} of {totalPaymentPages}
              </span>
              <button
                type="button"
                className="secondary-button"
                onClick={() =>
                  setFilters((previous) => ({
                    ...previous,
                    paymentPage: Math.min(totalPaymentPages, previous.paymentPage + 1),
                  }))
                }
                disabled={filters.paymentPage === totalPaymentPages}
              >
                Next
              </button>
            </div>
          ) : null}
        </article>

        <article className="data-panel">
          <div className="panel-header">
            <div>
              <span className="feature-label">Expenses</span>
              <h4>Recent spending</h4>
            </div>
          </div>

          <div className="row-list">
            {state.expenses.slice(0, 8).map((expense) => (
              <div key={expense.id} className="row-item stacked-row">
                <div>
                  <strong>{expense.title}</strong>
                  <p className="muted">
                    {expense.branch?.name ?? "General"} • {formatDate(expense.expenseDate)}
                  </p>
                </div>
                <strong>{formatMoney(expense.amount, expense.currency)}</strong>
              </div>
            ))}
          </div>
        </article>

        <article className="data-panel">
          <div className="panel-header">
            <div>
              <span className="feature-label">Receipt Preview</span>
              <h4>Completed payment receipt</h4>
            </div>
          </div>

          {state.selectedReceipt ? (
            <div className="detail-card">
              <span className="feature-label">{state.selectedReceipt.receiptNo}</span>
              <h5>{state.selectedReceipt.student.fullName}</h5>
              <p className="muted">
                {state.selectedReceipt.invoice.invoiceNo} • {state.selectedReceipt.organization.name}
              </p>
              <div className="row-list top-spacing">
                <div className="row-item"><span>Amount</span><strong>{formatMoney(state.selectedReceipt.payment.amount, state.selectedReceipt.payment.currency)}</strong></div>
                <div className="row-item"><span>Paid At</span><strong>{state.selectedReceipt.payment.paidAt ? formatDateTime(state.selectedReceipt.payment.paidAt) : "--"}</strong></div>
                <div className="row-item"><span>Balance</span><strong>{formatMoney(state.selectedReceipt.invoice.balanceRemaining)}</strong></div>
              </div>
            </div>
          ) : (
            <p className="empty-state">Load a completed payment receipt from the payments table.</p>
          )}
        </article>
      </div>
    </section>
  );
};
