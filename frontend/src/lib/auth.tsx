import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type PropsWithChildren,
} from "react";

import {
  login as loginRequest,
  logout as logoutRequest,
  registerAuthSessionManager,
  refreshSession as refreshSessionRequest,
  type LoginResult,
  type UserRole,
} from "./api";

const STORAGE_KEY = "mif.frontend.session";

type LoginFormInput = {
  login: string;
  password: string;
};

type AuthContextValue = {
  session: LoginResult | null;
  isAuthenticated: boolean;
  isRestoring: boolean;
  login: (input: LoginFormInput) => Promise<LoginResult>;
  logout: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

const loadStoredSession = () => {
  if (typeof window === "undefined") {
    return null;
  }

  const rawValue = window.localStorage.getItem(STORAGE_KEY);

  if (!rawValue) {
    return null;
  }

  try {
    return JSON.parse(rawValue) as LoginResult;
  } catch {
    window.localStorage.removeItem(STORAGE_KEY);
    return null;
  }
};

export const defaultPathForRole = (role: UserRole) => {
  switch (role) {
    case "TEACHER":
      return "/teacher";
    case "PARENT":
      return "/parent";
    case "ADMIN":
    case "ACCOUNTANT":
    default:
      return "/dashboard";
  }
};

const decodeJwtExpiry = (token: string) => {
  try {
    const [, payloadSegment] = token.split(".");

    if (!payloadSegment) {
      return null;
    }

    const normalizedPayload = payloadSegment.replace(/-/g, "+").replace(/_/g, "/");
    const paddedPayload = normalizedPayload.padEnd(Math.ceil(normalizedPayload.length / 4) * 4, "=");
    const payload = JSON.parse(window.atob(paddedPayload)) as { exp?: number };

    return typeof payload.exp === "number" ? payload.exp : null;
  } catch {
    return null;
  }
};

const isAccessTokenExpired = (accessToken: string) => {
  const expiry = decodeJwtExpiry(accessToken);

  if (!expiry) {
    return true;
  }

  const nowInSeconds = Math.floor(Date.now() / 1000);
  return expiry <= nowInSeconds + 30;
};

export const AuthProvider = ({ children }: PropsWithChildren) => {
  const [session, setSession] = useState<LoginResult | null>(() => loadStoredSession());
  const [isRestoring, setIsRestoring] = useState(true);

  useEffect(() => {
    registerAuthSessionManager({
      getSession: () => session,
      setSession,
    });

    return () => {
      registerAuthSessionManager(null);
    };
  }, [session]);

  useEffect(() => {
    let cancelled = false;

    const restoreSession = async () => {
      const storedSession = loadStoredSession();

      if (!storedSession) {
        if (!cancelled) {
          setSession(null);
          setIsRestoring(false);
        }
        return;
      }

      if (!isAccessTokenExpired(storedSession.accessToken)) {
        if (!cancelled) {
          setSession(storedSession);
          setIsRestoring(false);
        }
        return;
      }

      try {
        const refreshedSession = await refreshSessionRequest(storedSession.refreshToken);

        if (!cancelled) {
          setSession(refreshedSession);
        }
      } catch {
        if (!cancelled) {
          setSession(null);
        }
      } finally {
        if (!cancelled) {
          setIsRestoring(false);
        }
      }
    };

    void restoreSession();

    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    if (!session) {
      window.localStorage.removeItem(STORAGE_KEY);
      return;
    }

    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(session));
  }, [session]);

  const value = useMemo<AuthContextValue>(
    () => ({
      session,
      isAuthenticated: Boolean(session?.accessToken),
      isRestoring,
      login: async (input) => {
        const nextSession = await loginRequest(input);
        setSession(nextSession);
        return nextSession;
      },
      logout: async () => {
        if (session?.refreshToken) {
          try {
            await logoutRequest(session.refreshToken);
          } catch {
            // Clear local session even if the backend session is already invalid or unavailable.
          }
        }

        setSession(null);
      },
    }),
    [isRestoring, session],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};

export const useAuth = () => {
  const context = useContext(AuthContext);

  if (!context) {
    throw new Error("useAuth must be used inside AuthProvider");
  }

  return context;
};
