/* ---------- nav ---------- */
function setTab(t){tab=t;document.querySelectorAll('[data-tab]').forEach(b=>b.setAttribute('aria-selected',b.dataset.tab===t));
  $('vHome').hidden=t!=='home';$('vTodo').hidden=t!=='todo';$('vStats').hidden=t!=='stats';$('vSet').hidden=t!=='set';$('vTravel').hidden=t!=='travel';armed=null;
  if(t==='home')setHome(homeTab);if(t==='todo')renderTasks();if(t==='stats')renderStats();if(t==='set')renderSet();if(t==='travel')renderTravel()}
document.querySelector('.tabs').addEventListener('click',e=>{const b=e.target.closest('[data-tab]');if(b)setTab(b.dataset.tab)});

function renderAll(){renderFirstTripNotice();if(typeof renderWelcome==='function')renderWelcome();if(typeof syncTravelTab==='function')syncTravelTab();DS=Number.isInteger(S.dayStart)?S.dayStart:0;applyTheme();$('tlAxis').innerHTML=[0,6,12,18,24].map((h,i)=>`<span>${(h+DS)%24||(i===4?24:0)}${i===4?'시':''}</span>`).join('');renderDday();fillSelects();renderSubs();renderTasks();renderRecords();tick();if(homeTab==='preset')renderPresets();if(tab==='stats')renderStats();if(tab==='set')renderSet()}
syncTravelTab();
if(S.plan||(S.running&&S.running.plan))homeMode='plan';setMode(homeMode);
resetRecForm();if(stateStore.status().type==='recovered')saveStoredSnapshot();renderAll();renderExtras();renderWelcome();maybeReport();
let lastDay=dk(today0()),n=0;
setInterval(()=>{tick();if(++n%30===0&&tab==='stats')renderStats();
  if(n%10===0&&tr().on){if(checkArrival())ding();if(tab==='travel'){renderTravelTop();if(tr().world!=='earth')renderWorld()}}
  if(dk(today0())!==lastDay){lastDay=dk(today0());view=today0();renderAll();maybeReport()}},1000);
document.addEventListener('visibilitychange',()=>{if(!document.hidden)tick()});
