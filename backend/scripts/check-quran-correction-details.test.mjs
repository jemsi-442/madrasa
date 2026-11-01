import assert from 'node:assert/strict';
import { test } from 'node:test';
import { localPreviewUrl } from './check-quran-correction-details.mjs';

test('browser checks default to debug preview and allow a separate local preview', () => {
  assert.equal(localPreviewUrl().href, 'http://127.0.0.1:8087/');
  assert.equal(localPreviewUrl('http://127.0.0.1:8088').origin, 'http://127.0.0.1:8088');
});

test('browser checks reject remote origins, credentials and non-root URLs', () => {
  for (const url of [
    'https://example.com', 'http://127.0.0.1.example.com',
    'file:///tmp/index.html', 'http://user:password@127.0.0.1:8088',
    'http://127.0.0.1:8088/login', 'http://127.0.0.1:8088/?redirect=remote',
    'http://127.0.0.1:8088/#/login', 'not a URL',
  ]) assert.throws(() => localPreviewUrl(url));
});
