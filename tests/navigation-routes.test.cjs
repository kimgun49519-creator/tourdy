const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../js/travel-experience.js'),'utf8');
function routes(){
  const elements={krRoutes:{},tvRoutes:{}};
  const T={at:'KR',to:null,sp2:{to:null},kr:{at:'seoul',to:null}},R={act:null,done:{}};
  const route={id:'sample',name:'첫 루트',w:'kr',stops:['seoul','busan'],desc:'여행'};
  const c={window:{scrollTo(){}},$:id=>elements[id],tr:()=>T,kr:t=>t.kr,sp:t=>t.sp2,RT:()=>R,ROUTE:{sample:route},ROUTES:[route],
    inSeason:()=>true,plName:(_,s)=>s,routeIcon:()=>'<svg></svg>',esc:s=>s,seasonLbl:()=>'',pk:x=>x,ymd:x=>x,
    save(){},vibe(){},checkArrival:()=>false,renderTravel(){}};
  vm.createContext(c);vm.runInContext(source.slice(source.indexOf('function startRoute('),source.indexOf("document.addEventListener('keydown',e=>{const card")),c);
  return {c,T,R,render(){c.renderRoutes('kr');return elements.krRoutes.innerHTML;}};
}
test('only available route cards are gold, keyboard-focusable departure controls',()=>{
  const f=routes();let html=f.render();
  assert.match(html,/class="rt here" role="button" tabindex="0" data-rtgo="sample"/);
  assert.doesNotMatch(html,/<button[^>]*data-rtgo/);
  f.T.kr.to='other';html=f.render();assert.doesNotMatch(html,/data-rtgo=|class="rt here"/);
  f.c.startRoute('sample');assert.equal(f.R.act,null);
  f.T.kr.to=null;f.c.startRoute('sample');assert.equal(f.R.act.id,'sample');assert.equal(f.T.kr.to,'busan');
  html=f.render();assert.doesNotMatch(html,/data-rtgo=/);assert.match(html,/data-rtstop="sample"/);
});
test('wrong city, closed season and another active route cannot be departed by stale taps',()=>{
  for(const change of [f=>{f.T.kr.at='busan';},f=>{f.c.inSeason=()=>false;},f=>{f.R.act={id:'other',i:0};}]){
    const f=routes();change(f);assert.doesNotMatch(f.render(),/data-rtgo=/);
    const old=JSON.stringify(f.R);f.c.startRoute('sample');assert.equal(JSON.stringify(f.R),old);
  }
});
test('rapid native selections use the same authoritative tab and visible panel',()=>{
  const source=fs.readFileSync(path.join(__dirname,'../js/app.js'),'utf8');
  const panels=Object.fromEntries(['vHome','vTodo','vStats','vSet','vTravel','tabTravel'].map(x=>[x,{hidden:false}]));
  const buttons=['home','todo','stats','travel','set'].map(tab=>({dataset:{tab},setAttribute(_,value){this.selected=value;}}));
  const c={tab:'home',homeTab:'timer',armed:null,window:{TourdyNative:{transactionBusy:false,navigationChanged(){}}},$:id=>panels[id],document:{querySelectorAll:()=>buttons},
    setHome(){},renderTasks(){},renderStats(){},renderSet(){},renderTravel(){}};
  vm.createContext(c);vm.runInContext(source.slice(source.indexOf('function setTab('),source.indexOf("document.querySelector('.tabs')")),c);
  vm.runInContext(source.match(/window.TourdySelectTab=.*?;};/)[0],c);
  const mapping={home:'vHome',todo:'vTodo',stats:'vStats',travel:'vTravel',set:'vSet'};
  for(let i=0;i<200;i++){
    const id=buttons[(i*3)%5].dataset.tab;assert.equal(c.window.TourdySelectTab(id),true);
    assert.equal(c.tab,id);assert.equal(panels[mapping[id]].hidden,false);
    assert.equal(buttons.filter(b=>b.selected).length,1);
  }
  c.window.TourdyNative.transactionBusy=true;assert.equal(c.window.TourdySelectTab('home'),false);
  c.window.TourdyNative.transactionBusy=false;panels.tabTravel.hidden=true;
  assert.equal(c.window.TourdySelectTab('travel'),false);assert.equal(c.window.TourdySelectTab('invalid'),false);
});
