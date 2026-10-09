import { spawn } from 'node:child_process';
import { watch } from 'node:fs';
import { createInterface } from 'node:readline';
import { fileURLToPath, pathToFileURL } from 'node:url';

// Serialize saves while Flutter is compiling; never fall back to a state-losing restart.
export class AutoReload {
  constructor(send, report = console.log, delay = 700) {
    Object.assign(this, { send, report, delay, nextId: 0, pending: false });
  }
  changed() {
    this.pending = true;
    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.flush(), this.delay);
  }
  flush() {
    if (!this.ready || !this.appId || this.inFlight || !this.pending) return;
    this.pending = false;
    this.inFlight = ++this.nextId;
    this.send({ id: this.inFlight, method: 'app.restart', params: {
      appId: this.appId, fullRestart: false, pause: false,
      reason: 'Saved Dart source',
    } });
  }
  message(message) {
    if (message.event === 'app.start') this.appId = message.params.appId;
    if (message.event === 'app.started') {
      this.ready = true;
      this.report('Afaq auto reload ready. Save a Dart file to update the open app.');
      this.flush();
    }
    if (this.inFlight && message.id === this.inFlight) {
      this.inFlight = null;
      if (message.error || (message.result?.code ?? 0) !== 0) {
        this.report('Reload was not applied. Fix compilation errors and save again; no automatic restart.');
      } else {
        this.report('Reload completed.');
      }
      this.flush();
    }
  }
  close() { clearTimeout(this.timer); }
}

function main() {
  const cwd = fileURLToPath(new URL('../frontend/', import.meta.url));
  const port = process.env.WEB_PORT ?? '8087';
  const api = process.env.API_BASE_URL ?? 'http://127.0.0.1:4000';
  if (!/^\d+$/.test(port) || +port < 1024 || +port > 65535) throw new Error('Invalid WEB_PORT');
  const parsed = new URL(api);
  if (!['http:', 'https:'].includes(parsed.protocol) || parsed.username || parsed.password) {
    throw new Error('API_BASE_URL must be an HTTP(S) URL without credentials');
  }
  const flutter = spawn(process.env.FLUTTER_BIN ?? 'flutter', [
    'run', '-d', 'web-server', '--machine', '--web-hostname=127.0.0.1',
    `--web-port=${port}`, '--no-web-resources-cdn',
    `--dart-define=API_BASE_URL=${api}`,
  ], { cwd, stdio: ['pipe', 'pipe', 'inherit'] });
  const reload = new AutoReload(message => flutter.stdin.write(`${JSON.stringify([message])}\n`));
  const watcher = watch(new URL('../frontend/lib/', import.meta.url), { recursive: true }, (_event, file) => {
    if (file?.endsWith('.dart')) reload.changed();
  });
  const lines = createInterface({ input: flutter.stdout });
  lines.on('line', line => {
    let messages;
    try { messages = JSON.parse(line); } catch { console.log(line); return; }
    if (!Array.isArray(messages)) return;
    for (const message of messages) {
      reload.message(message);
      if (message.event === 'app.log') console.log(message.params.log);
      if (message.event === 'app.progress' && message.params.message) console.log(message.params.message);
      if (message.error) console.error(message.error);
    }
  });
  const stop = () => { watcher.close(); reload.close(); flutter.kill('SIGTERM'); };
  watcher.on('error', error => { console.error(error.message); stop(); process.exitCode = 1; });
  flutter.on('error', error => { console.error(error.message); watcher.close(); reload.close(); process.exitCode = 1; });
  flutter.on('exit', code => { watcher.close(); reload.close(); lines.close(); process.exitCode = code ?? 0; });
  process.once('SIGINT', stop);
  process.once('SIGTERM', stop);
  console.log(`Afaq development preview: http://127.0.0.1:${port}/#/login`);
  console.log('Initial compilation takes time. Later Dart saves use incremental hot reload.');
  console.log('Asset, dependency and web-shell changes require restarting this command.');
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
