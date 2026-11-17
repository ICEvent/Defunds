import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const source = readFileSync(
  new URL('../src/frontend/src/lib/utils/oisy.js', import.meta.url),
  'utf8'
);
const loginForm = readFileSync(
  new URL('../src/frontend/src/lib/components/LoginForm.svelte', import.meta.url),
  'utf8'
);

test('OISY signer dependencies are imported before the user clicks', () => {
  assert.match(source, /import \{ Signer \} from ['"]@icp-sdk\/signer['"]/);
  assert.match(source, /import \{ PostMessageTransport \} from ['"]@icp-sdk\/signer\/web['"]/);
  assert.match(source, /import \{ SignerAgent \} from ['"]@icp-sdk\/signer\/agent['"]/);
  // Awaiting dynamic imports would consume the browser's transient activation.
  assert.doesNotMatch(source, /\bimport\s*\(/);
});

test('openChannel is the first awaited operation in connectOisy', () => {
  const start = source.indexOf('export async function connectOisy()');
  const end = source.indexOf('export async function disconnectOisy()', start);
  assert.ok(start >= 0 && end > start);
  const body = source.slice(start, end).replace(/\/\/[^\n]*/g, '');
  const awaits = [...body.matchAll(/\bawait\s+([a-zA-Z_][\w.]*)\s*\(/g)];
  assert.ok(awaits.length >= 2, 'OISY must open its channel before querying accounts');
  assert.equal(awaits[0][1], 'signer.openChannel');
  assert.equal(awaits[1][1], 'signer.getAccounts');
});

test('OISY button starts the channel before its click handler first awaits', () => {
  assert.match(loginForm, /on:click=\{\(\) => handleWalletConnect\('oisy'\)\}/);
  const start = loginForm.indexOf('async function handleWalletConnect(provider)');
  const end = loginForm.indexOf('async function handleIILogin()', start);
  assert.ok(start >= 0 && end > start);
  const handler = loginForm.slice(start, end).replace(/\/\/[^\n]*/g, '');
  const connect = handler.indexOf("connectOisy()");
  const firstAwait = handler.indexOf('await ');
  assert.ok(connect >= 0, 'click handler should call connectOisy');
  assert.ok(firstAwait > connect, 'no awaited work may run before connectOisy');
});
