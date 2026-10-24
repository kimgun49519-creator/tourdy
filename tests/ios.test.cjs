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
  assert.doesNotMatch(project,/lastKnownFileType = folder/);
  assert.match(project,/lastKnownFileType = text.json; path = Tourdy\/Resources\/places.json/);
  assert.doesNotMatch(source,/subdirectory: "Resources"/);
  assert.doesNotMatch(source,/WebKit|WKWebView|evaluateJavaScript|URLSession/);
  for(const name of fs.readdirSync(path.join(root,'ios/Tourdy')).filter(x=>x.endsWith('.swift'))){
    assert.ok(project.includes('Tourdy/'+name),name+' is not part of the Xcode project');
    const swift=fs.readFileSync(path.join(root,'ios/Tourdy',name),'utf8');
    assert.doesNotMatch(swift,/import WebKit|WKWebView|evaluateJavaScript|URLSession/);
  }
  const data=JSON.parse(fs.readFileSync(path.join(root,'ios/Tourdy/Resources/places.json'),'utf8'));
  assert.ok(data.filter(p=>p.world==='kr').length>=160);
  assert.ok(data.filter(p=>p.world==='world').length>=190);
  assert.ok(data.filter(p=>p.world==='space').length>20);
  assert.equal(new Set(data.map(p=>p.id)).size,data.length);
  for(const p of data){assert.ok(Number.isFinite(p.latitude)&&Number.isFinite(p.longitude)&&Number.isFinite(p.cost));assert.ok(p.name&&p.id);}
});

test('native maps reuse all domestic city shapes and route stops resolve to bundled places',()=>{
  const dir=path.join(root,'ios/Tourdy/Resources');
  const places=JSON.parse(fs.readFileSync(path.join(dir,'places.json'),'utf8')),ids=new Set(places.map(p=>p.id));
  const atlas=JSON.parse(fs.readFileSync(path.join(dir,'atlas.json'),'utf8'));
  assert.equal(atlas.kr.regions.length,161);
  assert.ok(atlas.world.regions.length>170);
  for(const map of [atlas.kr,atlas.world])for(const region of map.regions){
    assert.ok(region.polygons.length>0,region.id);
    for(const polygon of region.polygons){assert.ok(polygon.length>=3);assert.ok(polygon.every(p=>p.length===2&&p.every(Number.isFinite)));}
  }
  const routes=JSON.parse(fs.readFileSync(path.join(dir,'routes.json'),'utf8'));
  assert.equal(routes.length,18);
  assert.equal(routes.filter(r=>r.season).length,7);
  for(const route of routes)for(const stop of route.stops)assert.ok(ids.has(stop),route.id+': '+stop);
  for(const p of places.filter(p=>p.world!=='space'))assert.ok(atlas.dots[p.id]?.every(Number.isFinite),p.id);
});
