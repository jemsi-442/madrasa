import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { runInNewContext } from 'node:vm';

const source = await readFile(new URL('../frontend/web/app_loading.js', import.meta.url), 'utf8');
function loading(online = true) {
  const elements = new Map();
  const listeners = new Map();
  const timers = new Map();
  let reloads = 0;
  const element = id => {
    if (!elements.has(id)) elements.set(id, {
      dataset: {}, attributes: {}, hidden: id === 'startup-retry', textContent: '',
      setAttribute(key, value) { this.attributes[key] = value; },
      removeAttribute(key) { delete this.attributes[key]; },
      remove() { this.removed = true; },
      addEventListener(name, callback) { this[name] = callback; },
    });
    return elements.get(id);
  };
  const window = {
    addEventListener: (name, callback) => listeners.set(name, callback),
    removeEventListener: name => listeners.delete(name),
    location: { reload: () => reloads++ },
  };
  runInNewContext(source, {
    document: { getElementById: element }, window, navigator: { onLine: online },
    setTimeout: (callback, delay) => { timers.set(delay, callback); return delay; },
    clearTimeout: id => timers.delete(id),
  });
  return { element, listeners, timers, startup: window.AfaqStartup, reloads: () => reloads };
}

test('stages follow real startup callbacks without invented percentages', () => {
  const view = loading();
  view.startup.stage(1);
  assert.equal(view.element('startup-description').textContent, 'Starting your display.');
  assert.equal(view.element('startup-step-0').className, 'is-done');
  assert.equal(view.element('startup-step-1').attributes['aria-current'], 'step');
  view.startup.stage(2);
  assert.equal(view.element('startup-description').textContent, 'Opening your workspace.');
  assert.equal(view.element('startup-step-1').attributes['aria-current'], undefined);
});

test('a stalled start explains the delay and offers manual retry only', () => {
  const view = loading();
  view.timers.get(12000)();
  assert.match(view.element('startup-description').textContent, /first visit/);
  view.timers.get(45000)();
  assert.equal(view.element('startup-retry').hidden, false);
  assert.equal(view.element('app-loading').attributes['aria-busy'], 'false');
  assert.equal(view.reloads(), 0);
  view.element('startup-retry').click();
  assert.equal(view.reloads(), 1);
});

test('offline errors give useful guidance without erasing saved sessions', () => {
  const view = loading(false);
  view.startup.fail();
  assert.match(view.element('startup-title').textContent, /offline/);
  assert.equal(view.reloads(), 0);
});

test('first frame removes loading and cancels timers, including after a timeout', () => {
  const view = loading();
  const lateTimeout = view.timers.get(45000);
  lateTimeout();
  view.listeners.get('flutter-first-frame')();
  assert.equal(view.element('app-loading').removed, true);
  assert.equal(view.timers.size, 0);
  assert.equal(view.listeners.has('error'), false);
  const title = view.element('startup-title').textContent;
  lateTimeout();
  view.startup.stage(1);
  view.element('startup-retry').click();
  assert.equal(view.reloads(), 0);
  assert.equal(view.element('startup-title').textContent, title);
});

test('a failed startup script offers recovery but a missing image does not', () => {
  const view = loading();
  view.listeners.get('error')({ target: { tagName: 'IMG' } });
  assert.equal(view.element('startup-retry').hidden, true);
  view.listeners.get('error')({ target: { tagName: 'SCRIPT' } });
  assert.equal(view.element('startup-retry').hidden, false);
});
