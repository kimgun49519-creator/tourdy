const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.join(__dirname,'..');
const Storage=require('../js/storage.js');

test('every installed shell file can be reopened with the network unavailable',async()=>{
  const handlers={},files=new Map();let offline=false,networkCalls=0;
  const base='https://offline.test/tourdy/';
  const cache={async addAll(requests){for(const request of requests){const url=new URL(request.url);const file=url.pathname.replace('/tourdy/','')||'index.html';files.set(url.href,fs.readFileSync(path.join(root,file),'utf8'));}},async match(request){const key=new URL(typeof request==='string'?request:request.url,base);key.search='';return files.get(key.href);}};
  const context={self:{addEventListener:(k,f)=>handlers[k]=f},location:{origin:new URL(base).origin},URL,Request:class{constructor(url){this.url=new URL(url,base).href;}},Response,caches:{open:async()=>cache},fetch:async()=>{networkCalls++;throw Error(offline?'offline':'unexpected network');}};
  vm.runInNewContext(fs.readFileSync(path.join(root,'sw.js'),'utf8'),context);
  let installed;handlers.install({waitUntil:p=>installed=p});await installed;offline=true;
  assert.ok(files.size>20);
  for(const url of files.keys()){
    let response;handlers.fetch({request:{url,method:'GET',mode:url===base?'navigate':'cors'},respondWith:p=>response=p});
    assert.ok(await response,url);
  }
  assert.equal(networkCalls,0);
});

for(const mode of ['domestic','world','space'])test(`${mode} arrival spends miles and retains its stamp after an offline reopen`,()=>{
  const sources={domestic:['travel-korea.js','checkKorea'],world:['travel-world.js','checkEarth'],space:['travel-space.js','checkSpace']};
  const [file,name]=sources[mode],source=fs.readFileSync(path.join(root,'js',file),'utf8');
  const start=source.indexOf('function '+name+'('),end=source.indexOf('\n}',start)+2;
  const state={subjects:[],sessions:[],travel:{on:true,used:0,at:'KR',to:mode==='world'?'JP':null,km:0,stamps:[],kr:{at:'seoul',home:'seoul',to:mode==='domestic'?'busan':null,km:0,done:[],path:[],cls:1},sp2:{at:'earth',to:mode==='space'?'moon':null,done:[]}}};
  const data=new Map(),storage={getItem:k=>data.get(k)??null,setItem:(k,v)=>data.set(k,v)};
  const store=Storage.create({key:'offline',getStorage:()=>storage,seed:()=>state,normalize:s=>s});
  let current=store.read();
  const context={tr:()=>current.travel,kr:t=>t.kr,sp:t=>t.sp2,KRM:{busan:['busan']},SPX:{moon:['moon','달',0,0,30]},SECKM:{},SECWM:{},totalMiles:()=>100,krTC:()=>30,wTC:()=>30,krKm:()=>325,kmBetween:()=>1000,goldLeg:()=>false,dk:()=> '2026-10-24',today0:()=>new Date(),spDone:(p,id)=>p.done.some(d=>d.c===id),postArrive(){},arrQ(){},save:()=>store.write(current),fetch(){throw Error('network unavailable');}};
  vm.createContext(context);vm.runInContext(source.slice(start,end),context);
  assert.equal(context[name](),true);
  const reopened=Storage.create({key:'offline',getStorage:()=>storage,seed:()=>{throw Error('must retain records')},normalize:s=>s}).read();
  const destination=mode==='domestic'?'busan':mode==='world'?'JP':'moon';
  const trip=mode==='domestic'?reopened.travel.kr:mode==='space'?reopened.travel.sp2:reopened.travel;
  assert.equal(trip.at,destination);assert.equal(trip.to,null);assert.equal(reopened.travel.used,30);
  assert.equal((mode==='world'?trip.stamps:trip.done)[0].c,destination);
  current=reopened;assert.equal(context[name](),false);assert.equal(current.travel.used,30);
});
