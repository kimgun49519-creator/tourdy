/* Bundled only by scripts/build-preview.cjs; never loaded by the production app. */
const testPanel = document.createElement('section');
testPanel.className = 'panel test-controls';
testPanel.setAttribute('aria-label', '테스트 도구');
testPanel.innerHTML = `<div class="panel-head"><h2>TOURDY 테스트</h2><span class="note">실제 기록과 분리 · 다시 열면 초기화</span></div>
  <div class="test-actions"><button class="secondary" data-test="29">29분 종료</button><button class="secondary" data-test="running">30분 넘김 · 공부 중</button><button class="secondary" data-test="stop">세션 종료</button><button class="secondary" data-test="add">공부 +10분</button><button class="secondary" data-test="miles">마일 +1,000</button><button class="secondary" data-test="unlock">세계·우주 열기</button><button class="secondary" data-test="fail">저장 실패 재현</button><button class="secondary" data-test="recover">저장 다시 허용</button><button class="secondary" data-test="reset">처음 상태</button></div>`;
document.querySelector('.tabs').insertAdjacentElement('afterend', testPanel);

function testState() {
  return norm({ subjects:[{ id:'test-math',name:'수학',color:'#0090FF',icon:'fx',goal:0 },{ id:'test-english',name:'영어',color:'#30A46C',icon:'globe',goal:0 }],sessions:[],running:null,tasks:{},repeats:[],welcome:false,notify:{sound:false,memo:false},travel:{on:true,at:'KR',to:null,used:0,km:0,stamps:[],news:[],world:'korea'} });
}
function resetTestState() {
  window.TOURDY_TEST_STORAGE.failed = false;
  S = testState(); TourdyRewards.initialize(S);
  storageRecoveryNotice = false;
  stateStore.write(S, {replace:true});
  closeArrival(); closeCheckin(); $('memoSheet').hidden=true; $('bonusPop').hidden=true;
  if($('firstTripDialog').open)$('firstTripDialog').close();
  save();renderAll();renderExtras();setTab('home');
}
function addTestStudy(minutes) {
  const now=Date.now();
  S.sessions.push({id:uid(),kind:'study',sid:liveSubs()[0].id,start:now-minutes*60000,end:now});
  TourdyRewards.earn(S);save();renderAll();if(tab==='travel')renderTravel();
}
testPanel.addEventListener('click', event => {
  const button=event.target.closest('[data-test]');if(!button)return;
  switch(button.dataset.test){
    case '29': resetTestState();addTestStudy(29);break;
    case 'running': resetTestState();addTestStudy(10);S.running={kind:'study',sid:liveSubs()[0].id,start:Date.now()-21*60000};save();refreshTimer();break;
    case 'stop': stopAll();break;
    case 'add': if(S.running)stopAll();addTestStudy(10);break;
    case 'miles': tr().used-=1000;save();setTab('travel');break;
    case 'unlock': tr().worldTest=true;tr().spTest=true;save();setTab('travel');break;
    case 'fail': window.TOURDY_TEST_STORAGE.failed=true;save();break;
    case 'recover': window.TOURDY_TEST_STORAGE.failed=false;save();break;
    case 'reset': resetTestState();break;
  }
});

// Small presentation state may survive an inline viewer rerender. Study records
// remain solely in this sandbox's memory, never in the user's browser storage.
function reportTestView(){if(parent!==window)parent.postMessage({type:'tourdy-preview-state',view:tab,world:tr().world||'korea',reward:S.firstTrip.status},'*')}
document.addEventListener('click',()=>setTimeout(reportTestView,0));
window.addEventListener('message',event=>{
  if(event.source!==parent||!event.data||event.data.type!=='tourdy-preview-restore')return;
  if(['home','todo','stats','set','travel'].includes(event.data.view))setTab(event.data.view);
});
reportTestView();
