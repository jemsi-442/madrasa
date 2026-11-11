(() => {
  const root = document.getElementById('app-loading');
  const title = document.getElementById('startup-title');
  const description = document.getElementById('startup-description');
  const retry = document.getElementById('startup-retry');
  let finished = false;
  let failed = false;
  const messages = ['Preparing Afaq for you.', 'Starting your display.', 'Opening your workspace.'];
  function stage(index) {
    if (finished || failed) return;
    description.textContent = messages[index];
    for (let i = 0; i < messages.length; i++) {
      const step = document.getElementById(`startup-step-${i}`);
      step.className = i < index ? 'is-done' : i === index ? 'is-current' : '';
      if (i === index) step.setAttribute('aria-current', 'step');
      else step.removeAttribute('aria-current');
    }
  }
  function fail() {
    if (finished) return;
    failed = true;
    root.dataset.state = 'error';
    root.setAttribute('aria-busy', 'false');
    title.textContent = navigator.onLine === false ? 'You appear to be offline' : 'Afaq could not finish opening';
    description.textContent = navigator.onLine === false
      ? 'Check your connection, then try again.'
      : 'The app is taking longer than expected. Check your connection or try again.';
    retry.hidden = false;
  }
  // These timers apply only before Flutter paints, never to an open form.
  const slow = setTimeout(() => {
    if (!finished && !failed) {
      description.textContent = 'Still preparing your workspace. A first visit may take a little longer.';
    }
  }, 12000);
  const stalled = setTimeout(fail, 45000);
  const resourceError = event => {
    if (event.target?.tagName === 'SCRIPT') fail();
  };
  window.addEventListener('error', resourceError, true);
  window.addEventListener('flutter-first-frame', () => {
    finished = true;
    clearTimeout(slow);
    clearTimeout(stalled);
    window.removeEventListener('error', resourceError, true);
    root.remove();
  }, { once: true });
  retry.addEventListener('click', () => { if (!finished) window.location.reload(); });
  window.AfaqStartup = { stage, fail };
})();
