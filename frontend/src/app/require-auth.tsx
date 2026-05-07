import { Navigate, Outlet, useLocation } from "react-router-dom";

import { defaultPathForRole, useAuth } from "../lib/auth";

export const RequireAuth = () => {
  const { session } = useAuth();
  const location = useLocation();

  if (!session) {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  }

  return <Outlet />;
};

export const RedirectAuthenticatedUser = () => {
  const { session } = useAuth();

  if (!session) {
    return <Outlet />;
  }

  return <Navigate to={defaultPathForRole(session.user.role)} replace />;
};

