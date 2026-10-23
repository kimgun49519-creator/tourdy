const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {execFileSync}=require('node:child_process');
const root=path.join(__dirname,'..');
test('native iOS target includes SwiftUI and offline destination data without web resources',()=>{
  execFileSync(process.execPath,[path.join(root,'scripts/build-ios.cjs')]);
  const project=fs.readFileSync(path.join(root,'ios/Tourdy.xcodeproj/project.pbxproj'),'utf8');
  const source=fs.readFileSync(path.join(root,'ios/Tourdy/NativeApp.swift'),'utf8');
  assert.match(project,/Tourdy\/NativeApp.swift/);
  assert.doesNotMatch(project,/Tourdy\/Web|TourdyApp.swift/);
  assert.doesNotMatch(source,/WebKit|WKWebView|evaluateJavaScript|URLSession/);
  const data=JSON.parse(fs.readFileSync(path.join(root,'ios/Tourdy/Resources/places.json'),'utf8'));
  assert.ok(data.filter(p=>p.world==='kr').length>=160);
  assert.ok(data.filter(p=>p.world==='world').length>=190);
  assert.ok(data.filter(p=>p.world==='space').length>20);
  assert.equal(new Set(data.map(p=>p.id)).size,data.length);
  for(const p of data){assert.ok(Number.isFinite(p.latitude)&&Number.isFinite(p.longitude)&&Number.isFinite(p.cost));assert.ok(p.name&&p.id);}
});
