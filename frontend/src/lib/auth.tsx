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
  type LoginResult,
  type UserRole,
} from "./api";

const STORAGE_KEY = "mms.frontend.session";

type LoginFormInput = {
  login: string;
  password: string;
};

type AuthContextValue = {
  session: LoginResult | null;
  isAuthenticated: boolean;
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

export const AuthProvider = ({ children }: PropsWithChildren) => {
  const [session, setSession] = useState<LoginResult | null>(() => loadStoredSession());

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
    [session],
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

