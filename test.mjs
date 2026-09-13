import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { register } from './index.mjs';
import { NoveltyStore, fingerprint } from './store.mjs';

// An isolated fake delivery transport that reproduces the host's real sequence:
//   message_sending  (may cancel)  ->  transport attempt  ->  message_sent(success)
// Calling the hooks in isolation hid the defects this harness catches: a plugin can pass
// every isolated test and still remember messages that were never delivered.
function harness({ blockRepeats = false, pluginConfig = {} } = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'lembra-spike-'));
  const hooks = new Map();
  const api = {
    // NOTE: the host supplies plugin settings on `pluginConfig`, not `config`.
    // `config` is populated here with decoys so a regression to it fails loudly.
    config: { dbPath: join(dir, 'WRONG.db'), blockRepeats: !blockRepeats },
    pluginConfig: { dbPath: join(dir, 's.db'), blockRepeats, ...pluginConfig },
    logger: { info() {} },
    on: (name, fn) => hooks.set(name, fn),
  };
  const handle = register(api);
  const delivered = [];

  // deliver(): what the host does around the hooks.
  async function deliver(content, ctx, { transportSucceeds = true } = {}) {
    const decision = await hooks.get('message_sending')({ to: 'peer', content }, ctx);
    if (decision?.cancel === true) return { outcome: 'cancelled', reason: decision.cancelReason };
    const success = transportSucceeds;
    if (success) delivered.push(content);
    hooks.get('message_sent')(
      { to: 'peer', content, success, messageId: `m${delivered.length}`,
        ...(success ? {} : { error: undefined }) },   // a failure WITHOUT an error string
      ctx);
    return { outcome: success ? 'delivered' : 'failed' };
  }
  return { hooks, deliver, delivered, cleanup: () => { handle?.stop?.(); rmSync(dir, { recursive: true, force: true }); } };
}

const CTX = { channelId: 'chan-1', accountId: 'acct-1', sessionKey: 'sess-1' };

test('plugin settings are read from pluginConfig, not the host config', async () => {
  // If the plugin reads api.config it opens WRONG.db and inverts blockRepeats, so this cancels.
  const h = harness({ blockRepeats: false });
  try {
    await h.deliver('Settings probe.', CTX);
    const second = await h.deliver('Settings probe.', CTX);
    assert.equal(second.outcome, 'delivered', 'advisory default came from pluginConfig');
  } finally { h.cleanup(); }
});

test('a delivered message is remembered; a repeat of it is caught', async () => {
  const h = harness({ blockRepeats: true });
  try {
    assert.equal((await h.deliver('The value is 12.', CTX)).outcome, 'delivered');
    const again = await h.deliver('The value is 12.', CTX);
    assert.equal(again.outcome, 'cancelled');
    assert.equal(again.reason, 'lembra:exact_repeat');
  } finally { h.cleanup(); }
});

test('a FAILED delivery with no error string is never remembered', async () => {
  // The regression this pins: the event carries success:false and no `error`, so a plugin
  // checking `event.ok === false` or `event.error` records an undelivered message as said.
  const h = harness({ blockRepeats: true });
  try {
    assert.equal((await h.deliver('Never arrived.', CTX, { transportSucceeds: false })).outcome, 'failed');
    assert.equal((await h.deliver('Never arrived.', CTX)).outcome, 'delivered',
                 'the failed send must not have been remembered');
    assert.deepEqual(h.delivered, ['Never arrived.']);
  } finally { h.cleanup(); }
});

test('a cancelled message is never remembered, so it can be sent later', async () => {
  const h = harness({ blockRepeats: true });
  try {
    await h.deliver('Once.', CTX);
    assert.equal((await h.deliver('Once.', CTX)).outcome, 'cancelled');
    assert.equal((await h.deliver('Once.', CTX)).outcome, 'cancelled', 'cancelling is idempotent');
    assert.deepEqual(h.delivered, ['Once.'], 'exactly one delivery recorded');
  } finally { h.cleanup(); }
});

test('two sessionless accounts on different channels do not share memory', async () => {
  // Both lack accountId. Keyed on accountId alone they collide; channelId separates them.
  const h = harness({ blockRepeats: true });
  try {
    await h.deliver('Shared phrase.', { channelId: 'chan-A' });
    assert.equal((await h.deliver('Shared phrase.', { channelId: 'chan-B' })).outcome, 'delivered');
    assert.equal((await h.deliver('Shared phrase.', { channelId: 'chan-A' })).outcome, 'cancelled');
  } finally { h.cleanup(); }
});

test('memory spans sessions on one account, because repetition does', async () => {
  const h = harness({ blockRepeats: true });
  try {
    await h.deliver('Across sessions.', { ...CTX, sessionKey: 'sess-1' });
    const other = await h.deliver('Across sessions.', { ...CTX, sessionKey: 'sess-2' });
    assert.equal(other.outcome, 'cancelled', 'a repeat in a new session is still a repeat');
  } finally { h.cleanup(); }
});

test('different accounts on one channel stay isolated', async () => {
  const h = harness({ blockRepeats: true });
  try {
    await h.deliver('Per-account.', { channelId: 'chan-1', accountId: 'a' });
    assert.equal((await h.deliver('Per-account.', { channelId: 'chan-1', accountId: 'b' })).outcome,
                 'delivered');
  } finally { h.cleanup(); }
});

test('no channelId means no memory, never a shared namespace', async () => {
  const h = harness({ blockRepeats: true });
  try {
    await h.deliver('Anonymous.', {});
    assert.equal((await h.deliver('Anonymous.', {})).outcome, 'delivered');
  } finally { h.cleanup(); }
});

test('a broken store degrades to advisory instead of blocking delivery', async () => {
  const hooks = new Map();
  register({ pluginConfig: { dbPath: ':memory:' }, logger: { info() {} }, on: (n, f) => hooks.set(n, f) });
  const broken = { get content() { throw new Error('unreadable'); } };
  assert.equal(await hooks.get('message_sending')(broken, CTX), undefined);
});

test('normalization is conservative: numbers and negation still differ', () => {
  assert.equal(fingerprint('The value is 12.'), fingerprint(' The  value\nis 12. '));
  assert.notEqual(fingerprint('The value is 12.'), fingerprint('The value is 13.'));
  assert.notEqual(fingerprint('The value is 12.'), fingerprint('The value is not 12.'));
  assert.equal(fingerprint('   '), null);
});

test('CJK and accented text round-trip through the fingerprint', () => {
  assert.equal(fingerprint('状態のリークはどこで検出しますか？'),
               fingerprint(' 状態のリークはどこで検出しますか？ '));
  assert.notEqual(fingerprint('A memória mantém o contexto.'), fingerprint('A memoria mantem o contexto.'));
});

test('the store survives reopening the same file', () => {
  const dir = mkdtempSync(join(tmpdir(), 'lembra-spike-'));
  try {
    const path = join(dir, 'p.db');
    const a = new NoveltyStore(path);
    a.record('ns', 'Durable.', { messageId: 'm9' });
    a.close();
    const b = new NoveltyStore(path);
    assert.equal(b.check('ns', 'Durable.').status, 'exact_repeat');
    assert.equal(b.check('ns', 'Durable.').messageId, 'm9');
    b.close();
  } finally { rmSync(dir, { recursive: true, force: true }); }
});
