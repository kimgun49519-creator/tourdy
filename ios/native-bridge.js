// Native switches share the original app handlers and its single saved state.
(() => {
  let nextID = 0, scheduled = false, previous = '', previousTabs = '', tabRevision = 0;
  const style = document.createElement('style');
  style.textContent = '[role="switch"] .sw-k{visibility:hidden}.tabs{display:none!important}';
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
    const tabs = [...document.querySelectorAll('.tabs [data-tab]')].flatMap(el => {
      if (el.hidden) return [];
      el.setAttribute('aria-hidden', 'true');
      el.tabIndex = -1;
      return [{id:el.dataset.tab, title:el.textContent.trim(), on:el.getAttribute('aria-selected') === 'true', x:0, y:0, width:0, height:0}];
    });
    const state = {revision:tabRevision, tabs};
    const tabJSON = JSON.stringify(state);
    if (tabJSON !== previousTabs) { previousTabs = tabJSON; window.webkit.messageHandlers.tourdyTabs.postMessage(state); }
  }
  function schedule() { if (!scheduled) { scheduled = true; requestAnimationFrame(publish); } }
  window.tourdyNativeToggle = (id, value) => {
    const el = [...document.querySelectorAll('[data-native-switch]')].find(el => el.dataset.nativeSwitch === id);
    if (!el || el.disabled) return;
    if ((el.getAttribute('aria-checked') === 'true') !== value) el.click();
    schedule();
  };
  window.tourdyNativeSelectTab = (id, revision) => {
    if (!Number.isSafeInteger(revision) || revision < tabRevision) return;
    tabRevision = revision;
    const el = [...document.querySelectorAll('.tabs [data-tab]')].find(el => el.dataset.tab === id);
    if (el && !el.hidden) el.click();
    schedule();
  };
  new MutationObserver(schedule).observe(document.body, {subtree:true, childList:true, attributes:true, attributeFilter:['aria-checked','aria-selected','hidden','class','style']});
  addEventListener('scroll', schedule, true);
  addEventListener('resize', schedule);
  addEventListener('pageshow', schedule);
  schedule();
})();
