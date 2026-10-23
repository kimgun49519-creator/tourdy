/* UI integration for a durable, single-use first-session ticket. */
document.querySelector('.tabs').insertAdjacentElement('afterend', $('firstTripNotice'));
document.body.appendChild($('storageNotice'));
document.body.appendChild($('firstTripDialog'));

function renderFirstTripNotice() {
  const ready = S.firstTrip && S.firstTrip.status === 'ready';
  const pending = S.firstTrip && S.firstTrip.status === 'pending';
  const el = $('firstTripNotice');
  el.hidden = !ready && !(pending && S.subjects.length && tab === 'home');
  const remaining = Math.ceil(Math.max(0,TourdyRewards.REQUIRED_MS-TourdyRewards.studyMs(S))/60000);
  const text = (selector, value) => { const node = el.querySelector(selector); if(node.textContent !== value)node.textContent = value; };
  text('h2',ready ? '어디든 떠나는 무료 티켓 1장' : remaining ? `첫 여행까지 공부 ${remaining}분` : '공부를 마치면 무료 티켓을 드려요');
  text('p',ready ? '누적 공부 30분 달성! 열린 여행 지역에서 원하는 곳으로 최고급 티켓을 타고 즉시 도착해요. 세계 여행은 국내 완주 후 이용할 수 있어요.' : '누적 공부 30분을 채우고 세션을 끝내면 무료 최고급 티켓을 드려요. 중간에 정지하거나 과목을 바꿔도 합산돼요.');
  $('firstTripOpen').hidden = !ready;
  text('small',ready ? '지금 쓰지 않아도 보관돼요. 공부를 마친 뒤 사용해 주세요.' : '휴식·딴짓·직접 추가한 시간은 보상에 포함되지 않아요.');
}

const canChooseFirstTripOrigin = K => !K.done.length && !K.path.length && !K.km;
function firstTripOrigins(reset = false) {
  const T = tr(), K = kr(T), world = $('firstTripWorld').value;
  const select = $('firstTripOrigin'), current = world === 'kr' ? K.at : T.at;
  const changeable = world === 'kr' && canChooseFirstTripOrigin(K);
  const chosen = reset ? current : select.value;
  const rows = changeable ? KR : [world === 'kr' ? KRM[current] : NAT[current]];
  select.innerHTML = rows.map(x => `<option value="${esc(x[0])}">${esc(world === 'kr' ? x[1] : x[2])}</option>`).join('');
  select.value = rows.some(x => x[0] === chosen) ? chosen : current;
  select.disabled = !changeable;
  $('firstTripOriginNote').textContent = changeable ? `기본 출발지는 ${KRM[K.at][1]}이에요. 원하면 첫 여행을 시작할 도시를 바꿀 수 있어요.` : '이미 시작한 여행은 현재 위치에서 출발해요.';
  firstTripOptions();
}

function firstTripOptions() {
  const world = $('firstTripWorld').value;
  const query = $('firstTripSearch').value.trim().toLocaleLowerCase();
  const T = tr(), K = kr(T);
  const catalog = world === 'kr' ? KR : NATIONS;
  const from = world === 'kr' ? $('firstTripOrigin').value || K.at : T.at;
  const selected = $('firstTripDestination').value;
  const rows = catalog.filter(x => x[0] !== from && (!query || (x[1] + ' ' + x[2]).toLocaleLowerCase().includes(query)));
  $('firstTripDestination').innerHTML = rows.map(x => `<option value="${esc(x[0])}">${esc(x[1])} · ${esc(x[2])}</option>`).join('');
  if (rows.some(x => x[0] === selected)) $('firstTripDestination').value = selected;
  else if (rows.length) $('firstTripDestination').value = rows[0][0];
  firstTripPreview();
}

function firstTripPreview() {
  const world = $('firstTripWorld').value, id = $('firstTripDestination').value;
  $('firstTripGo').disabled = !id;
  $('firstTripError').hidden = true;
  if (!id) { $('firstTripPreview').textContent = '검색 결과가 없어요. 다른 이름으로 찾아보세요.'; return; }
  const T = tr(), K = kr(T);
  const from = world === 'kr' ? $('firstTripOrigin').value || K.at : T.at;
  const mode = world === 'kr' ? krMode(from, id) : wMode(from, id);
  const classes = world === 'kr' ? KCLS[mode] : WCLS[mode];
  const active = K.to || T.to || sp(T).to || (T.routes && T.routes.act);
  const fromName = world === 'kr' ? KRM[from][1] : NAT[from][2];
  const toName = world === 'kr' ? KRM[id][1] : NAT[id][2];
  $('firstTripPreview').textContent = `${fromName} → ${toName} · ${classes[classes.length - 1]} · 금색 티켓 · 0 마일 · 즉시 도착${active ? '\n진행 중인 여행과 특별 루트는 취소하고 선택한 곳으로 떠나요.' : ''}`;
}

function openFirstTrip() {
  if (!S.firstTrip || S.firstTrip.status !== 'ready') return;
  if (S.running) return toast('공부를 마친 뒤 무료 티켓을 사용해 주세요');
  const unlocked = worldOpen(tr());
  $('firstTripWorldOption').disabled = !unlocked;
  $('firstTripWorldOption').textContent = unlocked ? '세계' : '세계 · 국내 완주 후';
  $('firstTripWorldNote').hidden = unlocked;
  if(!unlocked)$('firstTripWorld').value='kr';
  $('firstTripSearch').value = '';
  firstTripOrigins(true);
  $('firstTripDialog').showModal();
}

function claimFirstTrip(world, id, origin) {
  if (!S.firstTrip || S.firstTrip.status !== 'ready' || S.running) return false;
  if (!['kr', 'w'].includes(world) || !(world === 'kr' ? KRM[id] && KR.some(x => x[0] === id) : NAT[id] && NATIONS.some(x => x[0] === id))) return false;
  if(world === 'w' && !worldOpen(tr()))return false;
  const next = JSON.parse(JSON.stringify(S));
  const T = next.travel, K = kr(T);
  const from = world === 'kr' ? origin || K.at : T.at;
  if(world === 'kr'){
    if(!KR.some(x=>x[0]===from))return false;
    if(from !== K.at && !canChooseFirstTripOrigin(K))return false;
    if(canChooseFirstTripOrigin(K))K.home=K.at=from;
  }
  if (from === id || !TourdyRewards.redeem(next, { world, id, from })) return false;
  const date = dk(today0()), tier = world === 'kr' ? 1 : 2;
  // Starting the gift trip replaces a pending route without changing earned miles.
  T.to = null; T.final = null; T.hold = false;
  K.to = null; K.final = null; K.hold = false;
  sp(T).to = null;
  if (T.routes) T.routes.act = null;
  T.on = true; T.world = world === 'kr' ? 'korea' : 'earth';
  if (world === 'kr') {
    K.km += krKm(from, id);
    const stamp = K.done.find(x => x.c === id);
    if (stamp) stamp.tier = 2;
    else if (id !== K.home) K.done.push({ c: id, d: date, tier: 2, free: true });
    K.path.push(id); K.at = id;
  } else {
    const km = kmBetween(from, id);
    T.km += km;
    if (km >= 5000) T.long = true;
    const stamp = T.stamps.find(x => x.c === id);
    if (stamp) stamp.tier = 2;
    else T.stamps.push({ c: id, d: date, tier: 2 });
    (T.log || (T.log = [])).push({ f: from, t: id, d: date, m: 0, cls: 2, free: true });
    T.at = id;
  }
  const event = { w: world, f: from, t: id, cls: tier, free: true };
  // Compute the usual arrival achievements in the candidate state, then commit
  // destination + consumed ticket together. A failed write consumes nothing.
  const previous = S;
  try { S = next; postArrive(event); }
  finally { S = previous; }
  if (!stateStore.write(next)) return false;
  S = next;
  $('firstTripDialog').close();
  renderFirstTripNotice(); syncTravelTab(); setTab('travel');
  arrQ(event);
  return true;
}

$('firstTripOpen').onclick = openFirstTrip;
$('firstTripLater').onclick = () => $('firstTripDialog').close();
$('firstTripWorld').onchange = () => firstTripOrigins(true);
$('firstTripOrigin').onchange = firstTripOptions;
$('firstTripSearch').oninput = firstTripOptions;
$('firstTripDestination').onchange = firstTripPreview;
$('firstTripForm').onsubmit = event => {
  event.preventDefault();
  if (!claimFirstTrip($('firstTripWorld').value, $('firstTripDestination').value, $('firstTripOrigin').value)) {
    $('firstTripError').textContent = '저장 상태를 확인해 주세요. 티켓은 사용하지 않았어요. 공부 중이라면 먼저 마쳐 주세요.';
    $('firstTripError').hidden = false;
  }
};
