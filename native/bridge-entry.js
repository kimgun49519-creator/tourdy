import {Capacitor, registerPlugin} from '@capacitor/core';
import {App} from '@capacitor/app';
import {LocalNotifications} from '@capacitor/local-notifications';
import {Filesystem, Directory, Encoding} from '@capacitor/filesystem';
import {Share} from '@capacitor/share';
import {Haptics} from '@capacitor/haptics';
import {createFileRecords} from './file-records.cjs';
import {timerNotifications} from './notifications.cjs';

const Records=registerPlugin('TourdyRecords');
let alarms=Promise.resolve();
let lastAlarms='';
let durableState=null;
let navigationRevision=0,navigationSignature='',navigationQueued=false;
function navigationChanged(){
  if(navigationQueued)return;
  navigationQueued=true;
  queueMicrotask(async()=>{
    navigationQueued=false;
    if(!window.TourdyNavigationState)return;
    const root=document.documentElement;
    const state={...window.TourdyNavigationState(),systemTheme:!root.dataset.theme,request:window.TourdyNative.navigationRequest||0,locked:!!window.TourdyNative.transactionBusy,
      modal:!!document.querySelector('dialog[open],.arr:not([hidden]),.sheet:not([hidden]),.modal:not([hidden])'),
      dark:root.dataset.theme==='dark'||(!root.dataset.theme&&matchMedia('(prefers-color-scheme: dark)').matches)};
    const signature=JSON.stringify(state);if(signature===navigationSignature)return;
    navigationSignature=signature;
    try{await Records.navigationState({...state,revision:++navigationRevision});root.classList.add('native-navigation');}
    catch(error){navigationSignature='';root.classList.remove('native-navigation');console.error('Native navigation unavailable',error);}
  });
}
const reserved=Array.from({length:61},(_,i)=>({id:41000+i}));
// A pointer overlay alone does not stop a focused field's keyboard shortcuts.
for(const type of ['click','pointerdown','keydown','beforeinput','input','change','submit'])document.addEventListener(type,event=>{
  if(window.TourdyNative?.transactionBusy){event.preventDefault();event.stopImmediatePropagation();}
},true);
async function saved(state){
  durableState=JSON.parse(JSON.stringify(state));
  const notices=timerNotifications(durableState);
  const signature=JSON.stringify(notices);
  if(signature===lastAlarms)return;
  alarms=alarms.catch(()=>{}).then(async()=>{
    const permission=await LocalNotifications.checkPermissions();
    if(permission.display!=='granted')return;
    await LocalNotifications.cancel({notifications:reserved});
    if(notices.length)await LocalNotifications.schedule({notifications:notices.map(n=>({id:n.id,title:n.title,body:n.body,sound:n.sound?'default':undefined,schedule:{at:new Date(n.at)}}))});
    lastAlarms=signature;
  });
  alarms.catch(()=>{const note=document.getElementById('pushNote');if(note)note.textContent='알림 예약에 실패했어요. 알림 설정을 다시 확인해 주세요.';});
}
function setBusy(value){
  window.TourdyNative.transactionBusy=value;
  let overlay=document.getElementById('native-save-lock');
  if(!overlay){
    overlay=document.createElement('div');overlay.id='native-save-lock';overlay.setAttribute('role','status');
    overlay.textContent='기기에 저장하는 중…';
    overlay.style.cssText='position:fixed;inset:0;z-index:2147483647;display:grid;place-items:center;background:rgba(16,16,20,.3);color:white;font:600 16px system-ui;touch-action:none';
    document.body.appendChild(overlay);
  }
  overlay.hidden=!value;
  overlay.style.display=value?'grid':'none';
  navigationChanged();
}
async function shareJSON(raw,name){
  const file=await Filesystem.writeFile({path:'tourdy-exports/'+name,directory:Directory.Cache,data:raw,encoding:Encoding.UTF8,recursive:true});
  await Share.share({title:'TOURDY 기록',url:file.uri});
}
async function boot(){
  if(!Capacitor.isNativePlatform())throw Error('This build requires the installed TOURDY app.');
  const loaded=await Records.readRecords();
  const legacy={};
  if(loaded.data===null){
    for(const key of ['studyplanner.v2','studyplanner.v2.lastGood','studyplanner.v2.damaged','studyplanner.v1']){
      const raw=localStorage.getItem(key);if(raw!==null)legacy[key]=raw;
    }
  }
  const records=createFileRecords(Records,loaded.data,legacy);
  window.TourdyNative={records,transactionBusy:false,transactionComputing:false,setBusy,saved,shareJSON,navigationChanged,
    requestNotifications:async()=>{const permission=await LocalNotifications.requestPermissions();lastAlarms='';return permission.display==='granted';},
    vibrate:()=>Haptics.impact({style:'LIGHT'}).catch(()=>{}),
    notifyArrival:async event=>{
      if(!document.hidden||!durableState?.notify?.push)return;
      await LocalNotifications.schedule({notifications:[{id:41060,title:'여행 도착',body:'새로운 목적지에 도착했어요. 여행 티켓을 확인해 보세요.',schedule:{at:new Date(Date.now()+1500)}}]});
    }
  };
  for(const src of window.TOURDY_APP_SCRIPTS){
    await new Promise((resolve,reject)=>{const script=document.createElement('script');script.src=src;script.onload=resolve;script.onerror=()=>reject(Error('App resource failed: '+src));document.body.appendChild(script);});
  }
  // Functions declared by classic scripts remain authoritative; no second tab state.
  const state=window.TourdyReadState();
  await saved(state);
  new MutationObserver(navigationChanged).observe(document.documentElement,{attributes:true,subtree:true,attributeFilter:['hidden','open','data-theme']});
  matchMedia('(prefers-color-scheme: dark)').addEventListener('change',navigationChanged);
  navigationChanged();
  App.addListener('appStateChange',async({isActive})=>{
    if(isActive&&!window.TourdyNative.transactionBusy)window.TourdyResume();
    else if(!isActive)await window.TourdyFlush();
  });
}
boot().catch(error=>{
  document.querySelector('.wrap')?.setAttribute('hidden','');
  const box=document.createElement('section');box.style.cssText='margin:40px 20px;padding:24px;border-radius:20px;background:#1d1d24;color:white;font:16px system-ui';
  const title=document.createElement('h2');title.textContent='기록을 안전하게 열지 못했어요';
  const text=document.createElement('p');text.textContent='기존 파일은 그대로 보관했습니다. 앱을 다시 열어 주세요. 문제가 계속되면 앱을 삭제하지 말고 문의해 주세요.';
  const retry=document.createElement('button');retry.textContent='다시 시도';retry.onclick=()=>location.reload();
  box.append(title,text,retry);document.body.appendChild(box);
  console.error('TOURDY startup failed',error?.message);
});
