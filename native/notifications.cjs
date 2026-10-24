// Derive all local timer alarms from the same saved plan used by TOURDY.
function timerNotifications(state, now = Date.now()) {
  if (!state.notify?.push) return [];
  const result=[];
  const name=id=>state.subjects?.find(s=>s.id===id)?.name||'공부';
  let id=41000;
  const add=(at,title,body)=>{
    if(Number.isFinite(at)&&at>now+1000&&result.length<60)result.push({id:id++,at,title,body,sound:state.notify?.sound!==false});
  };
  let run=state.running ? JSON.parse(JSON.stringify(state.running)) : null;
  if(state.plan){
    const p=state.plan;
    add(p.start,'공부 시작',`${name(p.sid)} · 예약한 시간이에요.`);
    run={kind:'study',sid:p.sid,start:p.start,end:p.start+p.dur,cyc:p.cyc||null};
  }
  for(let guard=0;run&&Number.isFinite(run.end)&&guard<30;guard++){
    if(run.kind==='study'&&state.notify?.warn5!==false&&run.end-run.start>10*60000)add(run.end-300000,'5분 남았어요',name(run.sid));
    const cycle=run.cyc;
    if(cycle&&run.kind==='study'&&cycle.n<cycle.total){
      add(run.end,`${cycle.n}세트 끝`,`${cycle.rest/60000}분 쉬어요.`);
      run={kind:'rest',start:run.end,end:run.end+cycle.rest,cyc:cycle};
    }else if(cycle&&run.kind==='rest'){
      const next={...cycle,n:cycle.n+1};
      add(run.end,`${next.n}세트 시작`,name(next.sid));
      run={kind:'study',sid:next.sid,start:run.end,end:run.end+next.dur,cyc:next};
    }else{
      add(run.end,'공부 끝',`${name(run.sid)} · 수고했어요. 여행 기록도 확인해 보세요.`);
      run=null;
    }
  }
  return result;
}
module.exports={timerNotifications};
