const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path');
const {build}=require('../scripts/build-capacitor.cjs');
const root=path.resolve(__dirname,'..');
test('installed app bundles the original markup, styling, data and script order',async()=>{
  await build();
  const original=fs.readFileSync(path.join(root,'index.html'),'utf8');
  const scripts=[];
  const expected=original.replace(/<script src="(js\/[^\"]+)"><\/script>/g,(_,src)=>{if(src!=='js/pwa.js')scripts.push(src);return '';})
    .replace(/<link[^>]+(?:fonts\.googleapis\.com|fonts\.gstatic\.com)[^>]*>/g,'');
  const actual=fs.readFileSync(path.join(root,'native-dist/index.html'),'utf8');
  const bootstrap='<script>window.TOURDY_APP_SCRIPTS='+JSON.stringify(scripts)+'</script><script src="native/bridge.js"></script>';
  assert.equal(actual.replace(bootstrap,''),expected);
  assert.ok(!scripts.includes('js/pwa.js'));
  for(const file of ['css/app.css',...scripts])assert.deepEqual(fs.readFileSync(path.join(root,'native-dist',file)),fs.readFileSync(path.join(root,file)));
  const config=JSON.parse(fs.readFileSync(path.join(root,'capacitor.config.json'),'utf8'));
  assert.equal(config.server,undefined);
  const native=fs.readFileSync(path.join(root,'capacitor/ios/App/App/SceneDelegate.swift'),'utf8');
  assert.match(native,/TourdyTabsViewController\(\)/);
  const tabs=fs.readFileSync(path.join(root,'native/ios/TourdyGlassBar.swift'),'utf8');
  assert.match(tabs,/TabView\(selection:/);
  assert.doesNotMatch(tabs,/\.glassEffect\(|\.ultraThinMaterial|Capsule\(\)/);
});
