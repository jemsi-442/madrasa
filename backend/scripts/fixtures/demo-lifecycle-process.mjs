import { fork } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { superviseDemo } from '../local-demo-lifecycle.mjs';

if (process.argv[2] === 'worker') {
  const keepAlive = setInterval(() => {}, 1000);
  const stop = signal => {
    process.send({ event: 'stopping', signal });
    setTimeout(() => {
      clearInterval(keepAlive);
      process.send({ event: 'cleaned' }, () => process.disconnect());
    }, 300);
  };
  process.once('SIGINT', () => stop('SIGINT'));
  process.once('SIGTERM', () => stop('SIGTERM'));
  process.send({ event: 'ready', pid: process.pid });
} else {
  const child = fork(fileURLToPath(import.meta.url), ['worker'], {
    env: { NODE_ENV: 'test' }, stdio: ['ignore', 'ignore', 'ignore', 'ipc'],
  });
  superviseDemo(child);
  child.on('message', message => process.send?.(message));
  child.once('exit', () => { if (process.connected) process.disconnect(); });
}
