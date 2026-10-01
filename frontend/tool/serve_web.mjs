import { createServer } from 'node:http';
import { createReadStream } from 'node:fs';
import { readFile, realpath, stat } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { dirname, resolve, sep } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const contentTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json',
  '.css': 'text/css; charset=utf-8',
  '.wasm': 'application/wasm',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
};

function recoveryPage(buildId) {
  return `<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Refresh the local school preview</title>
<style>body{margin:0;background:#fcfaf6;color:#092136;font:18px Georgia,serif;display:grid;min-height:100vh;place-items:center}main{max-width:32rem;padding:2rem}h1{font-size:2rem}p{line-height:1.6}a{color:#705019}</style>
<main><h1>Opening the latest preview</h1>
<p id="status" role="status">Checking the old Flutter offline worker. Your login and records will not be cleared.</p>
<small>Local build: ${buildId}</small>
<noscript><p>Enable JavaScript, then reload this page.</p></noscript></main>
<script>
(async () => {
  try {
    if ('serviceWorker' in navigator) {
      const registrations = await navigator.serviceWorker.getRegistrations();
      for (const registration of registrations) {
        const worker = registration.active || registration.waiting || registration.installing;
        if (!worker) continue;
        const url = new URL(worker.scriptURL);
        if (registration.scope === location.origin + '/' &&
            url.origin === location.origin && url.pathname === '/flutter_service_worker.js') {
          await registration.unregister();
        }
      }
    }
    // A new navigation releases the old controller; no cookies or storage are cleared.
    location.replace('/?preview=${buildId}#/');
  } catch (_) {
    document.getElementById('status').textContent =
      'The browser could not refresh the old worker. Close other school preview tabs and reload this page, or open the preview in a private window.';
  }
})();
</script></html>`;
}

export async function createPreviewServer(directory) {
  const root = await realpath(directory);
  const mainPath = resolve(root, 'main.dart.js');
  await Promise.all([stat(resolve(root, 'index.html')), stat(mainPath)]);
  let fingerprint, buildId;
  async function currentBuild() {
    const info = await stat(mainPath);
    const next = `${info.size}:${info.mtimeMs}:${info.ctimeMs}`;
    if (fingerprint !== next) {
      buildId = createHash('sha256').update(await readFile(mainPath)).digest('hex').slice(0, 12);
      fingerprint = next;
    }
    return buildId;
  }

  return createServer(async (request, response) => {
    response.setHeader('Cache-Control', 'no-store, max-age=0');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    const send = (status, body, type = 'text/plain; charset=utf-8') => {
      response.writeHead(status, {
        'Content-Type': type,
        'Content-Length': Buffer.byteLength(body),
      });
      response.end(request.method === 'HEAD' ? undefined : body);
    };
    if (!['GET', 'HEAD'].includes(request.method)) {
      response.setHeader('Allow', 'GET, HEAD');
      send(405, 'Read-only local preview');
      return;
    }
    try {
      const url = new URL(request.url, 'http://127.0.0.1');
      let pathname;
      try {
        pathname = decodeURIComponent(url.pathname);
      } catch {
        send(400, 'Invalid path');
        return;
      }
      if (pathname.includes('\0') || pathname.includes('\\') ||
          pathname.split('/').some(part => part.startsWith('.'))) {
        send(404, 'Not found');
        return;
      }
      if (pathname === '/__preview__/refresh') {
        response.setHeader('Content-Security-Policy', "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'");
        send(200, recoveryPage(await currentBuild()), 'text/html; charset=utf-8');
        return;
      }
      if (pathname === '/__preview__/version') {
        send(200, JSON.stringify({ build: await currentBuild() }), 'application/json');
        return;
      }
      const file = await realpath(resolve(root, `.${pathname === '/' ? '/index.html' : pathname}`));
      if (!file.startsWith(root + sep)) {
        send(404, 'Not found');
        return;
      }
      const info = await stat(file);
      if (!info.isFile()) {
        send(404, 'Not found');
        return;
      }
      const type = contentTypes[file.slice(file.lastIndexOf('.'))] || 'application/octet-stream';
      if (pathname === '/' || pathname === '/index.html' || pathname === '/flutter_bootstrap.js') {
        const id = await currentBuild();
        let body = await readFile(file, 'utf8');
        // Version both scripts so an old HTTP cache cannot supply the previous app.
        body = pathname === '/flutter_bootstrap.js'
          ? body.replace(/"mainJsPath"\s*:\s*"main\.dart\.js"/g, `"mainJsPath":"main.dart.js?v=${id}"`)
          : body.replace('src="flutter_bootstrap.js"', `src="flutter_bootstrap.js?v=${id}"`);
        response.setHeader('X-Preview-Build', id);
        send(200, body, type);
        return;
      }
      response.writeHead(200, { 'Content-Type': type, 'Content-Length': info.size });
      if (request.method === 'HEAD') response.end();
      else createReadStream(file).on('error', () => response.destroy()).pipe(response);
    } catch (error) {
      if (response.headersSent) response.destroy();
      else send(['ENOENT', 'ENOTDIR', 'EACCES'].includes(error.code) ? 404 : 500, 'Preview file unavailable');
    }
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const directory = process.argv[2] || resolve(dirname(fileURLToPath(import.meta.url)), '../build/web');
  const port = Number(process.argv[3] || 8080);
  try {
    if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Invalid port');
    const server = await createPreviewServer(directory);
    server.on('error', error => {
      console.error(`Could not start local preview (${error.code || error.message}). Stop the existing preview before retrying.`);
      process.exitCode = 1;
    });
    server.listen(port, '127.0.0.1', () => {
      console.log(`School preview: http://127.0.0.1:${port}/`);
      console.log(`Old pages? Open http://127.0.0.1:${port}/__preview__/refresh`);
    });
  } catch (error) {
    console.error(`Local preview unavailable (${error.code || error.message}). Build Flutter web first.`);
    process.exitCode = 1;
  }
}
