// 오프라인 지원: 앱 파일은 저장해 두고, 인터넷이 되면 항상 최신 index.html을 먼저 받아요.
const VERSION='planner-v1';
const SHELL=['./','./index.html','./manifest.webmanifest','./icon-192.png','./icon-512.png','./icon-maskable-512.png','./apple-touch-icon.png','./favicon-64.png'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(VERSION).then(c=>c.addAll(SHELL)).then(()=>self.skipWaiting()))});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==VERSION&&k!=='planner-fonts').map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
self.addEventListener('fetch',e=>{
  const req=e.request,url=new URL(req.url);if(req.method!=='GET')return;
  if(url.hostname==='fonts.googleapis.com'||url.hostname==='fonts.gstatic.com'){ // 글꼴: 저장본 우선
    e.respondWith(caches.open('planner-fonts').then(c=>c.match(req).then(hit=>hit||fetch(req).then(r=>{if(r.ok||r.type==='opaque')c.put(req,r.clone());return r}))));return}
  if(url.origin!==location.origin)return;
  if(req.mode==='navigate'||url.pathname.endsWith('.html')){ // 화면: 최신 우선, 오프라인이면 저장본
    e.respondWith(fetch(req).then(r=>{const cp=r.clone();caches.open(VERSION).then(c=>c.put('./index.html',cp));return r}).catch(()=>caches.match('./index.html')));return}
  e.respondWith(caches.match(req).then(hit=>hit||fetch(req).then(r=>{const cp=r.clone();caches.open(VERSION).then(c=>c.put(req,cp));return r})));
});
