import { useEffect, useMemo, useState, type FormEvent } from "react";
import { Link, Navigate, useSearchParams } from "react-router-dom";

import {
  createGuardian,
  createStudent,
  getOrganizationProfile,
  linkGuardianToStudent,
  listClasses,
  listGuardians,
  listStudents,
  setPrimaryGuardian,
  unlinkGuardianFromStudent,
  updateStudent,
  type ClassRecord,
  type CreateGuardianPayload,
  type CreateStudentPayload,
  type Guardian,
  type OrganizationProfile,
  type StudentRecord,
} from "../lib/api";
import { InlineEmptyState, LoadingRowList, LoadingStatsGrid } from "../components/ui-states";
import { useAuth } from "../lib/auth";
import { formatDate } from "../lib/format";
import { useNotifyOnMessage } from "../lib/notifications";
import { usePwa } from "../lib/pwa";

type RegistryState = {
  organization: OrganizationProfile | null;
  classes: ClassRecord[];
  guardians: Guardian[];
  students: StudentRecord[];
  studentsMeta: {
    page: number;
    pageSize: number;
    totalItems: number;
    totalPages: number;
  } | null;
  selectedStudentId: string;
  loading: boolean;
  saving: boolean;
  error: string | null;
  success: string | null;
};

type StudentFilters = {
  search: string;
  branchId: string;
  classId: string;
  status: "" | "ACTIVE" | "INACTIVE" | "SUSPENDED" | "GRADUATED";
  sortBy: "createdAt" | "fullName" | "admissionNo" | "joinedOn";
  sortDir: "asc" | "desc";
  page: number;
};

const defaultStudentFilters: StudentFilters = {
  search: "",
  branchId: "",
  classId: "",
  status: "",
  sortBy: "createdAt",
  sortDir: "desc",
  page: 1,
};

type GuardianFormState = {
  fullName: string;
  phone: string;
  email: string;
  relationship: string;
  address: string;
};

type StudentFormState = {
  admissionNo: string;
  fullName: string;
  gender: "male" | "female";
  dob: string;
  branchId: string;
  classId: string;
  joinedOn: string;
  notes: string;
  guardianMode: "existing" | "new";
  primaryGuardianId: string;
  guardian: GuardianFormState;
};

type EditStudentFormState = {
  admissionNo: string;
  fullName: string;
  gender: "male" | "female";
  dob: string;
  branchId: string;
  classId: string;
  joinedOn: string;
  leftOn: string;
  notes: string;
  status: "ACTIVE" | "INACTIVE" | "SUSPENDED" | "GRADUATED";
};

const emptyGuardianForm = (): GuardianFormState => ({
  fullName: "",
  phone: "",
  email: "",
  relationship: "Parent",
  address: "",
});

const toCreateGuardianPayload = (form: GuardianFormState): CreateGuardianPayload => ({
  fullName: form.fullName.trim(),
  phone: form.phone.trim(),
  email: form.email.trim() || undefined,
  relationship: form.relationship.trim() || undefined,
  address: form.address.trim() || undefined,
});

const buildStudentForm = (branches: OrganizationProfile["branches"], guardians: Guardian[]): StudentFormState => ({
  admissionNo: "",
  fullName: "",
  gender: "male",
  dob: "",
  branchId: branches[0]?.id ?? "",
  classId: "",
  joinedOn: new Date().toISOString().slice(0, 10),
  notes: "",
  guardianMode: guardians.length ? "existing" : "new",
  primaryGuardianId: guardians[0]?.id ?? "",
  guardian: emptyGuardianForm(),
});

const buildEditStudentForm = (student: StudentRecord): EditStudentFormState => ({
  admissionNo: student.admissionNo,
  fullName: student.fullName,
  gender: student.gender === "female" ? "female" : "male",
  dob: student.dob ?? "",
  branchId: student.branchId,
  classId: student.classId ?? "",
  joinedOn: student.joinedOn ?? "",
  leftOn: student.leftOn ?? "",
  notes: student.notes ?? "",
  status: student.status as EditStudentFormState["status"],
});

const parsePositivePage = (value: string | null, fallback = 1) => {
  const parsed = Number(value);

  if (!Number.isInteger(parsed) || parsed < 1) {
    return fallback;
  }

  return parsed;
};

export const StudentRegistryPage = () => {
  const { session } = useAuth();
  const { isOnline } = usePwa();
  const [searchParams, setSearchParams] = useSearchParams();
  const initialFilters: StudentFilters = {
    search: searchParams.get("search") ?? defaultStudentFilters.search,
    branchId: searchParams.get("branchId") ?? defaultStudentFilters.branchId,
    classId: searchParams.get("classId") ?? defaultStudentFilters.classId,
    status: (searchParams.get("status") as StudentFilters["status"]) ?? defaultStudentFilters.status,
    sortBy: (searchParams.get("sortBy") as StudentFilters["sortBy"]) ?? defaultStudentFilters.sortBy,
    sortDir: (searchParams.get("sortDir") as StudentFilters["sortDir"]) ?? defaultStudentFilters.sortDir,
    page: parsePositivePage(searchParams.get("page")),
  };
  const [state, setState] = useState<RegistryState>({
    organization: null,
    classes: [],
    guardians: [],
    students: [],
    studentsMeta: null,
    selectedStudentId: "",
    loading: true,
    saving: false,
    error: null,
    success: null,
  });
  const [guardianForm, setGuardianForm] = useState<GuardianFormState>(emptyGuardianForm);
  const [studentForm, setStudentForm] = useState<StudentFormState>(buildStudentForm([], []));
  const [editStudentForm, setEditStudentForm] = useState<EditStudentFormState | null>(null);
  const [linkGuardianId, setLinkGuardianId] = useState("");
  const [filters, setFilters] = useState<StudentFilters>(initialFilters);
  const [searchInput, setSearchInput] = useState(initialFilters.search);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setFilters((previous) =>
        previous.search === searchInput
          ? previous
          : {
              ...previous,
              search: searchInput,
              page: 1,
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

    if (filters.classId) {
      nextParams.set("classId", filters.classId);
    }

    if (filters.status) {
      nextParams.set("status", filters.status);
    }

    if (filters.sortBy !== "createdAt") {
      nextParams.set("sortBy", filters.sortBy);
    }

    if (filters.sortDir !== "desc") {
      nextParams.set("sortDir", filters.sortDir);
    }

    if (filters.page > 1) {
      nextParams.set("page", String(filters.page));
    }

    setSearchParams(nextParams, { replace: true });
  }, [filters, setSearchParams]);

  useEffect(() => {
    if (!session || session.user.role !== "ADMIN") {
      return;
    }

    let cancelled = false;

    const load = async () => {
      setState((previous) => ({ ...previous, loading: true, error: null }));

      try {
        const [organization, classes, guardians, studentsResponse] = await Promise.all([
          getOrganizationProfile(session.accessToken),
          listClasses(session.accessToken),
          listGuardians(session.accessToken),
          listStudents(session.accessToken, {
            branchId: filters.branchId || undefined,
            classId: filters.classId || undefined,
            status: filters.status || undefined,
            search: filters.search.trim() || undefined,
            sortBy: filters.sortBy,
            sortDir: filters.sortDir,
            page: String(filters.page),
            pageSize: "8",
          }),
        ]);

        if (cancelled) {
          return;
        }

        const students = studentsResponse.items;
        const selectedStudentId =
          students.find((student) => student.id === state.selectedStudentId)?.id ?? students[0]?.id ?? "";
        setState({
          organization,
          classes,
          guardians,
          students,
          studentsMeta: studentsResponse.meta,
          selectedStudentId,
          loading: false,
          saving: false,
          error: null,
          success: null,
        });
        setStudentForm(buildStudentForm(organization.branches, guardians));
        setEditStudentForm(
          (students.find((student) => student.id === selectedStudentId) ?? students[0])
            ? buildEditStudentForm((students.find((student) => student.id === selectedStudentId) ?? students[0])!)
            : null,
        );
        setLinkGuardianId(
          guardians.find(
            (guardian) =>
              !(students.find((student) => student.id === selectedStudentId) ?? students[0])?.guardians.some(
                (link) => link.guardian.id === guardian.id,
              ),
          )?.id ?? "",
        );
      } catch (error) {
        if (cancelled) {
          return;
        }

        setState((previous) => ({
          ...previous,
          loading: false,
          error: error instanceof Error ? error.message : "Failed to load student registry.",
        }));
      }
    };

    void load();

    return () => {
      cancelled = true;
    };
  }, [
    filters.branchId,
    filters.classId,
    filters.page,
    filters.search,
    filters.sortBy,
    filters.sortDir,
    filters.status,
    session,
  ]);

  const selectedStudent = useMemo(
    () => state.students.find((student) => student.id === state.selectedStudentId) ?? null,
    [state.selectedStudentId, state.students],
  );

  useEffect(() => {
    if (!selectedStudent) {
      setEditStudentForm(null);
      setLinkGuardianId("");
      return;
    }

    setEditStudentForm(buildEditStudentForm(selectedStudent));
    setLinkGuardianId(
      state.guardians.find(
        (guardian) => !selectedStudent.guardians.some((link) => link.guardian.id === guardian.id),
      )?.id ?? "",
    );
  }, [selectedStudent, state.guardians]);

  const classOptions = useMemo(
    () => state.classes.filter((classRecord) => classRecord.branchId === studentForm.branchId),
    [state.classes, studentForm.branchId],
  );

  const editClassOptions = useMemo(
    () => state.classes.filter((classRecord) => classRecord.branchId === editStudentForm?.branchId),
    [state.classes, editStudentForm?.branchId],
  );
  const totalPages = state.studentsMeta?.totalPages ?? 1;
  const activeFilterCount = [filters.search, filters.branchId, filters.classId, filters.status].filter(Boolean).length;

  useNotifyOnMessage(state.error, state.success);

  const withSaving = async (work: () => Promise<void>) => {
    setState((previous) => ({ ...previous, saving: true, error: null, success: null }));

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

    setState((previous) => ({ ...previous, saving: false }));
  };

  const handleGuardianCreate = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (!session) {
      return;
    }

    await withSaving(async () => {
      const createdGuardian = await createGuardian(session.accessToken, toCreateGuardianPayload(guardianForm));

      setState((previous) => ({
        ...previous,
        guardians: [createdGuardian, ...previous.guardians],
        success: "Guardian created successfully.",
      }));
      setGuardianForm(emptyGuardianForm());
      setStudentForm((previous) => ({
        ...previous,
        guardianMode: "existing",
        primaryGuardianId: createdGuardian.id,
      }));
      setLinkGuardianId((previous) => previous || createdGuardian.id);
    });
  };

  const handleStudentCreate = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (!session || !state.organization) {
      return;
    }

    const payload: CreateStudentPayload = {
      admissionNo: studentForm.admissionNo.trim(),
      fullName: studentForm.fullName.trim(),
      gender: studentForm.gender,
      branchId: studentForm.branchId,
      classId: studentForm.classId || undefined,
      dob: studentForm.dob || undefined,
      joinedOn: studentForm.joinedOn || undefined,
      notes: studentForm.notes.trim() || undefined,
    };

    if (studentForm.guardianMode === "existing") {
      payload.primaryGuardianId = studentForm.primaryGuardianId;
    } else {
      payload.guardian = toCreateGuardianPayload(studentForm.guardian);
    }

    await withSaving(async () => {
      const student = await createStudent(session.accessToken, payload);

      setState((previous) => ({
        ...previous,
        students: [student, ...previous.students],
        selectedStudentId: student.id,
        success: "Student created successfully.",
      }));
      setStudentForm(buildStudentForm(state.organization!.branches, state.guardians));
    });
  };

  const handleStudentUpdate = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (!session || !selectedStudent || !editStudentForm) {
      return;
    }

    await withSaving(async () => {
      const updatedStudent = await updateStudent(session.accessToken, selectedStudent.id, {
        admissionNo: editStudentForm.admissionNo.trim(),
        fullName: editStudentForm.fullName.trim(),
        gender: editStudentForm.gender,
        branchId: editStudentForm.branchId,
        classId: editStudentForm.classId || null,
        dob: editStudentForm.dob || null,
        joinedOn: editStudentForm.joinedOn || null,
        leftOn: editStudentForm.leftOn || null,
        notes: editStudentForm.notes.trim() || null,
        status: editStudentForm.status,
      });

      setState((previous) => ({
        ...previous,
        students: previous.students.map((student) =>
          student.id === updatedStudent.id ? updatedStudent : student,
        ),
        success: "Student updated successfully.",
      }));
    });
  };

  const handleLinkGuardian = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();

    if (!session || !selectedStudent || !linkGuardianId) {
      return;
    }

    await withSaving(async () => {
      const updatedStudent = await linkGuardianToStudent(session.accessToken, selectedStudent.id, {
        guardianId: linkGuardianId,
      });

      setState((previous) => ({
        ...previous,
        students: previous.students.map((student) =>
          student.id === updatedStudent.id ? updatedStudent : student,
        ),
        success: "Guardian linked to student successfully.",
      }));
    });
  };

  const handleSetPrimaryGuardian = async (guardianId: string) => {
    if (!session || !selectedStudent) {
      return;
    }

    await withSaving(async () => {
      const updatedStudent = await setPrimaryGuardian(session.accessToken, selectedStudent.id, guardianId);

      setState((previous) => ({
        ...previous,
        students: previous.students.map((student) =>
          student.id === updatedStudent.id ? updatedStudent : student,
        ),
        success: "Primary guardian updated successfully.",
      }));
    });
  };

  const handleUnlinkGuardian = async (guardianId: string) => {
    if (!session || !selectedStudent) {
      return;
    }

    await withSaving(async () => {
      const updatedStudent = await unlinkGuardianFromStudent(session.accessToken, selectedStudent.id, guardianId);

      setState((previous) => ({
        ...previous,
        students: previous.students.map((student) =>
          student.id === updatedStudent.id ? updatedStudent : student,
        ),
        success: "Guardian removed from student successfully.",
      }));
    });
  };

  if (!session) {
    return null;
  }

  if (session.user.role !== "ADMIN") {
    return <Navigate to={session.user.role === "PARENT" ? "/parent" : session.user.role === "TEACHER" ? "/teacher" : "/dashboard"} replace />;
  }

  return (
    <section className="page-card">
      <div className="page-heading">
        <p className="eyebrow">Admissions</p>
        <h3>Student records and guardian links</h3>
        <p>Manage student intake, guardian relationships, and branch or class assignment records.</p>
      </div>

      {state.error ? <div className="banner error-banner">{state.error}</div> : null}
      {state.success ? <div className="banner success-banner">{state.success}</div> : null}

      {state.loading ? (
        <LoadingStatsGrid />
      ) : (
        <div className="stats-grid">
          <article className="stat-card">
            <span className="feature-label">Students</span>
            <strong className="stat-value">{state.students.length}</strong>
            <p className="muted">Registered in this organization</p>
          </article>
          <article className="stat-card">
            <span className="feature-label">Guardians</span>
            <strong className="stat-value">{state.guardians.length}</strong>
            <p className="muted">Available for linking</p>
          </article>
          <article className="stat-card">
            <span className="feature-label">Branches</span>
            <strong className="stat-value">{state.organization?.branches.length ?? "--"}</strong>
            <p className="muted">{state.organization?.name ?? "Organization"}</p>
          </article>
          <article className="stat-card">
            <span className="feature-label">Classes</span>
            <strong className="stat-value">{state.classes.length}</strong>
            <p className="muted">Ready for assignment</p>
          </article>
        </div>
      )}

      <div className="page-actions filters-grid">
        <label className="inline-field">
          <span>Search</span>
          <input
            value={searchInput}
            onChange={(event) => setSearchInput(event.target.value)}
            placeholder="Student, admission, guardian..."
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
                classId: "",
                page: 1,
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
          <span>Class</span>
          <select
            value={filters.classId}
            onChange={(event) =>
              setFilters((previous) => ({ ...previous, classId: event.target.value, page: 1 }))
            }
          >
            <option value="">All classes</option>
            {state.classes
              .filter((classRecord) => !filters.branchId || classRecord.branchId === filters.branchId)
              .map((classRecord) => (
                <option key={classRecord.id} value={classRecord.id}>
                  {classRecord.name} ({classRecord.academicYear})
                </option>
              ))}
          </select>
        </label>
        <label className="inline-field">
          <span>Status</span>
          <select
            value={filters.status}
            onChange={(event) =>
              setFilters((previous) => ({
                ...previous,
                status: event.target.value as StudentFilters["status"],
                page: 1,
              }))
            }
          >
            <option value="">All statuses</option>
            <option value="ACTIVE">ACTIVE</option>
            <option value="INACTIVE">INACTIVE</option>
            <option value="SUSPENDED">SUSPENDED</option>
            <option value="GRADUATED">GRADUATED</option>
          </select>
        </label>
        <label className="inline-field">
          <span>Sort By</span>
          <select
            value={filters.sortBy}
            onChange={(event) =>
              setFilters((previous) => ({
                ...previous,
                sortBy: event.target.value as StudentFilters["sortBy"],
                page: 1,
              }))
            }
          >
            <option value="createdAt">Recently Added</option>
            <option value="fullName">Student Name</option>
            <option value="admissionNo">Admission No</option>
            <option value="joinedOn">Join Date</option>
          </select>
        </label>
        <label className="inline-field">
          <span>Direction</span>
          <select
            value={filters.sortDir}
            onChange={(event) =>
              setFilters((previous) => ({
                ...previous,
                sortDir: event.target.value as StudentFilters["sortDir"],
                page: 1,
              }))
            }
          >
            <option value="desc">Descending</option>
            <option value="asc">Ascending</option>
          </select>
        </label>
        <div className="action-row full-span workspace-inline-tools">
          <span className="filter-summary">
            {state.studentsMeta?.totalItems ?? state.students.length} students
            {activeFilterCount ? ` • ${activeFilterCount} active filters` : " • all records"}
          </span>
          <button
            type="button"
            className="secondary-button"
            onClick={() => {
              setSearchInput("");
              setFilters(defaultStudentFilters);
            }}
          >
            Reset Filters
          </button>
        </div>
      </div>

      <div className="data-grid workspace-data-grid">
        <article className="data-panel">
          <div className="panel-header">
            <div className="panel-copy">
              <span className="feature-label">Create Guardian</span>
              <h4>Household contact</h4>
              <p className="panel-note">Create a reusable contact profile before linking students.</p>
            </div>
          </div>

          <form className="form-card compact-form" onSubmit={handleGuardianCreate}>
            <label>
              <span>Full Name</span>
              <input
                value={guardianForm.fullName}
                onChange={(event) =>
                  setGuardianForm((previous) => ({ ...previous, fullName: event.target.value }))
                }
                required
              />
            </label>
            <label>
              <span>Phone</span>
              <input
                value={guardianForm.phone}
                onChange={(event) =>
                  setGuardianForm((previous) => ({ ...previous, phone: event.target.value }))
                }
                required
              />
            </label>
            <label>
              <span>Email</span>
              <input
                type="email"
                value={guardianForm.email}
                onChange={(event) =>
                  setGuardianForm((previous) => ({ ...previous, email: event.target.value }))
                }
              />
            </label>
            <label>
              <span>Relationship</span>
              <input
                value={guardianForm.relationship}
                onChange={(event) =>
                  setGuardianForm((previous) => ({ ...previous, relationship: event.target.value }))
                }
              />
            </label>
            <label className="full-span">
              <span>Address</span>
              <input
                value={guardianForm.address}
                onChange={(event) =>
                  setGuardianForm((previous) => ({ ...previous, address: event.target.value }))
                }
              />
            </label>
            <button className="primary-button" type="submit" disabled={state.saving || !isOnline}>
              {!isOnline ? "Offline" : state.saving ? "Saving..." : "Create Guardian"}
            </button>
          </form>
        </article>

        <article className="data-panel">
          <div className="panel-header">
            <div className="panel-copy">
              <span className="feature-label">Create Student</span>
              <h4>Admission intake</h4>
              <p className="panel-note">Capture branch, class, and guardian ownership in one flow.</p>
            </div>
          </div>

          <form className="form-card compact-form" onSubmit={handleStudentCreate}>
            <label>
              <span>Admission No</span>
              <input
                value={studentForm.admissionNo}
                onChange={(event) =>
                  setStudentForm((previous) => ({ ...previous, admissionNo: event.target.value }))
                }
                required
              />
            </label>
            <label>
              <span>Full Name</span>
              <input
                value={studentForm.fullName}
                onChange={(event) =>
                  setStudentForm((previous) => ({ ...previous, fullName: event.target.value }))
                }
                required
              />
            </label>
            <label>
              <span>Gender</span>
              <select
                value={studentForm.gender}
                onChange={(event) =>
                  setStudentForm((previous) => ({
                    ...previous,
                    gender: event.target.value as StudentFormState["gender"],
                  }))
                }
              >
                <option value="male">Male</option>
                <option value="female">Female</option>
              </select>
            </label>
            <label>
              <span>Date of Birth</span>
              <input
                type="date"
                value={studentForm.dob}
                onChange={(event) => setStudentForm((previous) => ({ ...previous, dob: event.target.value }))}
              />
            </label>
            <label>
              <span>Branch</span>
              <select
                value={studentForm.branchId}
                onChange={(event) =>
                  setStudentForm((previous) => ({
                    ...previous,
                    branchId: event.target.value,
                    classId: "",
                  }))
                }
              >
                {(state.organization?.branches ?? []).map((branch) => (
                  <option key={branch.id} value={branch.id}>
                    {branch.name}
                  </option>
                ))}
              </select>
            </label>
            <label>
              <span>Class</span>
              <select
                value={studentForm.classId}
                onChange={(event) =>
                  setStudentForm((previous) => ({ ...previous, classId: event.target.value }))
                }
              >
                <option value="">No class yet</option>
                {classOptions.map((classRecord) => (
                  <option key={classRecord.id} value={classRecord.id}>
                    {classRecord.name} ({classRecord.academicYear})
                  </option>
                ))}
              </select>
            </label>
            <label>
              <span>Joined On</span>
              <input
                type="date"
                value={studentForm.joinedOn}
                onChange={(event) =>
                  setStudentForm((previous) => ({ ...previous, joinedOn: event.target.value }))
                }
              />
            </label>
            <label className="full-span">
              <span>Notes</span>
              <textarea
                value={studentForm.notes}
                onChange={(event) => setStudentForm((previous) => ({ ...previous, notes: event.target.value }))}
                rows={3}
              />
            </label>

            <label>
              <span>Guardian Source</span>
              <select
                value={studentForm.guardianMode}
                onChange={(event) =>
                  setStudentForm((previous) => ({
                    ...previous,
                    guardianMode: event.target.value as StudentFormState["guardianMode"],
                  }))
                }
              >
                <option value="existing">Use existing guardian</option>
                <option value="new">Create new guardian inline</option>
              </select>
            </label>

            {studentForm.guardianMode === "existing" ? (
              <label>
                <span>Primary Guardian</span>
                <select
                  value={studentForm.primaryGuardianId}
                  onChange={(event) =>
                    setStudentForm((previous) => ({
                      ...previous,
                      primaryGuardianId: event.target.value,
                    }))
                  }
                >
                  {state.guardians.map((guardian) => (
                    <option key={guardian.id} value={guardian.id}>
                      {guardian.fullName} ({guardian.phone})
                    </option>
                  ))}
                </select>
              </label>
            ) : (
              <>
                <label>
                  <span>Guardian Name</span>
                  <input
                    value={studentForm.guardian.fullName}
                    onChange={(event) =>
                      setStudentForm((previous) => ({
                        ...previous,
                        guardian: { ...previous.guardian, fullName: event.target.value },
                      }))
                    }
                    required
                  />
                </label>
                <label>
                  <span>Guardian Phone</span>
                  <input
                    value={studentForm.guardian.phone}
                    onChange={(event) =>
                      setStudentForm((previous) => ({
                        ...previous,
                        guardian: { ...previous.guardian, phone: event.target.value },
                      }))
                    }
                    required
                  />
                </label>
                <label>
                  <span>Guardian Email</span>
                  <input
                    type="email"
                    value={studentForm.guardian.email}
                    onChange={(event) =>
                      setStudentForm((previous) => ({
                        ...previous,
                        guardian: { ...previous.guardian, email: event.target.value },
                      }))
                    }
                  />
                </label>
                <label>
                  <span>Relationship</span>
                  <input
                    value={studentForm.guardian.relationship}
                    onChange={(event) =>
                      setStudentForm((previous) => ({
                        ...previous,
                        guardian: { ...previous.guardian, relationship: event.target.value },
                      }))
                    }
                  />
                </label>
              </>
            )}

            <button className="primary-button full-span" type="submit" disabled={state.saving || !isOnline}>
              {!isOnline ? "Offline" : state.saving ? "Saving..." : "Create Student"}
            </button>
          </form>
        </article>

        <article className="data-panel">
          <div className="panel-header">
            <div className="panel-copy">
              <span className="feature-label">Student List</span>
              <h4>Current registry</h4>
              <p className="panel-note">Browse the current page and open a student record for editing.</p>
            </div>
            <span className="panel-meta">
              {state.studentsMeta?.totalItems ?? state.students.length} total
            </span>
          </div>

          {state.loading ? (
            <LoadingRowList rows={5} />
          ) : (
            <div className="row-list">
              {state.students.map((student) => (
                <button
                  key={student.id}
                  type="button"
                  className={`row-item selectable-row${student.id === state.selectedStudentId ? " selected" : ""}`}
                  onClick={() =>
                    setState((previous) => ({
                      ...previous,
                      selectedStudentId: student.id,
                      success: null,
                      error: null,
                    }))
                  }
                >
                  <div>
                    <strong>{student.fullName}</strong>
                    <p className="muted">
                      {student.admissionNo} • {student.branch.name}
                    </p>
                  </div>
                  <span className={`status-chip status-${student.status.toLowerCase()}`}>{student.status}</span>
                </button>
              ))}
              {!state.students.length ? <InlineEmptyState message="No students registered yet." /> : null}
            </div>
          )}

          {(state.studentsMeta?.totalPages ?? 1) > 1 ? (
            <div className="pagination-bar">
              <button
                type="button"
                className="secondary-button"
                onClick={() =>
                  setFilters((previous) => ({ ...previous, page: Math.max(1, previous.page - 1) }))
                }
                disabled={filters.page === 1}
              >
                Previous
              </button>
              <span className="pagination-text">
                Page {state.studentsMeta?.page ?? filters.page} of {totalPages}
              </span>
              <button
                type="button"
                className="secondary-button"
                onClick={() =>
                  setFilters((previous) => ({
                    ...previous,
                    page: Math.min(totalPages, previous.page + 1),
                  }))
                }
                disabled={filters.page === totalPages}
              >
                Next
              </button>
            </div>
          ) : null}
        </article>

        <article className="data-panel data-panel-wide">
          <div className="panel-header">
            <div className="panel-copy">
              <span className="feature-label">Student Detail</span>
              <h4>{selectedStudent?.fullName ?? "Select a student"}</h4>
              <p className="panel-note">
                {selectedStudent
                  ? `${selectedStudent.admissionNo} • ${selectedStudent.branch.name}`
                  : "Choose a student from the registry to manage records and guardians."}
              </p>
            </div>
            {selectedStudent ? <span className="panel-meta">{selectedStudent.status}</span> : null}
          </div>

          {selectedStudent && editStudentForm ? (
            <div className="split-panel registry-detail-layout">
              <form className="form-card compact-form registry-detail-form" onSubmit={handleStudentUpdate}>
                <label>
                  <span>Admission No</span>
                  <input
                    value={editStudentForm.admissionNo}
                    onChange={(event) =>
                      setEditStudentForm((previous) =>
                        previous ? { ...previous, admissionNo: event.target.value } : previous,
                      )
                    }
                  />
                </label>
                <label>
                  <span>Full Name</span>
                  <input
                    value={editStudentForm.fullName}
                    onChange={(event) =>
                      setEditStudentForm((previous) =>
                        previous ? { ...previous, fullName: event.target.value } : previous,
                      )
                    }
                  />
                </label>
                <label>
                  <span>Status</span>
                  <select
                    value={editStudentForm.status}
                    onChange={(event) =>
                      setEditStudentForm((previous) =>
                        previous
                          ? {
                              ...previous,
                              status: event.target.value as EditStudentFormState["status"],
                            }
                          : previous,
                      )
                    }
                  >
                    <option value="ACTIVE">ACTIVE</option>
                    <option value="INACTIVE">INACTIVE</option>
                    <option value="SUSPENDED">SUSPENDED</option>
                    <option value="GRADUATED">GRADUATED</option>
                  </select>
                </label>
                <label>
                  <span>Gender</span>
                  <select
                    value={editStudentForm.gender}
                    onChange={(event) =>
                      setEditStudentForm((previous) =>
                        previous
                          ? {
                              ...previous,
                              gender: event.target.value as EditStudentFormState["gender"],
                            }
                          : previous,
                      )
                    }
                  >
                    <option value="male">Male</option>
                    <option value="female">Female</option>
                  </select>
                </label>
                <label>
                  <span>Branch</span>
                  <select
                    value={editStudentForm.branchId}
                    onChange={(event) =>
                      setEditStudentForm((previous) =>
                        previous
                          ? {
                              ...previous,
                              branchId: event.target.value,
                              classId: "",
                            }
                          : previous,
                      )
                    }
                  >
                    {(state.organization?.branches ?? []).map((branch) => (
                      <option key={branch.id} value={branch.id}>
                        {branch.name}
                      </option>
                    ))}
                  </select>
                </label>
                <label>
                  <span>Class</span>
                  <select
                    value={editStudentForm.classId}
                    onChange={(event) =>
                      setEditStudentForm((previous) =>
                        previous ? { ...previous, classId: event.target.value } : previous,
                      )
                    }
                  >
                    <option value="">No class yet</option>
                    {editClassOptions.map((classRecord) => (
                      <option key={classRecord.id} value={classRecord.id}>
                        {classRecord.name} ({classRecord.academicYear})
                      </option>
                    ))}
                  </select>
                </label>
                <label>
                  <span>Date of Birth</span>
                  <input
                    type="date"
                    value={editStudentForm.dob}
                    onChange={(event) =>
                      setEditStudentForm((previous) =>
                        previous ? { ...previous, dob: event.target.value } : previous,
                      )
                    }
                  />
                </label>
                <label>
                  <span>Joined On</span>
                  <input
                    type="date"
                    value={editStudentForm.joinedOn}
                    onChange={(event) =>
                      setEditStudentForm((previous) =>
                        previous ? { ...previous, joinedOn: event.target.value } : previous,
                      )
                    }
                  />
                </label>
                <label>
                  <span>Left On</span>
                  <input
                    type="date"
                    value={editStudentForm.leftOn}
                    onChange={(event) =>
                      setEditStudentForm((previous) =>
                        previous ? { ...previous, leftOn: event.target.value } : previous,
                      )
                    }
                  />
                </label>
                <label className="full-span">
                  <span>Notes</span>
                  <textarea
                    value={editStudentForm.notes}
                    onChange={(event) =>
                      setEditStudentForm((previous) =>
                        previous ? { ...previous, notes: event.target.value } : previous,
                      )
                    }
                    rows={4}
                  />
                </label>
                <button className="primary-button full-span" type="submit" disabled={state.saving || !isOnline}>
                  {!isOnline ? "Offline" : state.saving ? "Saving..." : "Update Student"}
                </button>
              </form>

              <div className="stack-panel registry-detail-side">
                <div className="detail-card">
                  <span className="feature-label">Primary Guardian</span>
                  <h5>{selectedStudent.primaryGuardian.fullName}</h5>
                  <p className="muted">
                    {selectedStudent.primaryGuardian.phone}
                    {selectedStudent.primaryGuardian.relationship
                      ? ` • ${selectedStudent.primaryGuardian.relationship}`
                      : ""}
                  </p>
                  <p className="muted">
                    Joined {selectedStudent.joinedOn ? formatDate(selectedStudent.joinedOn) : "not set"}
                  </p>
                  {selectedStudent.currentClass ? (
                    <div className="action-row top-spacing">
                      <Link
                        className="secondary-button button-link"
                        to={`/classes/${selectedStudent.currentClass.id}`}
                      >
                        Open {selectedStudent.currentClass.name}
                      </Link>
                    </div>
                  ) : null}
                </div>

                <form className="form-card registry-link-form" onSubmit={handleLinkGuardian}>
                  <label>
                    <span>Link Existing Guardian</span>
                    <select value={linkGuardianId} onChange={(event) => setLinkGuardianId(event.target.value)}>
                      <option value="">Choose guardian</option>
                      {state.guardians
                        .filter(
                          (guardian) =>
                            !selectedStudent.guardians.some((link) => link.guardian.id === guardian.id),
                        )
                        .map((guardian) => (
                          <option key={guardian.id} value={guardian.id}>
                            {guardian.fullName} ({guardian.phone})
                          </option>
                        ))}
                    </select>
                  </label>
                  <button
                    className="secondary-button"
                    type="submit"
                    disabled={state.saving || !linkGuardianId || !isOnline}
                  >
                    {!isOnline ? "Offline" : "Link Guardian"}
                  </button>
                </form>

                <div className="row-list">
                  {selectedStudent.guardians.map((link) => (
                    <div key={link.guardian.id} className="row-item stacked-row">
                      <div>
                        <strong>{link.guardian.fullName}</strong>
                        <p className="muted">
                          {link.guardian.phone}
                          {link.guardian.relationship ? ` • ${link.guardian.relationship}` : ""}
                        </p>
                      </div>
                      <div className="action-row">
                        {!link.isPrimary ? (
                          <button
                            type="button"
                            className="secondary-button"
                            onClick={() => void handleSetPrimaryGuardian(link.guardian.id)}
                            disabled={state.saving || !isOnline}
                          >
                            {!isOnline ? "Offline" : "Make Primary"}
                          </button>
                        ) : (
                          <span className="status-chip status-present">PRIMARY</span>
                        )}
                        {!link.isPrimary ? (
                          <button
                            type="button"
                            className="danger-button"
                            onClick={() => void handleUnlinkGuardian(link.guardian.id)}
                            disabled={state.saving || !isOnline}
                          >
                            {!isOnline ? "Offline" : "Remove"}
                          </button>
                        ) : null}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          ) : (
            <InlineEmptyState message="Select a student from the registry to edit details and manage guardians." />
          )}
        </article>
      </div>
    </section>
  );
};
