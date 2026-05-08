import { Navigate, Outlet, useLocation } from "react-router-dom";

import { defaultPathForRole, useAuth } from "../lib/auth";

const AuthRestoreScreen = () => (
  <div className="auth-restore-screen" role="status" aria-live="polite">
    <div className="auth-restore-card">
      <div className="auth-restore-mark-wrap">
        <img src="/brand/mif-mark.svg" alt="MODERN ISLAMIC FOUNDATION mark" className="auth-restore-mark" />
      </div>
      <p className="eyebrow">Session Restore</p>
      <h2>Restoring your secure workspace</h2>
      <p>Checking your saved session and preparing the latest foundation data.</p>
    </div>
  </div>
);

export const RequireAuth = () => {
  const { session, isRestoring } = useAuth();
  const location = useLocation();

  if (isRestoring) {
    return <AuthRestoreScreen />;
  }

  if (!session) {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }

  return <Outlet />;
};

export const RedirectAuthenticatedUser = () => {
  const { session, isRestoring } = useAuth();

  if (isRestoring) {
    return <AuthRestoreScreen />;
  }

  if (!session) {
    return <Outlet />;
  }

  return <Navigate to={defaultPathForRole(session.user.role)} replace />;
};
