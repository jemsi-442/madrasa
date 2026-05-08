const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? "http://127.0.0.1:4000";

type ApiEnvelope<T> = {
  success: boolean;
  message: string;
  data: T;
};

export type PaginatedResult<T> = {
  items: T[];
  meta: {
    page: number;
    pageSize: number;
    totalItems: number;
    totalPages: number;
  };
};

export type UserRole = "ADMIN" | "ACCOUNTANT" | "TEACHER" | "PARENT";

export type AuthUser = {
  id: string;
  fullName: string;
  role: UserRole;
  orgId: string;
  branchId: string | null;
};

export type UserRecord = {
  id: string;
  fullName: string;
  email: string | null;
  phone: string | null;
  role: UserRole;
  status: "ACTIVE" | "DISABLED";
  orgId: string;
  branchId: string | null;
  createdAt: string;
  guardianProfile: {
    id: string;
    fullName: string;
    phone: string;
    email: string | null;
  } | null;
};

export type LoginPayload = {
  login: string;
  password: string;
};

export type LoginResult = {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  user: AuthUser;
};

type AuthSessionManager = {
  getSession: () => LoginResult | null;
  setSession: (session: LoginResult | null) => void;
};

export type DashboardReport = {
  filters: {
    branchId: string | null;
    classId: string | null;
    dateFrom: string | null;
    dateTo: string | null;
  };
  students: {
    total: number;
    active: number;
    inactive: number;
    suspended: number;
    graduated: number;
  };
  attendance: {
    totalRecords: number;
    present: number;
    absent: number;
    late: number;
    excused: number;
    attendanceRate: string;
  };
  hifdh: {
    totalAssessments: number;
    averageMemorizationScore: string;
    averageRevisionScore: string;
  };
  finance: {
    invoices: {
      total: number;
      pending: number;
      paid: number;
      overdue: number;
      amountDue: string;
      amountPaid: string;
      outstandingBalance: string;
    };
    collections: {
      completedPayments: number;
      collectedAmount: string;
    };
    expenses: {
      total: number;
      amount: string;
    };
    netCashFlow: string;
  } | null;
};

export type AttendanceSummaryReport = {
  filters: {
    branchId: string | null;
    classId: string | null;
    dateFrom: string | null;
    dateTo: string | null;
  };
  totals: {
    totalRecords: number;
    present: number;
    absent: number;
    late: number;
    excused: number;
    attendanceRate: string;
  };
  timeline: Array<{
    date: string;
    totalRecords: number;
    present: number;
    absent: number;
    late: number;
    excused: number;
  }>;
};

export type MonthlyFinanceSummaryReport = {
  year: number;
  filters: {
    branchId: string | null;
    classId: string | null;
  };
  totals: {
    invoicesIssued: number;
    invoicedAmount: string;
    paymentsCollected: number;
    collectedAmount: string;
    expensesRecorded: number;
    expenseAmount: string;
    outstandingBalance: string;
    netCashFlow: string;
  };
  months: Array<{
    month: number;
    label: string;
    invoicesIssued: number;
    invoicedAmount: string;
    paymentsCollected: number;
    collectedAmount: string;
    expensesRecorded: number;
    expenseAmount: string;
    outstandingBalance: string;
    netCashFlow: string;
  }>;
};

export type TeacherDashboardReport = {
  teacher: {
    id: string;
    fullName: string;
    branchId: string | null;
  };
  date: string;
  summary: {
    assignedClasses: number;
    assignedStudents: number;
    attendanceMarkedToday: number;
    hifdhAssessmentsThisWeek: number;
  };
  classes: Array<{
    id: string;
    name: string;
    level: string;
    academicYear: string;
    capacity: number;
    branch: {
      id: string;
      name: string;
    };
    stats: {
      currentStudents: number;
      attendanceMarkedToday: number;
      attendancePendingToday: number;
    };
  }>;
  recentHifdh: Array<{
    id: string;
    assessedOn: string;
    juzNumber: number;
    surahName: string;
    memorizationScore: string;
    revisionScore: string;
    student: {
      id: string;
      fullName: string;
      admissionNo: string;
    };
  }>;
};

export type ParentProfile = {
  guardian: {
    id: string;
    fullName: string;
    phone: string;
    email: string | null;
    relationship: string;
    address: string | null;
  };
  students: Array<{
    id: string;
    fullName: string;
    admissionNo: string;
    gender: string;
    status: string;
    joinedOn: string | null;
    isPrimary: boolean;
    branch: {
      id: string;
      name: string;
    };
    currentClass: {
      id: string;
      name: string;
      academicYear: string;
    } | null;
  }>;
};

export type ParentAttendanceRecord = {
  id: string;
  date: string;
  status: string;
  reason: string | null;
  class: {
    id: string;
    name: string;
    academicYear: string;
  };
  markedBy: {
    id: string;
    fullName: string;
    role: string;
  };
};

export type ParentInvoice = {
  id: string;
  invoiceNo: string;
  amountDue: string;
  amountPaid: string;
  balanceRemaining: string;
  currency: string;
  dueDate: string;
  status: string;
  issuedAt: string;
  feeStructure: {
    id: string;
    name: string;
  } | null;
  payments: Array<{
    id: string;
    amount: string;
    currency: string;
    status: string;
    channel: string | null;
    reference: string | null;
    externalReference: string | null;
    paidAt: string | null;
    createdAt: string;
  }>;
};

export type ParentStudentPayment = {
  id: string;
  orgId: string;
  invoiceId: string;
  provider: string;
  reference: string | null;
  externalReference: string | null;
  providerTxnRef: string | null;
  requestId: string | null;
  amount: string;
  currency: string;
  status: "PENDING" | "COMPLETED" | "FAILED" | "VOIDED" | "EXPIRED";
  paymentType: string;
  channel: "mpesa" | "airtel_money" | "tigo_pesa" | null;
  apiVersion: string | null;
  expiresAt: string | null;
  paidAt: string | null;
  createdAt: string;
  invoice: {
    id: string;
    invoiceNo: string;
  };
};

export type ParentPaymentReceipt = {
  receiptNo: string;
  payment: {
    id: string;
    orgId: string;
    invoiceId: string;
    amount: string;
    currency: string;
    status: string;
    channel: string | null;
    reference: string | null;
    externalReference: string | null;
    providerTxnRef: string | null;
    paidAt: string | null;
    createdAt: string;
  };
  organization: {
    id: string;
    name: string;
    code: string;
  };
  branch: {
    id: string;
    name: string;
  } | null;
  student: {
    id: string;
    fullName: string;
    admissionNo: string;
  };
  invoice: {
    id: string;
    invoiceNo: string;
    amountDue: string;
    amountPaid: string;
    balanceRemaining: string;
    dueDate: string;
    status: string;
  };
};

export type HifdhRecord = {
  id: string;
  orgId: string;
  studentId: string;
  teacherId: string;
  juzNumber: number;
  surahName: string;
  ayahFrom: number | null;
  ayahTo: number | null;
  memorizationScore: string;
  revisionScore: string | null;
  remarks: string | null;
  assessedOn: string;
  createdAt: string;
  student: {
    id: string;
    fullName: string;
    admissionNo: string;
  } | null;
  teacher: {
    id: string;
    fullName: string;
    role: string;
  } | null;
};

export type ParentHifdhRecord = {
  id: string;
  studentId: string;
  teacherId: string;
  juzNumber: number;
  surahName: string;
  ayahFrom: number | null;
  ayahTo: number | null;
  memorizationScore: string;
  revisionScore: string | null;
  remarks: string | null;
  assessedOn: string;
  createdAt: string;
  teacher: {
    id: string;
    fullName: string;
    role: string;
  };
};

export type ParentAnnouncement = {
  id: string;
  title: string;
  message: string;
  audience: string;
  publishAt: string;
  expiresAt: string | null;
  branch: {
    id: string;
    name: string;
  } | null;
  createdBy: {
    id: string;
    fullName: string;
    role: string;
  };
};

export type OrganizationProfile = {
  id: string;
  name: string;
  code: string;
  status: string;
  plan: string | null;
  stats: {
    totalUsers: number;
    totalBranches: number;
  };
  branches: Array<{
    id: string;
    name: string;
    isMain: boolean;
  }>;
};

export type Guardian = {
  id: string;
  fullName: string;
  phone: string;
  email: string | null;
  relationship: string | null;
  address: string | null;
  createdAt: string;
};

export type ClassRecord = {
  id: string;
  orgId: string;
  branchId: string;
  name: string;
  level: string;
  academicYear: string;
  teacherId: string | null;
  capacity: number | null;
  createdAt: string;
  branch: {
    id: string;
    name: string;
  } | null;
  teacher: {
    id: string;
    fullName: string;
    email: string | null;
    phone: string | null;
  } | null;
  stats: {
    currentStudents: number;
    enrollments: number;
  } | null;
};

export type EnrollmentRecord = {
  id: string;
  orgId: string;
  studentId: string;
  classId: string;
  academicYear: string;
  status: string;
  createdAt: string;
  student: {
    id: string;
    fullName: string;
    admissionNo: string;
  } | null;
  class: {
    id: string;
    name: string;
    level: string;
    academicYear: string;
  } | null;
};

export type AttendanceRecord = {
  id: string;
  orgId: string;
  branchId: string;
  classId: string;
  studentId: string;
  date: string;
  status: "PRESENT" | "ABSENT" | "LATE" | "EXCUSED";
  reason: string | null;
  markedById: string;
  createdAt: string;
  student: {
    id: string;
    fullName: string;
    admissionNo: string;
  } | null;
  markedBy: {
    id: string;
    fullName: string;
    role: string;
  } | null;
};

export type FeeStructureRecord = {
  id: string;
  orgId: string;
  branchId: string | null;
  classId: string | null;
  name: string;
  amount: string;
  billingCycle: "ONE_TIME" | "MONTHLY" | "TERMLY";
  isActive: boolean;
  createdAt: string;
  branch: {
    id: string;
    name: string;
  } | null;
  class: {
    id: string;
    name: string;
    level: string;
  } | null;
};

export type InvoiceRecord = {
  id: string;
  orgId: string;
  branchId: string;
  studentId: string;
  feeStructureId: string | null;
  invoiceNo: string;
  amountDue: string;
  amountPaid: string;
  currency: string;
  dueDate: string;
  status: "PENDING" | "PARTIALLY_PAID" | "PAID" | "OVERDUE" | "CANCELLED";
  issuedAt: string;
  createdAt: string;
  student: {
    id: string;
    fullName: string;
    admissionNo: string;
  } | null;
  feeStructure: {
    id: string;
    name: string;
  } | null;
};

export type ExpenseRecord = {
  id: string;
  orgId: string;
  branchId: string | null;
  title: string;
  description: string | null;
  amount: string;
  currency: string;
  expenseDate: string;
  createdAt: string;
  recordedById: string | null;
  branch: {
    id: string;
    name: string;
  } | null;
  recordedBy: {
    id: string;
    fullName: string;
    role: string;
  } | null;
};

export type PaymentRecord = {
  id: string;
  orgId: string;
  invoiceId: string;
  provider: string;
  reference: string | null;
  externalReference: string | null;
  providerTxnRef: string | null;
  requestId: string | null;
  amount: string;
  currency: string;
  status: "PENDING" | "COMPLETED" | "FAILED" | "VOIDED" | "EXPIRED";
  paymentType: string;
  channel: "mpesa" | "airtel_money" | "tigo_pesa" | null;
  apiVersion: string | null;
  expiresAt: string | null;
  paidAt: string | null;
  createdAt: string;
  invoice: {
    id: string;
    invoiceNo: string;
    branchId: string;
    student: {
      id: string;
      fullName: string;
      admissionNo: string;
    } | null;
  };
};

export type PaymentReceipt = {
  receiptNo: string;
  payment: {
    id: string;
    orgId: string;
    invoiceId: string;
    amount: string;
    currency: string;
    status: string;
    channel: string | null;
    reference: string | null;
    externalReference: string | null;
    providerTxnRef: string | null;
    paidAt: string | null;
    createdAt: string;
  };
  organization: {
    id: string;
    name: string;
    code: string;
  };
  branch: {
    id: string;
    name: string;
  } | null;
  student: {
    id: string;
    fullName: string;
    admissionNo: string;
  };
  invoice: {
    id: string;
    invoiceNo: string;
    amountDue: string;
    amountPaid: string;
    balanceRemaining: string;
    dueDate: string;
    status: string;
  };
};

export type StudentRecord = {
  id: string;
  admissionNo: string;
  fullName: string;
  gender: string;
  dob: string | null;
  status: string;
  branchId: string;
  classId: string | null;
  joinedOn: string | null;
  leftOn: string | null;
  notes: string | null;
  createdAt: string;
  branch: {
    id: string;
    name: string;
  };
  currentClass: {
    id: string;
    name: string;
    academicYear: string;
  } | null;
  primaryGuardian: Guardian;
  guardians: Array<{
    isPrimary: boolean;
    linkedAt: string;
    guardian: Guardian;
  }>;
};

export type CreateGuardianPayload = {
  fullName: string;
  phone: string;
  email?: string;
  relationship?: string;
  address?: string;
};

export type CreateStudentPayload = {
  admissionNo: string;
  fullName: string;
  gender: "male" | "female";
  dob?: string;
  branchId: string;
  classId?: string;
  joinedOn?: string;
  notes?: string;
  primaryGuardianId?: string;
  guardian?: CreateGuardianPayload;
};

export type UpdateStudentPayload = {
  admissionNo?: string;
  fullName?: string;
  gender?: "male" | "female";
  dob?: string | null;
  branchId?: string;
  classId?: string | null;
  joinedOn?: string | null;
  leftOn?: string | null;
  notes?: string | null;
  status?: "ACTIVE" | "INACTIVE" | "SUSPENDED" | "GRADUATED";
};

type RequestOptions = {
  method?: string;
  body?: unknown;
  token?: string;
};

type CachedReadSnapshot<T> = {
  savedAt: string;
  data: T;
};

let authSessionManager: AuthSessionManager | null = null;
let refreshSessionPromise: Promise<LoginResult> | null = null;
const READ_CACHE_PREFIX = "mif-read-cache:v1";
const CACHEABLE_READ_PATTERNS = [
  /^\/api\/organizations\/me$/,
  /^\/api\/reports\//,
  /^\/api\/classes(?:\/|$)/,
  /^\/api\/enrollments(?:\?|$)/,
  /^\/api\/attendance\/class\//,
  /^\/api\/guardians(?:\?|$)/,
  /^\/api\/students(?:\?|$)/,
  /^\/api\/fee-structures(?:\?|$)/,
  /^\/api\/invoices(?:\?|$)/,
  /^\/api\/payments(?:\?|$)/,
  /^\/api\/expenses(?:\?|$)/,
  /^\/api\/hifdh-progress(?:\?|$)/,
  /^\/api\/parent-portal\//,
];

export const registerAuthSessionManager = (manager: AuthSessionManager | null) => {
  authSessionManager = manager;
};

const toQueryString = (params: Record<string, string | undefined>) => {
  const search = new URLSearchParams();

  Object.entries(params).forEach(([key, value]) => {
    if (value) {
      search.set(key, value);
    }
  });

  const output = search.toString();
  return output ? `?${output}` : "";
};

const buildHeaders = (token?: string, hasBody?: boolean) => {
  const headers = new Headers();

  if (hasBody) {
    headers.set("Content-Type", "application/json");
  }

  if (token) {
    headers.set("Authorization", `Bearer ${token}`);
  }

  return headers;
};

const isCacheableReadPath = (path: string) => CACHEABLE_READ_PATTERNS.some((pattern) => pattern.test(path));

const getReadCacheScope = () => {
  const session = authSessionManager?.getSession();

  if (!session?.user) {
    return "anonymous";
  }

  return `${session.user.orgId}:${session.user.role}:${session.user.id}`;
};

const getReadCacheKey = (path: string) => `${READ_CACHE_PREFIX}:${getReadCacheScope()}:${path}`;

const readCachedSnapshot = <T,>(path: string) => {
  if (typeof window === "undefined") {
    return null;
  }

  try {
    const storedValue = window.localStorage.getItem(getReadCacheKey(path));

    if (!storedValue) {
      return null;
    }

    return JSON.parse(storedValue) as CachedReadSnapshot<T>;
  } catch {
    return null;
  }
};

const writeCachedSnapshot = <T,>(path: string, data: T) => {
  if (typeof window === "undefined") {
    return;
  }

  try {
    const snapshot: CachedReadSnapshot<T> = {
      savedAt: new Date().toISOString(),
      data,
    };

    window.localStorage.setItem(getReadCacheKey(path), JSON.stringify(snapshot));
  } catch {
    // Ignore storage quota and serialization failures; live API data remains the source of truth.
  }
};

const parseDownloadFileName = (contentDisposition: string | null, fallbackFileName: string) => {
  if (!contentDisposition) {
    return fallbackFileName;
  }

  const utf8Match = contentDisposition.match(/filename\*=UTF-8''([^;]+)/i);
  if (utf8Match?.[1]) {
    return decodeURIComponent(utf8Match[1]);
  }

  const plainMatch = contentDisposition.match(/filename="?([^"]+)"?/i);
  if (plainMatch?.[1]) {
    return plainMatch[1];
  }

  return fallbackFileName;
};

const refreshSessionRequest = async (refreshToken: string) =>
  apiRequest<LoginResult>("/api/auth/refresh", {
    method: "POST",
    body: { refreshToken },
  });

const tryRefreshSession = async (expiredToken?: string) => {
  if (!authSessionManager) {
    return null;
  }

  const currentSession = authSessionManager.getSession();

  if (!currentSession?.refreshToken) {
    return null;
  }

  if (expiredToken && currentSession.accessToken !== expiredToken) {
    return currentSession;
  }

  if (!refreshSessionPromise) {
    refreshSessionPromise = refreshSessionRequest(currentSession.refreshToken)
      .then((nextSession) => {
        authSessionManager?.setSession(nextSession);
        return nextSession;
      })
      .catch((error) => {
        authSessionManager?.setSession(null);
        throw error;
      })
      .finally(() => {
        refreshSessionPromise = null;
      });
  }

  return refreshSessionPromise;
};

const apiRequest = async <T>(path: string, options: RequestOptions = {}) => {
  const { method = "GET", body, token } = options;
  const isCacheableRead = method === "GET" && isCacheableReadPath(path);
  const makeRequest = async (requestToken = token) =>
    fetch(`${API_BASE_URL}${path}`, {
      method,
      headers: buildHeaders(requestToken, body !== undefined),
      body: body === undefined ? undefined : JSON.stringify(body),
    });

  let response: Response;

  try {
    response = await makeRequest(token);
  } catch (error) {
    if (isCacheableRead) {
      const cachedSnapshot = readCachedSnapshot<T>(path);

      if (cachedSnapshot) {
        return cachedSnapshot.data;
      }
    }

    if (typeof navigator !== "undefined" && !navigator.onLine) {
      throw new Error("You are offline and this content is not available yet.");
    }

    throw error instanceof Error ? error : new Error("Network request failed.");
  }

  if (response.status === 401 && token) {
    try {
      const refreshedSession = await tryRefreshSession(token);

      if (refreshedSession?.accessToken && refreshedSession.accessToken !== token) {
        response = await makeRequest(refreshedSession.accessToken);
      }
    } catch {
      throw new Error("Your session has expired. Please sign in again.");
    }
  }

  const contentType = response.headers.get("content-type") ?? "";
  const payload = contentType.includes("application/json")
    ? ((await response.json()) as ApiEnvelope<T> & { error?: string })
    : null;

  if (!response.ok) {
    throw new Error(payload?.message ?? payload?.error ?? `Request failed with status ${response.status}`);
  }

  if (!payload) {
    throw new Error("The API returned an unexpected response.");
  }

  if (isCacheableRead) {
    writeCachedSnapshot(path, payload.data);
  }

  return payload.data;
};

const downloadRequest = async (path: string, token: string, fallbackFileName: string) => {
  const makeRequest = async (requestToken: string) =>
    fetch(`${API_BASE_URL}${path}`, {
      method: "GET",
      headers: buildHeaders(requestToken),
    });

  let response = await makeRequest(token);

  if (response.status === 401) {
    try {
      const refreshedSession = await tryRefreshSession(token);

      if (refreshedSession?.accessToken && refreshedSession.accessToken !== token) {
        response = await makeRequest(refreshedSession.accessToken);
      }
    } catch {
      throw new Error("Your session has expired. Please sign in again.");
    }
  }

  if (!response.ok) {
    const contentType = response.headers.get("content-type") ?? "";
    const payload = contentType.includes("application/json")
      ? ((await response.json()) as { message?: string; error?: string })
      : null;

    throw new Error(payload?.message ?? payload?.error ?? `Request failed with status ${response.status}`);
  }

  const blob = await response.blob();
  const fileName = parseDownloadFileName(response.headers.get("content-disposition"), fallbackFileName);
  const objectUrl = window.URL.createObjectURL(blob);
  const link = document.createElement("a");

  link.href = objectUrl;
  link.download = fileName;
  document.body.appendChild(link);
  link.click();
  link.remove();
  window.URL.revokeObjectURL(objectUrl);

  return { fileName };
};

export const login = (payload: LoginPayload) =>
  apiRequest<LoginResult>("/api/auth/login", {
    method: "POST",
    body: payload,
  });

export const refreshSession = (refreshToken: string) => refreshSessionRequest(refreshToken);

export const logout = (refreshToken: string) =>
  apiRequest<void>("/api/auth/logout", {
    method: "POST",
    body: { refreshToken },
  });

export const getCurrentUser = (token: string) =>
  apiRequest<{
    userId: string;
    orgId: string;
    role: UserRole;
    branchId?: string | null;
  }>("/api/auth/me", { token });

export const getOrganizationProfile = (token: string) =>
  apiRequest<OrganizationProfile>("/api/organizations/me", { token });

export const getDashboardReport = (token: string) =>
  apiRequest<DashboardReport>("/api/reports/dashboard", { token });

export const getAttendanceSummaryReport = (token: string) =>
  apiRequest<AttendanceSummaryReport>("/api/reports/attendance/summary", { token });

export const getMonthlyFinanceSummaryReport = (token: string, year?: number) =>
  apiRequest<MonthlyFinanceSummaryReport>(
    `/api/reports/finance/monthly-summary${year ? `?year=${year}` : ""}`,
    { token },
  );

export const getTeacherDashboardReport = (token: string, teacherId?: string) =>
  apiRequest<TeacherDashboardReport>(`/api/reports/teacher-dashboard${toQueryString({ teacherId })}`, { token });

export const exportStudentsReport = (
  token: string,
  query: {
    branchId?: string;
    classId?: string;
    status?: "ACTIVE" | "INACTIVE" | "SUSPENDED" | "GRADUATED";
  } = {},
) =>
  downloadRequest(
    `/api/reports/students/export${toQueryString(query)}`,
    token,
    "students-report.csv",
  );

export const exportPaymentsReport = (
  token: string,
  query: {
    branchId?: string;
    classId?: string;
    status?: "PENDING" | "COMPLETED" | "FAILED" | "VOIDED" | "EXPIRED";
    dateFrom?: string;
    dateTo?: string;
  } = {},
) =>
  downloadRequest(
    `/api/reports/payments/export${toQueryString(query)}`,
    token,
    "payments-report.csv",
  );

export const exportAttendanceReport = (
  token: string,
  query: {
    branchId?: string;
    classId?: string;
    status?: "PRESENT" | "ABSENT" | "LATE" | "EXCUSED";
    dateFrom?: string;
    dateTo?: string;
  } = {},
) =>
  downloadRequest(
    `/api/reports/attendance/export${toQueryString(query)}`,
    token,
    "attendance-report.csv",
  );

export const exportMonthlyFinanceSummaryReport = (
  token: string,
  query: {
    branchId?: string;
    classId?: string;
    year?: number;
  } = {},
) =>
  downloadRequest(
    `/api/reports/finance/monthly-summary/export${toQueryString(
      Object.fromEntries(
        Object.entries(query).map(([key, value]) => [key, value === undefined ? undefined : String(value)]),
      ),
    )}`,
    token,
    "finance-monthly-summary.csv",
  );

export const getParentProfile = (token: string, parentUserId?: string) =>
  apiRequest<ParentProfile>(`/api/parent-portal/me${toQueryString({ parentUserId })}`, { token });

export const getParentAnnouncements = (token: string, parentUserId?: string) =>
  apiRequest<ParentAnnouncement[]>(`/api/parent-portal/announcements${toQueryString({ parentUserId })}`, { token });

export const getParentStudentAttendance = (token: string, studentId: string, parentUserId?: string) =>
  apiRequest<ParentAttendanceRecord[]>(
    `/api/parent-portal/students/${studentId}/attendance${toQueryString({ parentUserId })}`,
    { token },
  );

export const getParentStudentFinance = (token: string, studentId: string, parentUserId?: string) =>
  apiRequest<ParentInvoice[]>(
    `/api/parent-portal/students/${studentId}/finance${toQueryString({ parentUserId })}`,
    { token },
  );

export const getParentStudentHifdh = (token: string, studentId: string, parentUserId?: string) =>
  apiRequest<ParentHifdhRecord[]>(
    `/api/parent-portal/students/${studentId}/hifdh${toQueryString({ parentUserId })}`,
    { token },
  );

export const initiateParentStudentPayment = (
  token: string,
  studentId: string,
  payload: {
    invoiceId: string;
    payerPhone: string;
    channel: "mpesa" | "airtel_money" | "tigo_pesa";
  },
  parentUserId?: string,
) =>
  apiRequest<ParentStudentPayment>(`/api/parent-portal/students/${studentId}/payments${toQueryString({ parentUserId })}`, {
    method: "POST",
    body: payload,
    token,
  });

export const getParentStudentPayment = (token: string, studentId: string, paymentId: string, parentUserId?: string) =>
  apiRequest<ParentStudentPayment>(
    `/api/parent-portal/students/${studentId}/payments/${paymentId}${toQueryString({ parentUserId })}`,
    { token },
  );

export const getParentStudentPaymentReceipt = (
  token: string,
  studentId: string,
  paymentId: string,
  parentUserId?: string,
) =>
  apiRequest<ParentPaymentReceipt>(
    `/api/parent-portal/students/${studentId}/payments/${paymentId}/receipt${toQueryString({ parentUserId })}`,
    { token },
  );

export const listUsers = (
  token: string,
  query: {
    role?: UserRole;
    status?: "ACTIVE" | "DISABLED";
  } = {},
) => apiRequest<UserRecord[]>(`/api/users${toQueryString(query)}`, { token });

export const listGuardians = (token: string) =>
  apiRequest<Guardian[]>("/api/guardians", { token });

export const createGuardian = (token: string, payload: CreateGuardianPayload) =>
  apiRequest<Guardian>("/api/guardians", {
    method: "POST",
    body: payload,
    token,
  });

export const listClasses = (token: string) =>
  apiRequest<ClassRecord[]>("/api/classes", { token });

export const getClassById = (token: string, classId: string) =>
  apiRequest<ClassRecord>(`/api/classes/${classId}`, { token });

export const listEnrollments = (
  token: string,
  query: { classId?: string; status?: string; academicYear?: string } = {},
) =>
  apiRequest<EnrollmentRecord[]>(`/api/enrollments${toQueryString(query)}`, { token });

export const getClassAttendance = (token: string, classId: string, date?: string) =>
  apiRequest<AttendanceRecord[]>(
    `/api/attendance/class/${classId}${toQueryString({ date })}`,
    { token },
  );

export const bulkMarkAttendance = (
  token: string,
  payload: {
    classId: string;
    date: string;
    records: Array<{
      studentId: string;
      status: "PRESENT" | "ABSENT" | "LATE" | "EXCUSED";
      reason?: string;
    }>;
  },
) =>
  apiRequest<AttendanceRecord[]>("/api/attendance/bulk-mark", {
    method: "POST",
    body: payload,
    token,
  });

export const listHifdhProgress = (
  token: string,
  query: { studentId?: string; teacherId?: string; juzNumber?: string; dateFrom?: string; dateTo?: string } = {},
) =>
  apiRequest<HifdhRecord[]>(`/api/hifdh-progress${toQueryString(query)}`, { token });

export const createHifdhProgress = (
  token: string,
  payload: {
    studentId: string;
    teacherId?: string;
    juzNumber: number;
    surahName: string;
    ayahFrom?: number;
    ayahTo?: number;
    memorizationScore: string;
    revisionScore?: string;
    remarks?: string;
    assessedOn: string;
  },
) =>
  apiRequest<HifdhRecord>("/api/hifdh-progress", {
    method: "POST",
    body: payload,
    token,
  });

export const listStudents = (
  token: string,
  query: {
    branchId?: string;
    classId?: string;
    status?: string;
    search?: string;
    sortBy?: "createdAt" | "fullName" | "admissionNo" | "joinedOn";
    sortDir?: "asc" | "desc";
    page?: string;
    pageSize?: string;
  } = {},
) =>
  apiRequest<PaginatedResult<StudentRecord>>(`/api/students${toQueryString(query)}`, { token });

export const listFeeStructures = (
  token: string,
  query: {
    branchId?: string;
    classId?: string;
    isActive?: "true" | "false";
    search?: string;
    page?: string;
    pageSize?: string;
  } = {},
) =>
  apiRequest<PaginatedResult<FeeStructureRecord>>(`/api/fee-structures${toQueryString(query)}`, { token });

export const createFeeStructure = (
  token: string,
  payload: {
    name: string;
    amount: string;
    billingCycle: "ONE_TIME" | "MONTHLY" | "TERMLY";
    branchId?: string;
    classId?: string;
    isActive?: boolean;
  },
) =>
  apiRequest<FeeStructureRecord>("/api/fee-structures", {
    method: "POST",
    body: payload,
    token,
  });

export const listInvoices = (
  token: string,
  query: {
    studentId?: string;
    branchId?: string;
    status?: string;
    search?: string;
    sortBy?: "createdAt" | "dueDate" | "amountDue" | "invoiceNo";
    sortDir?: "asc" | "desc";
    page?: string;
    pageSize?: string;
  } = {},
) =>
  apiRequest<PaginatedResult<InvoiceRecord>>(`/api/invoices${toQueryString(query)}`, { token });

export const createInvoice = (
  token: string,
  payload: {
    studentId: string;
    feeStructureId?: string;
    amountDue?: string;
    dueDate: string;
    currency?: "TZS";
  },
) =>
  apiRequest<InvoiceRecord>("/api/invoices", {
    method: "POST",
    body: payload,
    token,
  });

export const listExpenses = (
  token: string,
  query: {
    branchId?: string;
    search?: string;
    dateFrom?: string;
    dateTo?: string;
    page?: string;
    pageSize?: string;
  } = {},
) =>
  apiRequest<PaginatedResult<ExpenseRecord>>(`/api/expenses${toQueryString(query)}`, { token });

export const createExpense = (
  token: string,
  payload: {
    title: string;
    description?: string;
    amount: string;
    expenseDate: string;
    branchId?: string;
    currency?: "TZS";
  },
) =>
  apiRequest<ExpenseRecord>("/api/expenses", {
    method: "POST",
    body: payload,
    token,
  });

export const listPayments = (
  token: string,
  query: {
    invoiceId?: string;
    studentId?: string;
    branchId?: string;
    status?: string;
    channel?: string;
    dateFrom?: string;
    dateTo?: string;
    search?: string;
    sortBy?: "createdAt" | "amount" | "status" | "paidAt";
    sortDir?: "asc" | "desc";
    page?: string;
    pageSize?: string;
  } = {},
) =>
  apiRequest<PaginatedResult<PaymentRecord>>(`/api/payments${toQueryString(query)}`, { token });

export const initiatePayment = (
  token: string,
  payload: {
    invoiceId: string;
    payerPhone: string;
    channel: "mpesa" | "airtel_money" | "tigo_pesa";
    customer: {
      firstname: string;
      lastname: string;
      email?: string;
    };
  },
) =>
  apiRequest<PaymentRecord>("/api/payments", {
    method: "POST",
    body: payload,
    token,
  });

export const reconcilePayment = (token: string, paymentId: string) =>
  apiRequest<PaymentRecord>(`/api/payments/${paymentId}/reconcile`, {
    method: "POST",
    token,
  });

export const getPaymentReceipt = (token: string, paymentId: string) =>
  apiRequest<PaymentReceipt>(`/api/payments/${paymentId}/receipt`, { token });

export const getStudentById = (token: string, studentId: string) =>
  apiRequest<StudentRecord>(`/api/students/${studentId}`, { token });

export const createStudent = (token: string, payload: CreateStudentPayload) =>
  apiRequest<StudentRecord>("/api/students", {
    method: "POST",
    body: payload,
    token,
  });

export const updateStudent = (token: string, studentId: string, payload: UpdateStudentPayload) =>
  apiRequest<StudentRecord>(`/api/students/${studentId}`, {
    method: "PATCH",
    body: payload,
    token,
  });

export const linkGuardianToStudent = (
  token: string,
  studentId: string,
  payload: { guardianId: string; isPrimary?: boolean },
) =>
  apiRequest<StudentRecord>(`/api/students/${studentId}/guardians`, {
    method: "POST",
    body: payload,
    token,
  });

export const setPrimaryGuardian = (token: string, studentId: string, guardianId: string) =>
  apiRequest<StudentRecord>(`/api/students/${studentId}/primary-guardian`, {
    method: "PATCH",
    body: { guardianId },
    token,
  });

export const unlinkGuardianFromStudent = (token: string, studentId: string, guardianId: string) =>
  apiRequest<StudentRecord>(`/api/students/${studentId}/guardians/${guardianId}`, {
    method: "DELETE",
    token,
  });

export const getApiBaseUrl = () => API_BASE_URL;
