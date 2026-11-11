{{flutter_js}}
{{flutter_build_config}}

async function startAfaq() {
  // Retire only this app's old generated worker, not other apps on the origin.
  // It can otherwise keep serving a release bundle over the development server.
  if ('serviceWorker' in navigator) {
    const workerUrl = new URL('flutter_service_worker.js', document.baseURI);
    const scope = new URL('.', document.baseURI).href;
    const retirement = async () => {
      const registrations = await navigator.serviceWorker.getRegistrations().catch(() => []);
      for (const registration of registrations) {
        const script = registration.active?.scriptURL;
        if (registration.scope === scope && script &&
            new URL(script).pathname === workerUrl.pathname) {
          const controlled = navigator.serviceWorker.controller?.scriptURL === script;
          const removed = await registration.unregister().catch(() => false);
          if (removed && controlled) return true;
        }
      }
      return false;
    };
    // Storage APIs must not hold the initial screen indefinitely. Late cleanup
    // never reloads an app that has already started (and may contain a form).
    let timer;
    const reload = await Promise.race([
      retirement(), new Promise(resolve => { timer = setTimeout(() => resolve(false), 1500); }),
    ]).finally(() => clearTimeout(timer));
    if (reload) { location.reload(); return; }
  }
  // Keep the renderer on the same host, including on slow local networks.
  await _flutter.loader.load({
    config: { canvasKitBaseUrl: 'canvaskit/' },
    onEntrypointLoaded: async engineInitializer => {
      try {
        window.AfaqStartup?.stage(1);
        const runner = await engineInitializer.initializeEngine();
        window.AfaqStartup?.stage(2);
        await runner.runApp();
      } catch (_) { window.AfaqStartup?.fail(); }
    },
  });
}

startAfaq().catch(() => window.AfaqStartup?.fail());
