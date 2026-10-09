{{flutter_js}}
{{flutter_build_config}}

async function startAfaq() {
  // Retire only this app's old generated worker, not other apps on the origin.
  // It can otherwise keep serving a release bundle over the development server.
  if ('serviceWorker' in navigator) {
    const workerUrl = new URL('flutter_service_worker.js', document.baseURI);
    const scope = new URL('.', document.baseURI).href;
    const registrations = await navigator.serviceWorker.getRegistrations().catch(() => []);
    for (const registration of registrations) {
      const script = registration.active?.scriptURL;
      if (registration.scope === scope && script &&
          new URL(script).pathname === workerUrl.pathname) {
        const controlled = navigator.serviceWorker.controller?.scriptURL === script;
        const removed = await registration.unregister().catch(() => false);
        if (removed && controlled) {
          location.reload();
          return;
        }
      }
    }
  }
  // Keep the renderer on the same host, including on slow local networks.
  await _flutter.loader.load({ config: { canvasKitBaseUrl: 'canvaskit/' } });
}

startAfaq();
