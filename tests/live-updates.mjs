#!/usr/bin/env node
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import vm from 'node:vm';
import { enmannerLiveUpdates, browserBridge } from '../integration/adapters/vite-live-updates.mjs';

// Reuse the example's locked Vite dependency; npm ci there before this test.
const { createServer } = await import('../examples/vite-example/node_modules/vite/dist/node/index.js');
const root = await mkdtemp(join(tmpdir(), 'Enmanner Live Updates With Spaces '));
const stateFile = join(root, 'state.json');
let server;
let socket;
try {
  process.env.ENMANNER_LIVE_UPDATES_FILE = stateFile;
  const setState = (paused, revision) => writeFile(stateFile, JSON.stringify({ paused, revision }));
  await setState(false, 0);
  await writeFile(join(root, 'index.html'), '<html><head></head><body><script type="module" src="/main.js"></script></body></html>');
  await writeFile(join(root, 'style.css'), 'body { color: black; }');
  await writeFile(join(root, 'main.js'), 'import "./style.css"; document.body.dataset.version = "one";');
  server = await createServer({ root, configFile: false, logLevel: 'silent', plugins: [enmannerLiveUpdates()], server: { host: '127.0.0.1', port: 0 } });
  await server.listen();
  const url = `http://127.0.0.1:${server.httpServer.address().port}`;
  assert.match(await (await fetch(url)).text(), /browserBridge/);
  await fetch(`${url}/main.js`);
  await fetch(`${url}/style.css`);
  assert.equal(JSON.parse(await readFile(`${stateFile}.ack`, 'utf8')).adapter, 'vite');
  const messages = [];
  socket = new WebSocket(url.replace('http:', 'ws:'), 'vite-hmr');
  socket.addEventListener('message', e => messages.push(JSON.parse(e.data)));
  await new Promise((resolve, reject) => { socket.addEventListener('open', resolve); socket.addEventListener('error', reject); });
  const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
  await sleep(100);
  messages.length = 0;
  await setState(true, 0);
  for (let i = 0; i < 8; i++) {
    await writeFile(join(root, 'main.js'), `document.body.dataset.version = "${i}";`);
    await sleep(60);
  }
  await writeFile(join(root, 'style.css'), 'body { color: red; }');
  await writeFile(join(root, 'index.html'), '<html><head></head><body>Latest HTML<script type="module" src="/main.js"></script></body></html>');
  server.ws.send({ type: 'error', err: { message: 'incomplete edit' } });
  server.ws.send({ type: 'full-reload', path: '*' });
  server.ws.send({ type: 'custom', event: 'application-event', data: {} });
  await sleep(250);
  assert.deepEqual(messages.map(m => m.type), ['custom']);
  assert.deepEqual(await (await fetch(`${url}/__enmanner_live_updates`)).json(), { paused: true, revision: 0 });
  await setState(false, 1);
  assert.deepEqual(await (await fetch(`${url}/__enmanner_live_updates`)).json(), { paused: false, revision: 1 });
  server.ws.send({ type: 'full-reload', path: '*' });
  await sleep(100);
  assert.equal(messages.at(-1).type, 'full-reload');
  assert.match(await (await fetch(`${url}/main.js`)).text(), /"7"/);
  await setState(true, 1);
  await server.restart();
  assert.deepEqual(await (await fetch(`${url}/__enmanner_live_updates`)).json(), { paused: true, revision: 1 });

  // Execute the actual injected bridge with browser event semantics and a
  // controllable network: protect close/reconnect and reload exactly once.
  let reloads = 0;
  let current = { paused: true, revision: 0 };
  const scheduled = [];
  class Socket extends EventTarget { constructor() { super(); } }
  const context = vm.createContext({
    window: { WebSocket: Socket, location: { reload: () => reloads++ } },
    fetch: async () => ({ ok: true, json: async () => current }),
    setTimeout: callback => scheduled.push(callback),
  });
  vm.runInContext(`(${browserBridge.toString()})("/state", {paused:true,revision:0})`, context);
  const vite = new context.window.WebSocket('ws://local', 'vite-hmr');
  const application = new context.window.WebSocket('ws://local', 'app');
  vite.dispatchEvent(new Event('open'));
  const failedConnection = new context.window.WebSocket('ws://local', 'vite-hmr');
  let fallbackClose = false;
  failedConnection.addEventListener('close', () => { fallbackClose = true; });
  failedConnection.dispatchEvent(new Event('close'));
  assert.equal(fallbackClose, true);
  let delivered = 0;
  vite.addEventListener('message', () => delivered++);
  vite.dispatchEvent(new MessageEvent('message', { data: JSON.stringify({ type: 'update' }) }));
  assert.equal(delivered, 0);
  let closed = 0;
  vite.addEventListener('close', () => closed++);
  application.addEventListener('close', () => closed++);
  vite.dispatchEvent(new Event('close'));
  assert.equal(closed, 0);
  application.dispatchEvent(new Event('close'));
  assert.equal(closed, 1);
  await scheduled.shift()();
  assert.equal(reloads, 0);
  current = { paused: false, revision: 1 };
  await scheduled.shift()();
  assert.equal(reloads, 1);
  assert.equal(scheduled.length, 0);

  delete process.env.ENMANNER_LIVE_UPDATES_FILE;
  assert.equal(enmannerLiveUpdates().transformIndexHtml.handler(), undefined);
  console.log('Live updates: real Vite source edits, pause, resume, bridge reconnect, application sockets, and opt-out passed.');
} finally {
  socket?.close();
  await server?.close();
  await rm(root, { recursive: true, force: true });
}
