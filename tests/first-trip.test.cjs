const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const Rewards = require('../js/rewards.js');
const Storage = require('../js/storage.js');
function fixture() {
  const elements = new Map();
  const $ = id => {
    if (!elements.has(id)) elements.set(id, { hidden:false, closeCount:0, close(){this.closeCount++}, appendChild(){}, insertAdjacentElement(){}, querySelector(){return {textContent:''}} });
    return elements.get(id);
  };
  const seed = () => ({ subjects:[],sessions:[],firstTrip:{version:1,status:'ready'},travel:{on:true,at:'KR',km:0,used:17,stamps:[],to:'JP',kr:{home:'seoul',at:'seoul',to:'busan',km:0,path:[],done:[]},sp2:{to:'moon'},routes:{act:{id:'old-route'}}} });
  const data = new Map([['state',JSON.stringify(seed())]]);
  let fail = false;
  const storage = { getItem:k=>data.get(k)??null,setItem(k,v){if(fail)throw new Error('quota');data.set(k,v);} };
  const store = Storage.create({key:'state',getStorage:()=>storage,normalize:s=>s,seed});
  const sandbox = { $,document:{querySelector:()=>$('tabs'),body:$('body')},TourdyRewards:Rewards,S:store.read(),stateStore:store,
    KR:[['seoul','서울','특별시'],['busan','부산','광역시']],KRM:{seoul:['seoul','서울'],busan:['busan','부산']},NATIONS:[['KR','대한민국','서울'],['FR','프랑스','파리']],NAT:{KR:['KR','대한민국','서울'],FR:['FR','프랑스','파리']},
    tr:()=>sandbox.S.travel,worldOpen:t=>t.kr.done.length>=1,kr:t=>t.kr,sp:t=>t.sp2,krKm:()=>325,kmBetween:()=>8965,dk:()=> '2026-10-24',today0:()=>new Date(2026,9,24),
    renderTravel(){},syncTravelTab(){},setTab(){},arrQ(event){sandbox.arrival=event;},
    postArrive(event){(sandbox.S.travel.arrLog||(sandbox.S.travel.arrLog=[])).push(event);},
  };
  vm.createContext(sandbox);vm.runInContext(fs.readFileSync(path.join(__dirname,'../js/first-trip.js'),'utf8'),sandbox);
  return {sandbox,data,$,setFailure:value=>{fail=value},claim:(world,id,origin)=>sandbox.claimFirstTrip(world,id,origin)};
}
test('free world trip atomically persists destination, highest tier and used ticket without spending miles', () => {
  const f=fixture();f.sandbox.S.travel.kr.done.push({c:'busan',d:'2026-10-24'});assert.equal(f.claim('w','FR'),true);
  const saved=JSON.parse(f.data.get('state'));
  assert.equal(saved.firstTrip.status,'used');assert.equal(saved.travel.at,'FR');
  assert.equal(saved.travel.used,17);assert.equal(saved.travel.stamps[0].tier,2);
  assert.equal(saved.travel.log[0].m,0);assert.equal(saved.travel.firstWorldTrip,undefined);
  assert.equal(saved.travel.to,null);assert.equal(saved.travel.kr.to,null);assert.equal(saved.travel.sp2.to,null);assert.equal(saved.travel.routes.act,null);
  assert.equal(f.claim('w','KR'),false);
});
test('domestic gift retains the gold stamp and path with zero mileage spend', () => {
  const f=fixture();assert.equal(f.claim('kr','busan'),true);
  const saved=JSON.parse(f.data.get('state'));
  assert.equal(saved.travel.kr.at,'busan');assert.equal(saved.travel.kr.km,325);
  assert.equal(saved.travel.kr.done[0].tier,2);assert.equal(saved.travel.kr.done[0].free,true);
  assert.equal(saved.travel.used,17);assert.equal(f.sandbox.arrival.cls,1);
});
test('failed save keeps the ticket and original location, and retry succeeds', () => {
  const f=fixture();const original=f.data.get('state');f.setFailure(true);
  assert.equal(f.claim('kr','seoul','busan'),false);assert.equal(f.data.get('state'),original);
  assert.equal(f.sandbox.S.firstTrip.status,'ready');assert.equal(f.sandbox.S.travel.kr.at,'seoul');assert.equal(f.sandbox.S.travel.kr.home,'seoul');
  assert.equal(f.$('firstTripDialog').closeCount,0);assert.equal(f.sandbox.arrival,undefined);
  f.setFailure(false);assert.equal(f.claim('kr','seoul','busan'),true);
});
test('a first reward cannot bypass the domestic completion gate', () => {
  const f=fixture();const original=f.data.get('state');
  f.sandbox.S.travel.firstWorldTrip=true;
  assert.equal(f.claim('w','FR'),false);assert.equal(f.data.get('state'),original);
  assert.equal(f.sandbox.S.firstTrip.status,'ready');
});
test('custom starting city and destination are persisted together with the ticket', () => {
  const f=fixture();assert.equal(f.claim('kr','seoul','busan'),true);
  const saved=JSON.parse(f.data.get('state'));
  assert.equal(saved.travel.kr.home,'busan');assert.equal(saved.travel.kr.at,'seoul');
  assert.equal(saved.travel.kr.done[0].c,'seoul');assert.equal(saved.travel.kr.path[0],'seoul');
  assert.equal(saved.firstTrip.destination.from,'busan');assert.equal(f.sandbox.arrival.f,'busan');
  assert.equal(saved.travel.used,17);
});
test('origin selection rejects identical endpoints, invalid cities and rewriting an existing journey', () => {
  const f=fixture();assert.equal(f.claim('kr','busan','busan'),false);assert.equal(f.claim('kr','busan','missing'),false);
  f.sandbox.S.travel.kr.done.push({c:'busan',d:'2026-10-24'});
  f.sandbox.S.travel.kr.path.push('busan');
  assert.equal(f.claim('kr','seoul','busan'),false);assert.equal(f.sandbox.S.travel.kr.home,'seoul');
  assert.equal(f.sandbox.S.firstTrip.status,'ready');
});
test('production world gate ignores a previously saved firstWorldTrip flag', () => {
  const source=fs.readFileSync(path.join(__dirname,'../js/travel-korea.js'),'utf8');
  const definition=source.match(/const worldOpen=.*?;/)[0];
  const context={KR:[['seoul'],['busan']],kr:t=>t.kr,TRAVEL_TEST:false};
  vm.createContext(context);vm.runInContext(definition+'\nthis.check=worldOpen;',context);
  assert.equal(context.check({firstWorldTrip:true,kr:{done:[]}}),false);
  assert.equal(context.check({kr:{done:[{c:'busan'}]}}),true);
});
test('running study and invalid destinations cannot consume a ticket', () => {
  const f=fixture();assert.equal(f.claim('space','moon'),false);assert.equal(f.claim('w','missing'),false);assert.equal(f.claim('kr','seoul'),false);
  f.sandbox.S.running={kind:'study',start:Date.now()};assert.equal(f.claim('w','FR'),false);assert.equal(f.sandbox.S.firstTrip.status,'ready');
});
