import { FormEvent, useState } from "react";
import { useNavigate } from "react-router-dom";

import { defaultPathForRole, useAuth } from "../lib/auth";
import { getApiBaseUrl } from "../lib/api";

export const LoginPage = () => {
  const navigate = useNavigate();
  const { login } = useAuth();
  const [loginValue, setLoginValue] = useState("admin@example.com");
  const [password, setPassword] = useState("ChangeMe123!");
  const [status, setStatus] = useState<string>("Sign in with a real MMS account to open the live workspace.");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setLoading(true);
    setStatus("Signing in...");

    try {
      const result = await login({ login: loginValue, password });
      setStatus(`Welcome ${result.user.fullName}. Opening your workspace...`);
      navigate(defaultPathForRole(result.user.role), { replace: true });
    } catch (error) {
      setStatus(error instanceof Error ? error.message : "Login failed.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <section className="page-card hero-page">
      <div>
        <p className="eyebrow">Authentication</p>
        <h3>Real login page</h3>
        <p>
          This page is wired to the live backend endpoint at <code>{getApiBaseUrl()}</code>.
        </p>
      </div>

      <form className="form-card" onSubmit={handleSubmit}>
        <label>
          <span>Email or Phone</span>
          <input
            value={loginValue}
            onChange={(event) => setLoginValue(event.target.value)}
            type="text"
            autoComplete="username"
          />
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
      </form>
    </section>
  );
};
