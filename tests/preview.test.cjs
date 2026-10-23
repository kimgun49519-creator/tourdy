const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const { buildPreview, buildInline } = require('../scripts/build-preview.cjs');
test('test preview bundles the actual app, enables test controls and uses memory only', () => {
  const html=buildPreview();
  assert.ok(html.includes('const TRAVEL_TEST=true'));
  assert.ok(html.includes('TOURDY_TEST_STORAGE'));
  assert.ok(html.includes('30분 넘김 · 공부 중'));
  assert.equal(/\blocalStorage\b/.test(html),false);
  assert.equal(html.includes("navigator.serviceWorker.register"),false);
  assert.equal(/<script src=/.test(html),false);
  for(const match of html.matchAll(/<script>([\s\S]*?)<\/script>/g))new vm.Script(match[1]);
  const production=fs.readFileSync(path.join(__dirname,'../index.html'),'utf8');
  assert.equal(production.includes('js/test-mode.js'),false);
  assert.ok(fs.readFileSync(path.join(__dirname,'../js/travel-world.js'),'utf8').includes('const TRAVEL_TEST=false'));
});
test('inline viewer is a sandboxed fragment below one megabyte', () => {
  const inline=buildInline(buildPreview());
  assert.ok(inline.startsWith('<div id="tourdy-test-viewer">'));
  assert.ok(inline.includes('sandbox="allow-scripts allow-modals allow-downloads"'));
  assert.ok(!inline.includes('allow-same-origin'));
  assert.ok(Buffer.byteLength(inline)<1000000);
  for(const match of inline.matchAll(/<script>([\s\S]*?)<\/script>/g))new vm.Script(match[1]);
});
