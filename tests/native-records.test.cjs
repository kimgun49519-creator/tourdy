const {test}=require('node:test');
const assert=require('node:assert/strict');
const {create}=require('../js/storage.js');
const {createFileRecords}=require('../native/file-records.cjs');
const {timerNotifications}=require('../native/notifications.cjs');
const seed=()=>({subjects:[],sessions:[],tasks:{},repeats:[],running:null});
function fixture(){
  let disk=null,fail=false;
  const plugin={async commit({expected,data}){if(fail)throw Error('disk full');if(expected!==disk)throw Object.assign(Error('conflict'),{code:'CONFLICT'});disk=data;}};
  const records=createFileRecords(plugin,null);
  const store=create({key:'studyplanner.v2',getStorage:()=>records.storage,commitBatch:records.commit,seed,normalize:x=>x});
  store.read();
  return {store,records,get disk(){return disk;},set fail(x){fail=x;},external(){disk='changed externally';}};
}
test('queued file commits capture each snapshot and preserve previous good records',async()=>{
  const f=fixture(),state=seed();state.goal=30;
  const first=f.store.writeAsync(state);state.goal=60;
  const second=f.store.writeAsync(state);state.goal=90;
  assert.equal(f.records.storage.getItem('studyplanner.v2'),null);
  assert.deepEqual(await Promise.all([first,second]),[true,true]);
  const records=JSON.parse(f.disk).records;
  assert.equal(JSON.parse(records['studyplanner.v2']).goal,60);
  assert.equal(JSON.parse(records['studyplanner.v2.lastGood']).goal,30);
});
test('failed atomic commit retains primary and previous-good snapshot together',async()=>{
  const f=fixture();assert.equal(await f.store.writeAsync(seed()),true);
  const before=f.disk;f.fail=true;
  assert.equal(await f.store.writeAsync({...seed(),goal:99}),false);
  assert.equal(f.disk,before);
  assert.equal(f.records.storage.getItem('studyplanner.v2.lastGood'),null);
  f.fail=false;assert.equal(await f.store.writeAsync({...seed(),goal:99}),true);
});
test('external file changes are never overwritten',async()=>{
  const f=fixture();await f.store.writeAsync(seed());f.external();
  assert.equal(await f.store.writeAsync({...seed(),goal:60}),false);
  assert.equal(f.disk,'changed externally');assert.equal(f.store.status().type,'conflict');
});
test('malformed native envelopes fail closed',()=>{
  for(const raw of ['{broken','{}','{"format":1,"records":{"unexpected":"x"}}'])assert.throws(()=>createFileRecords({},raw));
});
test('local alarms follow saved timer end and omit paused, disabled, and past alarms',()=>{
  const now=1000000,state={notify:{push:true,warn5:true},subjects:[{id:'s',name:'수학'}],running:{kind:'study',sid:'s',start:now,end:now+1800000}};
  assert.deepEqual(timerNotifications(state,now).map(x=>x.at),[now+1500000,now+1800000]);
  state.running.end+=600000;assert.equal(timerNotifications(state,now).at(-1).at,now+2400000);
  assert.deepEqual(timerNotifications(state,now+3000000),[]);
  state.running=null;assert.deepEqual(timerNotifications(state,now),[]);
  state.notify.push=false;assert.deepEqual(timerNotifications(state,now),[]);
});
