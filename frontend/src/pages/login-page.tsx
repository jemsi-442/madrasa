import { FormEvent, useState } from "react";
import { useNavigate } from "react-router-dom";

import { defaultPathForRole, useAuth } from "../lib/auth";
import { getApiBaseUrl } from "../lib/api";
import { useNotifications } from "../lib/notifications";

export const LoginPage = () => {
  const navigate = useNavigate();
  const { login } = useAuth();
  const notifications = useNotifications();
  const [loginValue, setLoginValue] = useState("admin@example.com");
  const [password, setPassword] = useState("ChangeMe123!");
  const [status, setStatus] = useState<string>("Sign in with your MODERN ISLAMIC FOUNDATION account.");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setLoading(true);
    setStatus("Signing in...");

    try {
      const result = await login({ login: loginValue, password });
      setStatus(`Welcome ${result.user.fullName}. Opening your workspace...`);
      notifications.success(`Welcome ${result.user.fullName}.`);
      navigate(defaultPathForRole(result.user.role), { replace: true });
    } catch (error) {
      const message = error instanceof Error ? error.message : "Login failed.";
      setStatus(message);
      notifications.error(message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <section className="page-card hero-page">
      <div className="login-hero">
        <div className="hero-seal">
          <img src="/brand/mif-mark.svg" alt="MODERN ISLAMIC FOUNDATION mark" className="hero-mark" />
        </div>

        <p className="eyebrow">MODERN ISLAMIC FOUNDATION</p>
        <h3>Where Innovation Meets Faith</h3>
        <p className="hero-summary">
          Secure access to administration, finance, teaching, and parent services in one foundation platform.
        </p>

        <div className="feature-card auth-guide">
          <span className="feature-label">Registration and Login</span>
          <p>Account registration is completed by MODERN ISLAMIC FOUNDATION administration during onboarding.</p>

          <ul className="guide-list">
            <li>Each account is registered with the user&apos;s full profile, including phone number, email address, and access role.</li>
            <li>After registration, the user receives the approved login details for their workspace.</li>
            <li>Use those assigned details here to sign in securely and continue with daily school operations.</li>
          </ul>
        </div>

        <p className="connection-note">
          Connected to live backend endpoint at <code>{getApiBaseUrl()}</code>.
        </p>
      </div>

      <form className="form-card auth-card" onSubmit={handleSubmit}>
        <div className="auth-card-heading">
          <span className="feature-label">Secure Sign In</span>
          <h4>Access your workspace</h4>
          <p>Use the login detail assigned to your registered foundation account.</p>
        </div>

        <label>
          <span>Registered Login</span>
          <input
            value={loginValue}
            onChange={(event) => setLoginValue(event.target.value)}
            type="text"
            autoComplete="username"
          />
          <small className="field-hint">Enter the approved login detail shared with you after account registration.</small>
        </label>

        <label>
          <span>Password</span>
          <input
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            type="password"
            autoComplete="current-password"
          />
        </label>

        <button className="primary-button" type="submit" disabled={loading}>
          {loading ? "Signing In..." : "Sign In"}
        </button>

        <p className="status-line">{status}</p>
        <p className="auth-support">
          If your account has not been created yet, contact MODERN ISLAMIC FOUNDATION administration to complete registration and access setup.
        </p>
      </form>
    </section>
  );
};
