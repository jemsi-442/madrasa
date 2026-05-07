import { NavLink, Outlet, useNavigate } from "react-router-dom";

import { useAuth } from "../lib/auth";

const roleLinks = {
  ADMIN: [
    { to: "/dashboard", label: "Operations Dashboard" },
    { to: "/finance", label: "Finance Workspace" },
    { to: "/students", label: "Student Registry" },
    { to: "/teacher", label: "Teacher Workspace" },
    { to: "/parent", label: "Parent Portal" },
  ],
  ACCOUNTANT: [
    { to: "/dashboard", label: "Finance Dashboard" },
    { to: "/finance", label: "Finance Workspace" },
  ],
  TEACHER: [{ to: "/teacher", label: "Teacher Workspace" }],
  PARENT: [{ to: "/parent", label: "Parent Portal" }],
} as const;

export const AppShell = () => {
  const { session, logout } = useAuth();
  const navigate = useNavigate();

  const links = session ? roleLinks[session.user.role] : [];

  const handleLogout = async () => {
    await logout();
    navigate("/login", { replace: true });
  };

  return (
    <div className="app-shell">
      <aside className="side-nav">
        <div className="brand-block">
          <span className="brand-tag">MMS</span>
          <h1>Madrasa Management System</h1>
          <p>Production web client aligned to the technical documentation and live backend modules.</p>
        </div>

        <nav className="nav-list" aria-label="Primary navigation">
          {links.map((link) => (
            <NavLink
              key={link.to}
              to={link.to}
              className={({ isActive }) => `nav-link${isActive ? " active" : ""}`}
            >
              {link.label}
            </NavLink>
          ))}
        </nav>
      </aside>

      <div className="main-column">
        <header className="top-bar">
          <div>
            <p className="eyebrow">Tanzania Market Edition</p>
            <h2>Real system workspace for admin, teacher, accountant, and parent workflows</h2>
          </div>

          <div className="top-bar-actions">
            <div className="user-pill">
              <strong>{session?.user.fullName}</strong>
              <span>{session?.user.role}</span>
            </div>

            <button type="button" className="secondary-button" onClick={handleLogout}>
              Sign Out
            </button>
          </div>
        </header>

        <main className="page-content">
          <Outlet />
        </main>
      </div>
    </div>
  );
};
