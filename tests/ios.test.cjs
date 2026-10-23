const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const {execFileSync}=require('node:child_process');
const root=path.join(__dirname,'..');
test('iOS build bundles production assets without a server, test mode or remote fonts',()=>{
  execFileSync(process.execPath,[path.join(root,'scripts/build-ios.cjs')]);
  const web=path.join(root,'ios/Tourdy/Web'),html=fs.readFileSync(path.join(web,'index.html'),'utf8');
  assert.doesNotMatch(html,/fonts\.google|src="js\/pwa.js"|test-mode.js/);
  for(const match of html.matchAll(/(?:src|href)="((?:js|css)\/[^\"]+)"/g))assert.ok(fs.existsSync(path.join(web,match[1])),match[1]);
  assert.match(fs.readFileSync(path.join(web,'js/travel-world.js'),'utf8'),/TRAVEL_TEST=false/);
  new vm.Script(fs.readFileSync(path.join(web,'native-bridge.js'),'utf8'));
});
