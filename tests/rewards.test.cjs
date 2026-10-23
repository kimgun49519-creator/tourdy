const { test } = require('node:test');
const assert = require('node:assert/strict');
const rewards = require('../js/rewards.js');
const minute = 60000;
const session = (minutes, extra = {}) => ({ kind: 'study', start: 0, end: minutes * minute, ...extra });
const state = () => ({ subjects: [], sessions: [], running: null, firstTrip: { version: 1, status: 'pending' } });
test('10 minutes then 20 minutes earns exactly one ticket after finishing', () => {
  const s = state(); s.sessions.push(session(10));
  assert.equal(rewards.earn(s), false);
  s.sessions.push(session(20));
  assert.equal(rewards.earn(s), true);
  assert.equal(s.firstTrip.status, 'ready');
  assert.equal(rewards.earn(s), false);
});
test('29:59 does not qualify, exactly 30:00 does', () => {
  const s = state(); s.sessions.push(session(30, { end: 30 * minute - 1000 }));
  assert.equal(rewards.earn(s), false);
  s.sessions[0].end += 1000;
  assert.equal(rewards.earn(s), true);
});
test('crossing 30 minutes while still running keeps the reward pending', () => {
  const s = state(); s.sessions.push(session(10));
  s.running = { kind: 'study', start: 1000000 };
  const now = 1000000 + 25 * minute;
  assert.equal(rewards.studyMs(s, now), 35 * minute);
  assert.equal(rewards.earn(s, now), false);
  s.sessions.push(session(25, { start: s.running.start, end: now })); s.running = null;
  assert.equal(rewards.earn(s, now), true);
});
test('reopening an active 35-minute timer never awards prematurely', () => {
  const s = { sessions: [session(10)], running: { kind:'study', start:Date.now()-25*minute } };
  rewards.initialize(s);
  assert.equal(s.firstTrip.status, 'pending');
  const reopened = JSON.parse(JSON.stringify(s));
  rewards.initialize(reopened); assert.equal(rewards.earn(reopened), false);
});
test('rest, distraction, sample records, and manual additions do not qualify', () => {
  const s = state(); s.sessions = [session(60,{kind:'rest'}),session(60,{kind:'waste'}),session(60,{ex:true}),session(60,{manual:true}),session(60,{noMile:true})];
  assert.equal(rewards.studyMs(s), 0);
  assert.equal(rewards.earn(s), false);
});
test('running reservations contribute only until their end', () => {
  const s = state(); s.running = { kind:'study', start:1000, end:1000+10*minute };
  assert.equal(rewards.studyMs(s,1000+60*minute),10*minute);
  assert.equal(rewards.earn(s),false);
});
test('existing completed timer records qualify once and redemption survives reload', () => {
  const s = { sessions:[session(35)] }; rewards.initialize(s);
  assert.equal(s.firstTrip.status,'ready');
  assert.equal(rewards.redeem(s,{world:'w',id:'FR'},123),true);
  const reopened = JSON.parse(JSON.stringify(s)); rewards.initialize(reopened);
  assert.equal(rewards.earn(reopened),false);
  assert.equal(rewards.redeem(reopened,{world:'kr',id:'busan'}),false);
  assert.equal(reopened.firstTrip.destination.id,'FR');
});
