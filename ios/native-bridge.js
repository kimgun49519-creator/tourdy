// Native switches share the original app handlers and its single saved state.
(() => {
  let nextID = 0, scheduled = false, previous = '';
  const style = document.createElement('style');
  style.textContent = '[role="switch"] .sw-k{visibility:hidden}';
  document.head.appendChild(style);
  function publish() {
    scheduled = false;
    const rows = [...document.querySelectorAll('[role="switch"]')].flatMap(el => {
      const knob = el.querySelector('.sw-k');
      if (!knob || !el.getClientRects().length) return [];
      const rect = knob.getBoundingClientRect();
      if (rect.bottom < 0 || rect.top > innerHeight || rect.right < 0 || rect.left > innerWidth) return [];
      // Browser push notifications are not implemented in the native shell yet.
      if (el.dataset.sw === 'notify.push') {
        el.disabled = true;
        const note = el.querySelector('small');
        if (note && note.textContent !== 'iOS 알림은 아직 연결하지 않았어요') note.textContent = 'iOS 알림은 아직 연결하지 않았어요';
        return [];
      }
      if (!el.dataset.nativeSwitch) el.dataset.nativeSwitch = String(++nextID);
      return [{id: el.dataset.nativeSwitch, title: el.querySelector('.sw-t')?.childNodes[0]?.textContent?.trim() || el.textContent.trim(), on: el.getAttribute('aria-checked') === 'true', x: rect.x, y: rect.y, width: rect.width, height: Math.max(rect.height, 32)}];
    });
    const json = JSON.stringify(rows);
    if (json !== previous) { previous = json; window.webkit.messageHandlers.tourdySwitches.postMessage(rows); }
  }
  function schedule() { if (!scheduled) { scheduled = true; requestAnimationFrame(publish); } }
  window.tourdyNativeToggle = (id, value) => {
    const el = [...document.querySelectorAll('[data-native-switch]')].find(el => el.dataset.nativeSwitch === id);
    if (!el || el.disabled) return;
    if ((el.getAttribute('aria-checked') === 'true') !== value) el.click();
    schedule();
  };
  new MutationObserver(schedule).observe(document.body, {subtree:true, childList:true, attributes:true, attributeFilter:['aria-checked','hidden','class','style']});
  addEventListener('scroll', schedule, true);
  addEventListener('resize', schedule);
  addEventListener('pageshow', schedule);
  schedule();
})();
