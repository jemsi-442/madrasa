import { useEffect, useRef, useState } from "react";
import { NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";

import { useAuth } from "../lib/auth";
import { useNotifications } from "../lib/notifications";
import { usePwa } from "../lib/pwa";

type ShellIconKind = "dashboard" | "finance" | "students" | "teacher" | "parent" | "classroom";

type ShellLink = {
  to: string;
  label: string;
  icon: ShellIconKind;
};

type ShellContext = {
  section: string;
  title: string;
  icon: ShellIconKind;
};

const roleLinks = {
  ADMIN: [
    { to: "/dashboard", label: "Operations Dashboard", icon: "dashboard" },
    { to: "/finance", label: "Finance Workspace", icon: "finance" },
    { to: "/students", label: "Student Registry", icon: "students" },
    { to: "/teacher", label: "Teacher Workspace", icon: "teacher" },
    { to: "/parent", label: "Parent Portal", icon: "parent" },
  ] satisfies readonly ShellLink[],
  ACCOUNTANT: [
    { to: "/dashboard", label: "Finance Dashboard", icon: "dashboard" },
    { to: "/finance", label: "Finance Workspace", icon: "finance" },
  ] satisfies readonly ShellLink[],
  TEACHER: [{ to: "/teacher", label: "Teacher Workspace", icon: "teacher" }] satisfies readonly ShellLink[],
  PARENT: [{ to: "/parent", label: "Parent Portal", icon: "parent" }] satisfies readonly ShellLink[],
} as const;

const getShellContext = (pathname: string, role?: keyof typeof roleLinks): ShellContext => {
  if (pathname.startsWith("/finance")) {
    return {
      section: "Workspace",
      title: "Finance Workspace",
      icon: "finance",
    };
  }

  if (pathname.startsWith("/students")) {
    return {
      section: "Workspace",
      title: "Student Registry",
      icon: "students",
    };
  }

  if (pathname.startsWith("/teacher")) {
    return {
      section: "Workspace",
      title: "Teacher Workspace",
      icon: "teacher",
    };
  }

  if (pathname.startsWith("/parent")) {
    return {
      section: "Workspace",
      title: "Parent Portal",
      icon: "parent",
    };
  }

  if (pathname.startsWith("/classes/")) {
    return {
      section: "Workspace",
      title: "Class Detail",
      icon: "classroom",
    };
  }

  return {
    section: "Workspace",
    title: role === "ACCOUNTANT" ? "Finance Dashboard" : "Operations Dashboard",
    icon: "dashboard",
  };
};

const ShellIcon = ({ kind }: { kind: ShellIconKind }) => {
  if (kind === "finance") {
    return (
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M4 7.5h16v9H4z" />
        <path d="M4 10.5h16" />
        <path d="M8 15h2.5" />
      </svg>
    );
  }

  if (kind === "students") {
    return (
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M12 7 4 10.5 12 14l8-3.5L12 7Z" />
        <path d="M7.5 12.5v3.2c0 1.2 2 2.3 4.5 2.3s4.5-1.1 4.5-2.3v-3.2" />
      </svg>
    );
  }

  if (kind === "teacher") {
    return (
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M5 6.5h11a2 2 0 0 1 2 2v9H7a2 2 0 0 0-2 2z" />
        <path d="M7 6.5v13" />
        <path d="M18 8.5h1.5" />
      </svg>
    );
  }

  if (kind === "parent") {
    return (
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M7.5 11a2.5 2.5 0 1 0 0-.01Z" />
        <path d="M16.5 11a2.5 2.5 0 1 0 0-.01Z" />
        <path d="M4.5 18c.7-2.3 2.4-3.5 5-3.5s4.3 1.2 5 3.5" />
        <path d="M12.5 18c.5-1.7 1.8-2.6 4-2.6 1.5 0 2.6.4 3.4 1.1" />
      </svg>
    );
  }

  if (kind === "classroom") {
    return (
      <svg viewBox="0 0 24 24" aria-hidden="true">
        <path d="M4 7h16v10H4z" />
        <path d="M9 17v2" />
        <path d="M15 17v2" />
        <path d="M8 11h8" />
      </svg>
    );
  }

  return (
    <svg viewBox="0 0 24 24" aria-hidden="true">
      <path d="M5 5h6v6H5z" />
      <path d="M13 5h6v9h-6z" />
      <path d="M5 13h6v6H5z" />
      <path d="M13 16h6v3h-6z" />
    </svg>
  );
};

const getInitials = (fullName?: string) => {
  const parts = (fullName ?? "")
    .trim()
    .split(/\s+/)
    .filter(Boolean);

  if (!parts.length) {
    return "MF";
  }

  return parts
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("");
};

export const AppShell = () => {
  const { session, logout } = useAuth();
  const notifications = useNotifications();
  const { canInstall, installApp, isInstalled, isOnline, updateReady, applyUpdate } = usePwa();
  const navigate = useNavigate();
  const location = useLocation();
  const [navOpen, setNavOpen] = useState(false);
  const onlineStateInitializedRef = useRef(false);

  const links = session ? roleLinks[session.user.role] : [];
  const shellContext = getShellContext(location.pathname, session?.user.role);
  const currentYear = new Date().getFullYear();
  const sessionInitials = getInitials(session?.user.fullName);
  const todayLabel = new Intl.DateTimeFormat("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
  }).format(new Date());

  useEffect(() => {
    setNavOpen(false);
  }, [location.pathname]);

  useEffect(() => {
    if (updateReady) {
      notifications.info("A newer app version is ready. Use update to refresh safely.");
    }
  }, [notifications, updateReady]);

  useEffect(() => {
    if (!onlineStateInitializedRef.current) {
      onlineStateInitializedRef.current = true;
      return;
    }

    if (isOnline) {
      notifications.success("Connection restored. Live actions are available again.");
      return;
    }

    notifications.info("You are offline. Live saves, exports, and payment actions are temporarily paused.");
  }, [isOnline, notifications]);

  const handleLogout = async () => {
    await logout();
    setNavOpen(false);
    notifications.info("Signed out successfully.");
    navigate("/login", { replace: true });
  };

  const handleInstall = async () => {
    const accepted = await installApp();

    if (accepted) {
      notifications.success("App install started successfully.");
      return;
    }

    notifications.info("Install prompt was dismissed.");
  };

  return (
    <div className="app-shell">
      <aside className={`side-nav${navOpen ? " is-open" : ""}`} id="primary-navigation">
        <div className="brand-block">
          <div className="brand-seal">
            <img src="/brand/mif-mark.svg" alt="MODERN ISLAMIC FOUNDATION mark" className="brand-mark" />
          </div>

          <div className="brand-copy">
            <span className="brand-tag">Foundation System</span>
            <h1>MODERN ISLAMIC FOUNDATION</h1>
            <p>Where Innovation Meets Faith</p>
          </div>
        </div>

        <div className="nav-section-label">Workspace</div>
        <nav className="nav-list" aria-label="Primary navigation">
          {links.map((link) => (
            <NavLink
              key={link.to}
              to={link.to}
              className={({ isActive }) => `nav-link${isActive ? " active" : ""}`}
            >
              <span className="nav-icon" aria-hidden="true">
                <ShellIcon kind={link.icon} />
              </span>
              <span>{link.label}</span>
            </NavLink>
          ))}
        </nav>

        <div className="side-nav-footer">
          <strong>{session?.user.fullName}</strong>
          <p>Secure session</p>
        </div>
      </aside>

      <button
        type="button"
        className={`nav-scrim${navOpen ? " is-visible" : ""}`}
        aria-label="Close navigation"
        onClick={() => setNavOpen(false)}
      />

      <div className="main-column">
        <header className="top-bar">
          <div className="top-bar-primary">
            <button
              type="button"
              className={`menu-toggle${navOpen ? " is-open" : ""}`}
              aria-controls="primary-navigation"
              aria-expanded={navOpen}
              aria-label={navOpen ? "Close navigation" : "Open navigation"}
              onClick={() => setNavOpen((open) => !open)}
            >
              <span className="shell-action-icon" aria-hidden="true">
                <svg viewBox="0 0 24 24">
                  {navOpen ? (
                    <>
                      <path d="M6 6l12 12" />
                      <path d="M18 6 6 18" />
                    </>
                  ) : (
                    <>
                      <path d="M4 7h16" />
                      <path d="M4 12h16" />
                      <path d="M4 17h16" />
                    </>
                  )}
                </svg>
              </span>
            </button>

            <div className="top-bar-context">
              <p className="eyebrow">{shellContext.section}</p>
              <div className="top-bar-title-row">
                <span className="context-icon" aria-hidden="true">
                  <ShellIcon kind={shellContext.icon} />
                </span>
                <div className="top-bar-title-copy">
                  <h2>{shellContext.title}</h2>
                </div>
              </div>
            </div>
          </div>

          <div className="top-bar-actions">
            {canInstall && !isInstalled ? (
              <button type="button" className="shell-utility-button is-primary" onClick={() => void handleInstall()}>
                <span className="shell-action-icon" aria-hidden="true">
                  <svg viewBox="0 0 24 24">
                    <path d="M12 4v10" />
                    <path d="m8 10 4 4 4-4" />
                    <path d="M5 19h14" />
                  </svg>
                </span>
                <span className="shell-action-label">Install App</span>
              </button>
            ) : null}

            {updateReady ? (
              <button type="button" className="shell-utility-button is-primary" onClick={applyUpdate}>
                <span className="shell-action-icon" aria-hidden="true">
                  <svg viewBox="0 0 24 24">
                    <path d="M20 11a8 8 0 1 0 2 5.5" />
                    <path d="M20 4v7h-7" />
                  </svg>
                </span>
                <span className="shell-action-label">Update App</span>
              </button>
            ) : null}

            <div className="top-bar-session">
              <span className="top-bar-user-mark" aria-hidden="true">
                {sessionInitials}
              </span>
              <div className="top-bar-meta">
                <strong>{session?.user.fullName}</strong>
                <span>{todayLabel}</span>
              </div>
            </div>

            <button type="button" className="shell-utility-button" onClick={handleLogout}>
              <span className="shell-action-icon" aria-hidden="true">
                <svg viewBox="0 0 24 24">
                  <path d="M10 7H6a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h4" />
                  <path d="M13 8l5 4-5 4" />
                  <path d="M18 12H9" />
                </svg>
              </span>
              <span className="shell-action-label">Sign Out</span>
            </button>
          </div>
        </header>

        {!isOnline ? (
          <div className="app-status-banner is-offline" role="status" aria-live="polite">
            <span className="status-dot" aria-hidden="true" />
            <strong>Offline mode</strong>
            <span>Live saves, exports, and payment actions will resume when the connection returns.</span>
          </div>
        ) : null}

        <main className="page-content">
          <Outlet />
        </main>

        <footer className="shell-footer">
          <p>&copy; {currentYear} MODERN ISLAMIC FOUNDATION. All rights reserved.</p>
          <span>{isOnline ? "Foundation Management System" : "Offline mode active"}</span>
        </footer>
      </div>
    </div>
  );
};
