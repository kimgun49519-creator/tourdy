// Cache each release as a complete shell so HTML and extracted scripts agree.
const VERSION = 'tourdy-v5';
const SHELL = [
  './', './index.html', './manifest.webmanifest', './css/app.css',
  './js/storage.js', './js/rewards.js', './js/core.js', './js/timer.js',
  './js/planner.js', './js/stats.js', './js/settings.js',
  './js/travel-world.js', './js/travel-korea.js', './js/travel-space.js',
  './js/travel-map.js', './js/travel-experience.js', './js/extras.js',
  './js/first-trip.js', './js/app.js', './js/pwa.js',
  './icon-192.png', './icon-512.png', './icon-maskable-512.png',
  './apple-touch-icon.png', './favicon-64.png',
];
self.addEventListener('install', event => {
  event.waitUntil(caches.open(VERSION).then(cache => cache.addAll(SHELL.map(url => new Request(url, { cache: 'reload' })))));
  // Existing clients keep their current release until they accept the update.
});
self.addEventListener('message', event => {
  if (event.data && event.data.type === 'ACTIVATE_UPDATE') self.skipWaiting();
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key !== VERSION && /^(toury-|tourdy-)/.test(key)).map(key => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', event => {
  const request = event.request, url = new URL(request.url);
  if (request.method !== 'GET') return;
  if (url.hostname === 'fonts.googleapis.com' || url.hostname === 'fonts.gstatic.com') {
    event.respondWith(caches.open('planner-fonts').then(async cache => {
      const hit = await cache.match(request);
      if (hit) return hit;
      try {
        const response = await fetch(request);
        if (response.ok || response.type === 'opaque') event.waitUntil(cache.put(request, response.clone()));
        return response;
      } catch (_) { return Response.error(); }
    }));
    return;
  }
  if (url.origin !== location.origin) return;
  event.respondWith(caches.open(VERSION).then(async cache => {
    const hit = await cache.match(request.mode === 'navigate' ? './index.html' : request, { ignoreSearch: true });
    return hit || fetch(request);
  }));
});
