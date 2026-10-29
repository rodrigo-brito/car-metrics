#pragma once
#include <pgmspace.h>

// Página do painel. Busca /api a cada 10 s e renderiza os cards.
static const char DASHBOARD_HTML[] PROGMEM = R"HTML(<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>ESP32 Painel</title>
<style>
:root{--bg:#0f1115;--card:#181b22;--fg:#e6e8ef;--mut:#8b90a0;--ok:#2ecc71;--warn:#f1c40f;--bad:#e74c3c;--line:#262a35}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:15px/1.4 system-ui,-apple-system,Segoe UI,Roboto,sans-serif;padding:16px}
h1{font-size:18px;margin:0 0 4px;display:flex;align-items:center;gap:10px}
.dot{width:14px;height:14px;border-radius:50%;background:var(--mut);box-shadow:0 0 10px currentColor}
.dot.ok{background:var(--ok);color:var(--ok)}.dot.bad{background:var(--bad);color:var(--bad)}.dot.warn{background:var(--warn);color:var(--warn)}
.sub{color:var(--mut);font-size:13px;margin-bottom:16px}
h2{font-size:12px;letter-spacing:.08em;text-transform:uppercase;color:var(--mut);margin:18px 0 8px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:10px}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:12px}
.card .n{font-weight:600;display:flex;justify-content:space-between;align-items:center}
.card .v{color:var(--mut);font-size:13px;margin-top:6px}
.bar{height:5px;background:var(--line);border-radius:3px;margin-top:8px;overflow:hidden}
.bar i{display:block;height:100%;background:var(--ok)}
.bar i.warn{background:var(--warn)}.bar i.bad{background:var(--bad)}
.pill{font-size:11px;padding:2px 7px;border-radius:999px;background:var(--line)}
.pill.ok{background:#153d28;color:var(--ok)}.pill.bad{background:#4a1d1a;color:var(--bad)}.pill.warn{background:#4a3f12;color:var(--warn)}
.err{background:#4a1d1a;color:#ffb3ad;padding:10px;border-radius:8px;margin:10px 0;display:none}
.foot{color:var(--mut);font-size:12px;margin-top:20px;display:flex;flex-wrap:wrap;gap:14px;align-items:center}
button{background:var(--line);color:var(--fg);border:0;border-radius:8px;padding:6px 12px;cursor:pointer}
</style></head><body>
<h1><span id="dot" class="dot"></span> usestl.com/health <span id="overall" class="pill">...</span></h1>
<div class="sub" id="sub">carregando…</div>
<div class="err" id="err"></div>
<h2>Checks</h2><div class="grid" id="checks"></div>
<h2>Operations</h2><div class="grid" id="ops"></div>
<div class="foot">
  <span id="dev"></span>
  <form method="post" action="/refresh" style="margin:0"><button>Atualizar agora</button></form>
</div>
<script>
const cls=s=>s==='ok'?'ok':(s==='degraded'||s==='warn')?'warn':'bad';
const esc=s=>String(s).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
async function load(){
  try{
    const d=await (await fetch('/api',{cache:'no-store'})).json();
    const c=cls(d.overall);
    dot.className='dot '+c; overall.className='pill '+c; overall.textContent=d.overall;
    sub.textContent=`última consulta há ${d.ageSec<0?'—':d.ageSec+' s'} · ${d.pollMs} ms · HTTP ${d.httpCode} · consulta a cada ${d.pollEvery} s · ${d.polls} consultas, ${d.failures} falhas`;
    err.style.display=d.error?'block':'none'; err.textContent=d.error||'';
    checks.innerHTML=d.checks.map(x=>`<div class="card"><div class="n">${esc(x.name)} <span class="pill ${cls(x.status)}">${esc(x.status)}</span></div><div class="v">${x.latencyMs} ms</div></div>`).join('')||'<div class="v">sem dados</div>';
    ops.innerHTML=d.operations.map(x=>{const p=Math.round(x.rate*100),b=p>=99?'':p>=90?'warn':'bad';
      return `<div class="card"><div class="n">${esc(x.name)} <span class="pill ${cls(x.status)}">${esc(x.status)}</span></div><div class="v">ok ${x.ok} · fail ${x.fail} · ${p}%</div><div class="bar"><i class="${b}" style="width:${p}%"></i></div></div>`}).join('')||'<div class="v">sem dados</div>';
    const up=d.uptimeSec,h=Math.floor(up/3600),m=Math.floor(up%3600/60);
    dev.textContent=`ESP32 ${d.ip} · ${d.ssid} ${d.rssi} dBm · uptime ${h}h${String(m).padStart(2,'0')} · heap ${Math.round(d.heap/1024)} KB`;
  }catch(e){ err.style.display='block'; err.textContent='falha ao ler /api: '+e; }
}
load(); setInterval(load,10000);
</script></body></html>)HTML";
