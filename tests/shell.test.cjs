const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const root=path.join(__dirname,'..');
const html=fs.readFileSync(path.join(root,'index.html'),'utf8');
const sw=fs.readFileSync(path.join(root,'sw.js'),'utf8');
const assets=[...html.matchAll(/(?:src|href)="((?:js|css)\/[^\"]+)"/g)].map(m=>m[1]);
test('all extracted app scripts and styles exist and belong to the offline shell', () => {
  assert.ok(assets.length>=16);
  for(const asset of assets){assert.ok(fs.existsSync(path.join(root,asset)),asset);assert.ok(sw.includes("'./"+asset+"'"),asset+' missing offline');if(asset.endsWith('.js'))new vm.Script(fs.readFileSync(path.join(root,asset),'utf8'),{filename:asset});}
  assert.equal(/<script>([\s\S]+?)<\/script>/.test(html),false);
});
test('offline shell returns cached HTML and scripts without a network call', async () => {
  const handlers={},cached={ok:true,release:'v5'};let fetches=0;
  const context={self:{addEventListener:(name,fn)=>handlers[name]=fn},URL,location:{origin:'https://example.test'},caches:{open:async()=>({match:async()=>cached})},fetch:async()=>{fetches++;throw new Error('offline')},Response};
  vm.runInNewContext(sw,context);
  for(const request of [{url:'https://example.test/tourdy/',method:'GET',mode:'navigate'},{url:'https://example.test/tourdy/js/core.js',method:'GET',mode:'cors'}]){
    let result;handlers.fetch({request,respondWith:r=>result=r,waitUntil(){}});assert.equal(await result,cached);
  }
  assert.equal(fetches,0);
});
test('activation removes only TOURDY releases and preserves unrelated caches', async () => {
  const handlers={},deleted=[];
  const context={self:{addEventListener:(n,f)=>handlers[n]=f,clients:{claim:async()=>{}}},caches:{keys:async()=>['toury-v4','tourdy-v3','tourdy-v7','planner-fonts','another-app'],delete:async key=>{deleted.push(key)}},URL};
  vm.runInNewContext(sw,context);let result;handlers.activate({waitUntil:r=>result=r});await result;
  assert.deepEqual(deleted,['toury-v4','tourdy-v3']);
});
