const { test } = require('node:test');
const assert = require('node:assert/strict');
const { create, validate } = require('../js/storage.js');
const seed = () => ({ subjects: [], sessions: [], tasks: {}, repeats: [], running: null });
function fixture(entries = {}) {
  const data = new Map(Object.entries(entries));
  const storage = { getItem: key => data.get(key) ?? null, setItem: (key, value) => data.set(key, value) };
  const statuses = [];
  const store = create({ getStorage: () => storage, key: 'state', legacyKey: 'legacy', seed, normalize: value => ({ ...seed(), ...value }), onStatus: status => statuses.push(status.type) });
  return { data, storage, store, statuses };
}
test('first save, read, and previous-good snapshot preserve all existing fields', () => {
  const f = fixture(); const state = f.store.read();
  state.custom = { untouched: true };
  assert.equal(f.store.write(state), true);
  const before = f.data.get('state');
  state.subjects.push({ id: 's1', name: '수학' });
  assert.equal(f.store.write(state), true);
  assert.equal(f.data.get('state.lastGood'), before);
  assert.deepEqual(JSON.parse(f.data.get('state')).custom, { untouched: true });
});
test('quota failure retains the last primary and can be retried', () => {
  const original = JSON.stringify(seed()), f = fixture({ state: original });
  const state = f.store.read(); state.goal = 30;
  const put = f.storage.setItem;
  f.storage.setItem = () => { throw new DOMException('full', 'QuotaExceededError'); };
  assert.equal(f.store.write(state), false);
  assert.equal(f.data.get('state'), original);
  assert.equal(f.store.status().type, 'failed');
  f.storage.setItem = put;
  assert.equal(f.store.write(state), true);
  assert.equal(JSON.parse(f.data.get('state')).goal, 30);
});
test('failure on the primary write still leaves the last valid snapshot', () => {
  const original = JSON.stringify(seed()), f = fixture({ state: original });
  const state = f.store.read(); state.goal = 60;
  const put = f.storage.setItem;
  f.storage.setItem = (key,value) => { if(key==='state')throw new Error('disk');put(key,value); };
  assert.equal(f.store.write(state), false);
  assert.equal(f.data.get('state'), original);
  assert.equal(f.data.get('state.lastGood'), original);
});
test('damaged primary is recovered and retained verbatim', () => {
  const f = fixture({ state: '{broken', 'state.lastGood': JSON.stringify({ ...seed(), goal: 90 }) });
  const state = f.store.read();
  assert.equal(state.goal, 90);
  assert.equal(f.store.status().type, 'recovered');
  assert.equal(f.store.write(state), true);
  assert.equal(f.data.get('state.damaged'), '{broken');
  assert.equal(JSON.parse(f.data.get('state')).goal, 90);
});
test('unrecoverable input is never overwritten with an empty seed', () => {
  const f = fixture({ state: '{broken' }); const state = f.store.read();
  assert.equal(f.store.write(state), false);
  assert.equal(f.data.get('state'), '{broken');
  assert.equal(f.store.status().type, 'damaged');
  assert.equal(f.store.write(state, { replace: true }), true);
  assert.equal(f.data.get('state.damaged'), '{broken');
});
test('a temporarily denied read cannot later overwrite unseen records', () => {
  const f = fixture({ state: JSON.stringify({ ...seed(), goal: 120 }) });
  const get = f.storage.getItem;
  f.storage.getItem = () => { throw new DOMException('denied', 'SecurityError'); };
  const state = f.store.read();
  f.storage.getItem = get;
  assert.equal(f.store.write(state), false);
  assert.equal(JSON.parse(f.data.get('state')).goal, 120);
});
test('stale tab writes are refused without losing either state', () => {
  const f = fixture({ state: JSON.stringify(seed()) }); const state = f.store.read();
  const changedElsewhere = JSON.stringify({ ...seed(), goal: 180 });
  f.data.set('state', changedElsewhere); state.goal = 30;
  assert.equal(f.store.write(state), false);
  assert.equal(f.store.status().type, 'conflict');
  assert.equal(f.data.get('state'), changedElsewhere);
  assert.equal(state.goal, 30);
});
test('legacy state migrates without deleting its original key', () => {
  const original = JSON.stringify({ subjects: [], goal: 45 });
  const f = fixture({ legacy: original }); const state = f.store.read();
  assert.equal(f.store.write(state), true);
  assert.equal(f.data.get('legacy'), original);
  assert.equal(JSON.parse(f.data.get('state')).goal, 45);
});
test('invalid session times and malformed containers are rejected', () => {
  for (const bad of [null, { subjects: 'bad' }, { subjects: [], sessions: {} }, { ...seed(), sessions: [{ start: 10, end: 1 }] }, { ...seed(), running: { start: NaN } }, { ...seed(), tasks: { day: {} } }]) {
    assert.throws(() => validate(bad));
  }
});
