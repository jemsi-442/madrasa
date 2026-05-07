import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";

import { AppShell } from "./app-shell";
import { RedirectAuthenticatedUser, RequireAuth } from "./require-auth";
import { DashboardPage } from "../pages/dashboard-page";
import { FinanceWorkspacePage } from "../pages/finance-workspace-page";
import { ClassDetailPage } from "../pages/class-detail-page";
import { LoginPage } from "../pages/login-page";
import { ParentPortalPage } from "../pages/parent-portal-page";
import { StudentRegistryPage } from "../pages/student-registry-page";
import { TeacherWorkspacePage } from "../pages/teacher-workspace-page";
import { useAuth, defaultPathForRole } from "../lib/auth";

const HomeRedirect = () => {
  const { session } = useAuth();

  if (!session) {
    return <Navigate to="/login" replace />;
  }

  return <Navigate to={defaultPathForRole(session.user.role)} replace />;
};

export const App = () => {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<HomeRedirect />} />
        <Route element={<RequireAuth />}>
          <Route element={<AppShell />}>
            <Route path="/dashboard" element={<DashboardPage />} />
            <Route path="/classes/:classId" element={<ClassDetailPage />} />
            <Route path="/finance" element={<FinanceWorkspacePage />} />
            <Route path="/students" element={<StudentRegistryPage />} />
            <Route path="/teacher" element={<TeacherWorkspacePage />} />
            <Route path="/parent" element={<ParentPortalPage />} />
          </Route>
        </Route>
        <Route element={<RedirectAuthenticatedUser />}>
          <Route path="/login" element={<LoginPage />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
};
