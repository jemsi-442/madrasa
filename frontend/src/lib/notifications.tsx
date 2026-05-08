import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type PropsWithChildren,
} from "react";

type NotificationTone = "success" | "error" | "info";

type NotificationItem = {
  id: number;
  message: string;
  tone: NotificationTone;
};

type NotificationsContextValue = {
  notify: (message: string, tone?: NotificationTone) => void;
  success: (message: string) => void;
  error: (message: string) => void;
  info: (message: string) => void;
  dismiss: (id: number) => void;
};

const NotificationsContext = createContext<NotificationsContextValue | undefined>(undefined);

const AUTO_DISMISS_MS = 4000;

export const NotificationProvider = ({ children }: PropsWithChildren) => {
  const [items, setItems] = useState<NotificationItem[]>([]);

  const dismiss = useCallback((id: number) => {
    setItems((previous) => previous.filter((item) => item.id !== id));
  }, []);

  const notify = useCallback((message: string, tone: NotificationTone = "info") => {
    const id = Date.now() + Math.floor(Math.random() * 1000);

    setItems((previous) => [...previous, { id, message, tone }]);

    window.setTimeout(() => {
      setItems((previous) => previous.filter((item) => item.id !== id));
    }, AUTO_DISMISS_MS);
  }, []);

  const value = useMemo<NotificationsContextValue>(
    () => ({
      notify,
      success: (message) => notify(message, "success"),
      error: (message) => notify(message, "error"),
      info: (message) => notify(message, "info"),
      dismiss,
    }),
    [dismiss, notify],
  );

  return (
    <NotificationsContext.Provider value={value}>
      {children}
      <div className="toast-viewport" aria-live="polite" aria-atomic="true">
        {items.map((item) => (
          <div key={item.id} className={`toast-card toast-${item.tone}`}>
            <p>{item.message}</p>
            <button type="button" className="toast-close" onClick={() => dismiss(item.id)} aria-label="Dismiss notification">
              x
            </button>
          </div>
        ))}
      </div>
    </NotificationsContext.Provider>
  );
};

export const useNotifications = () => {
  const context = useContext(NotificationsContext);

  if (!context) {
    throw new Error("useNotifications must be used inside NotificationProvider");
  }

  return context;
};

export const useNotifyOnMessage = (errorMessage: string | null | undefined, successMessage: string | null | undefined) => {
  const notifications = useNotifications();
  const lastErrorRef = useRef<string | null>(null);
  const lastSuccessRef = useRef<string | null>(null);

  useEffect(() => {
    if (!errorMessage) {
      lastErrorRef.current = null;
      return;
    }

    if (lastErrorRef.current === errorMessage) {
      return;
    }

    notifications.error(errorMessage);
    lastErrorRef.current = errorMessage;
  }, [errorMessage, notifications]);

  useEffect(() => {
    if (!successMessage) {
      lastSuccessRef.current = null;
      return;
    }

    if (lastSuccessRef.current === successMessage) {
      return;
    }

    notifications.success(successMessage);
    lastSuccessRef.current = successMessage;
  }, [notifications, successMessage]);
};
