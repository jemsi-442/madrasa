import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type PropsWithChildren,
} from "react";

declare global {
  interface BeforeInstallPromptEvent extends Event {
    prompt: () => Promise<void>;
    userChoice: Promise<{ outcome: "accepted" | "dismissed"; platform: string }>;
  }
}

type PwaContextValue = {
  isSupported: boolean;
  isInstalled: boolean;
  isOnline: boolean;
  canInstall: boolean;
  updateReady: boolean;
  installApp: () => Promise<boolean>;
  applyUpdate: () => void;
};

const PwaContext = createContext<PwaContextValue | undefined>(undefined);

const isStandaloneDisplay = () =>
  window.matchMedia("(display-mode: standalone)").matches || (window.navigator as Navigator & { standalone?: boolean }).standalone === true;

export const PwaProvider = ({ children }: PropsWithChildren) => {
  const [deferredPrompt, setDeferredPrompt] = useState<BeforeInstallPromptEvent | null>(null);
  const [waitingWorker, setWaitingWorker] = useState<ServiceWorker | null>(null);
  const [isInstalled, setIsInstalled] = useState(false);
  const [isOnline, setIsOnline] = useState(() => window.navigator.onLine);
  const controllerChangeHandledRef = useRef(false);

  useEffect(() => {
    setIsInstalled(isStandaloneDisplay());

    const handleBeforeInstallPrompt = (event: Event) => {
      event.preventDefault();
      setDeferredPrompt(event as BeforeInstallPromptEvent);
    };

    const handleInstalled = () => {
      setIsInstalled(true);
      setDeferredPrompt(null);
    };

    window.addEventListener("beforeinstallprompt", handleBeforeInstallPrompt);
    window.addEventListener("appinstalled", handleInstalled);

    return () => {
      window.removeEventListener("beforeinstallprompt", handleBeforeInstallPrompt);
      window.removeEventListener("appinstalled", handleInstalled);
    };
  }, []);

  useEffect(() => {
    const handleOnline = () => setIsOnline(true);
    const handleOffline = () => setIsOnline(false);

    window.addEventListener("online", handleOnline);
    window.addEventListener("offline", handleOffline);

    return () => {
      window.removeEventListener("online", handleOnline);
      window.removeEventListener("offline", handleOffline);
    };
  }, []);

  useEffect(() => {
    if (!("serviceWorker" in navigator)) {
      return;
    }

    if (import.meta.env.DEV) {
      void navigator.serviceWorker.getRegistrations().then((registrations) => {
        registrations.forEach((registration) => {
          void registration.unregister();
        });
      });
      return;
    }

    let active = true;

    const registerWorker = async () => {
      const registration = await navigator.serviceWorker.register("/sw.js");

      if (!active) {
        return;
      }

      if (registration.waiting) {
        setWaitingWorker(registration.waiting);
      }

      registration.addEventListener("updatefound", () => {
        const installing = registration.installing;

        if (!installing) {
          return;
        }

        installing.addEventListener("statechange", () => {
          if (installing.state === "installed" && navigator.serviceWorker.controller) {
            setWaitingWorker(registration.waiting ?? installing);
          }
        });
      });

      navigator.serviceWorker.addEventListener("controllerchange", () => {
        if (controllerChangeHandledRef.current) {
          return;
        }

        controllerChangeHandledRef.current = true;
        window.location.reload();
      });
    };

    void registerWorker();

    return () => {
      active = false;
    };
  }, []);

  const installApp = async () => {
    if (!deferredPrompt) {
      return false;
    }

    await deferredPrompt.prompt();
    const result = await deferredPrompt.userChoice;

    if (result.outcome === "accepted") {
      setDeferredPrompt(null);
      return true;
    }

    return false;
  };

  const applyUpdate = () => {
    waitingWorker?.postMessage({ type: "SKIP_WAITING" });
    setWaitingWorker(null);
  };

  const value = useMemo<PwaContextValue>(
    () => ({
      isSupported: "serviceWorker" in navigator,
      isInstalled,
      isOnline,
      canInstall: Boolean(deferredPrompt) && !isInstalled,
      updateReady: Boolean(waitingWorker),
      installApp,
      applyUpdate,
    }),
    [deferredPrompt, isInstalled, isOnline, waitingWorker],
  );

  return <PwaContext.Provider value={value}>{children}</PwaContext.Provider>;
};

export const usePwa = () => {
  const context = useContext(PwaContext);

  if (!context) {
    throw new Error("usePwa must be used inside PwaProvider");
  }

  return context;
};
