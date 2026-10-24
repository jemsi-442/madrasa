import { constants } from 'node:os';

export function superviseDemo(child, parent = process, report = console.error) {
  let stopping = false;
  const forward = signal => {
    if (stopping) return;
    stopping = true;
    child.kill(signal);
  };
  const interrupt = () => forward('SIGINT');
  const terminate = () => forward('SIGTERM');
  parent.on('SIGINT', interrupt);
  parent.on('SIGTERM', terminate);
  const detach = () => {
    parent.off('SIGINT', interrupt);
    parent.off('SIGTERM', terminate);
  };
  child.once('error', () => {
    detach();
    report('Could not start the disposable demo. Details redacted.');
    parent.exitCode = 1;
  });
  child.once('exit', (code, signal) => {
    detach();
    parent.exitCode = code ?? (signal ? 128 + (constants.signals[signal] ?? 1) : 1);
  });
}
