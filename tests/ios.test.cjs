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

test('rapid native tab requests retain the newest selection and reject stale requests',()=>{
  const pending=[],messages=[];
  const tabs=['home','todo','stats','travel','set'].map(id=>({dataset:{tab:id},hidden:false,textContent:id,selected:id==='home',setAttribute(){},getAttribute(){return String(this.selected)},click(){tabs.forEach(el=>el.selected=el===this)}}));
  const context={document:{createElement:()=>({}),head:{appendChild(){}},body:{},querySelectorAll:selector=>selector==='.tabs [data-tab]'?tabs:[]},window:{webkit:{messageHandlers:{tourdySwitches:{postMessage(){}},tourdyTabs:{postMessage:state=>messages.push(state)}}}},MutationObserver:class{observe(){}},addEventListener(){},requestAnimationFrame:fn=>pending.push(fn)};
  vm.createContext(context);vm.runInContext(fs.readFileSync(path.join(root,'ios/native-bridge.js'),'utf8'),context);
  const flush=()=>{while(pending.length)pending.shift()()};flush();
  for(let revision=1;revision<=100;revision++)context.window.tourdyNativeSelectTab(tabs[revision%5].dataset.tab,revision);
  flush();context.window.tourdyNativeSelectTab('set',99);flush();
  const final=messages.at(-1);
  assert.equal(final.revision,100);assert.equal(final.tabs.find(el=>el.on).id,'home');
  assert.equal(tabs.find(el=>el.selected).dataset.tab,'home');
});
