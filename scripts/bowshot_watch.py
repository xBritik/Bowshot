#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# A small page that follows a build while it runs: the step it is in with its bar and time left, the steps done (reused or made, with their times), the disk, the last log lines.
#   python3 scripts/bowshot_watch.py <game folder>        then open http://127.0.0.1:8765  (--port N, --log FILE for a log elsewhere)
# It only reads: the build log (<game folder>/Bowshot-build/build.log, or Bowshot-local/ before 0.1.3, the lines of a terminal build or the JSON events of the builder window), the disk's free
# space, and the files the pipeline archive step writes. It listens on 127.0.0.1 only, never writes, and ends with Ctrl-C. Plain standard library.
import argparse, http.server, json, os, re, shutil, subprocess, sys, time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import bowshot_report as report

LIVE = re.compile(r'^\[(\d\d:\d\d:\d\d)\] \[(\d+)/(\d+)\] (.+?)(?: · (.+?))?(?:: (\d+)%, (.*?))?(?: …)?$')
STEP_LINE = re.compile(r'^\[\d\d:\d\d:\d\d\] \[\d+/\d+\] ')
ETA = re.compile(r'ETA (\S+)')
STALL_S = 180


def find_log(folder):
    for name in ('Bowshot-build', 'Bowshot-local'):
        p = Path(folder) / name / 'build.log'
        if p.is_file(): return p
    return None


def live_step(lines):
    """The step the build is in, from its last progress line (or JSON event): {k, n, name, step, pct, detail, eta}, None when between steps"""
    cur = None
    for raw in lines:
        l = raw.rstrip('\r')
        if l.startswith('{'):
            try: e = json.loads(l)
            except ValueError: continue
            ev = e.get('ev')
            if ev == 'stage': cur = {'k': e.get('k'), 'n': e.get('n'), 'name': e.get('name', ''), 'step': e.get('step', ''), 'pct': None, 'detail': '', 'eta': ''}
            elif ev == 'step' and cur: cur['step'] = e.get('step', '')
            elif ev == 'progress' and cur:
                f = e.get('frac'); cur['pct'] = None if f is None else int(f * 100)
                done, total = e.get('done'), e.get('total')
                bits = [f'{int(done):,}/{int(total):,} {e.get("unit", "")}'.strip()] if done is not None and total else []
                if e.get('note'): bits.append(e['note'])
                cur['detail'] = ' · '.join(bits); eta = e.get('eta'); cur['eta'] = f'about {report.hms(eta)} left' if eta else ''
            elif ev == 'stage_end': cur = None
            continue
        if re.match(r'^\[\d\d:\d\d:\d\d\] [✓✗⚠] ', l): cur = None; continue
        if not STEP_LINE.match(l): continue
        m = LIVE.match(l)
        if not m or l.startswith('[RED]'): continue
        detail = m[7] or ''; e = ETA.search(detail)
        step = re.sub(r': \d+:\d\d(?: · ETA \S+)?$', '', m[5] or '')   # a step line without a count ends with its elapsed time
        cur = {'k': m[2], 'n': m[3], 'name': m[4], 'step': step, 'pct': int(m[6]) if m[6] else None, 'detail': detail, 'eta': f'about {e[1]} left' if e else ''}
    return cur


class Pace:   # bytes the archive step wrote, and how fast over the last minutes
    def __init__(self): self.hist = []
    def measure(self, folder):
        files = []
        for name in ('Bowshot-build', 'Bowshot-local'):
            d = Path(folder) / name / 'build/run/pso_archive'
            if d.is_dir(): files = list(d.glob('p0*.mtl4a')); break
        if not files: return None
        size = sum(f.stat().st_size for f in files); now = time.time()
        self.hist.append((now, size)); del self.hist[:-200]
        old = [h for h in self.hist if now - h[0] >= 240]
        rate = round((size - old[-1][1]) / (now - old[-1][0]) * 60 / 1e9, 2) if old else None
        return {'files': len(files), 'gb': round(size / 1e9, 1), 'rate': rate}


def status(log, folder, pace):
    try: text = log.read_text(encoding='utf-8', errors='replace')
    except OSError: text = ''
    lines = text.split('\n')
    steps = []
    if text:
        tmp = report.parse(log)
        steps = [{'name': s['step'], 'state': s['state'], 'time': report.hms(s['seconds']), 'summary': s['summary'][:90]} for s in tmp['steps']]
    finished = next((l[7:].strip() for l in reversed(lines) if l.startswith('READY: ')), '')
    failed = next((l[7:].strip() for l in reversed(lines) if l.startswith('ERROR: ')), '')
    cur = None if finished else live_step(lines)
    age = time.time() - log.stat().st_mtime if log.exists() else 0
    running = subprocess.run(['pgrep', '-f', 'bowshot_build.sh'], capture_output=True).returncode == 0
    first = next((m[1] for m in (STAMP.match(l) for l in lines) if m), '')
    free = shutil.disk_usage(str(folder))
    return {'steps': steps, 'current': cur, 'finished': finished, 'failed': failed, 'running': running, 'start': first, 'now': time.strftime('%H:%M:%S'),
            'silent_s': int(age) if running else 0, 'stalled': running and age > STALL_S and not finished, 'disk': f'{free.free / 2**30:.0f} GB free of {free.total / 2**30:.0f} GB',
            'archive': pace.measure(folder) if cur and cur['name'] == 'Pipeline prebuild' else None, 'tail': [x[:200] for x in lines[-14:] if x.strip()]}


STAMP = re.compile(r'^\[(\d\d:\d\d:\d\d)\]')

PAGE = """<!doctype html><meta charset=utf-8><title>Bowshot build</title>
<style>
:root{color-scheme:light dark;--fg:#1d1d1f;--mut:#6e6e73;--bg:#fff;--card:#f5f5f7;--acc:#0a84ff;--ok:#30a14e;--warn:#d98200;--bad:#d1242f}
@media(prefers-color-scheme:dark){:root{--fg:#f5f5f7;--mut:#98989d;--bg:#1c1c1e;--card:#2c2c2e}}
body{font:15px -apple-system,system-ui,sans-serif;background:var(--bg);color:var(--fg);margin:0;padding:28px;max-width:760px}
h1{font-size:20px;margin:0 0 4px}.sub{color:var(--mut);margin-bottom:22px}
.card{background:var(--card);border-radius:12px;padding:16px 18px;margin-bottom:16px}
.row{display:flex;justify-content:space-between;align-items:baseline;gap:12px}
.bar{height:10px;border-radius:5px;background:rgba(128,128,128,.25);overflow:hidden;margin:10px 0 8px}
.bar i{display:block;height:100%;background:var(--acc);transition:width .6s}
.mut{color:var(--mut);font-size:13px}.big{font-size:17px;font-weight:600}
.step{display:flex;gap:10px;padding:6px 0;border-top:1px solid rgba(128,128,128,.2)}.step:first-child{border-top:0}
.step b{width:22px;text-align:center}.step span:nth-child(2){flex:1}.t{font-variant-numeric:tabular-nums;color:var(--mut)}
.ok{color:var(--ok)}.run{color:var(--acc)}.bad{color:var(--bad)}.re{color:var(--mut)}.warn{color:var(--warn)}
pre{margin:0;font:12px ui-monospace,Menlo,monospace;white-space:pre-wrap;max-height:210px;overflow:auto;color:var(--mut)}
.red{color:var(--bad)}.fin{color:var(--ok);font-weight:600}
</style>
<h1>Bowshot build</h1><div class=sub id=sub>…</div>
<div class=card id=cur><div class=row><span class=big id=name>…</span><span class=mut id=idx></span></div>
<div class=bar><i id=fill style="width:0"></i></div>
<div class=row><span class=mut id=det></span><span class=mut id=eta></span></div><div class="mut warn" id=stall style="margin-top:6px"></div></div>
<div class=card id=arch style="display:none"><div class=row><span class=mut>Pipeline archive being written</span><span id=archv class=big></span></div><div class=mut id=archn style="margin-top:6px"></div></div>
<div class=card><div class=mut style="margin-bottom:6px">Steps</div><div id=steps></div></div>
<div class=card><div class=row><span class=mut>Disk</span><span id=disk class=mut></span></div></div>
<div class=card><div class=mut style="margin-bottom:6px">Log</div><pre id=log></pre></div>
<script>
const $=id=>document.getElementById(id), esc=s=>String(s).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
async function tick(){
 try{
  const d=await (await fetch('/status',{cache:'no-store'})).json();
  $('sub').textContent=(d.finished?'Finished':d.failed?'Stopped with an error':d.running?'Running':'Not running')+(d.start?' · since '+d.start:'')+' · '+d.now;
  const c=d.current;
  if(d.finished){$('name').textContent='Done';$('name').className='big fin';$('fill').style.width='100%';$('det').textContent=d.finished;$('eta').textContent='';$('idx').textContent=''}
  else if(d.failed){$('name').textContent='The build stopped';$('name').className='big bad';$('det').textContent=d.failed;$('eta').textContent='';$('idx').textContent=''}
  else if(c){$('name').textContent=c.name;$('name').className='big';$('idx').textContent='Step '+c.k+' of '+c.n+(c.step?' · '+c.step:'');
   $('fill').style.width=(c.pct??0)+'%';$('det').textContent=(c.pct!=null?c.pct+' % · ':'')+c.detail;$('eta').textContent=c.eta||''}
  $('stall').textContent=d.stalled?'No output for '+Math.round(d.silent_s/60)+' min: some steps log nothing for a long while, but check that the build is still working.':'';
  $('steps').innerHTML=d.steps.map(s=>'<div class=step><b class="'+(s.state=='failed'?'bad':s.state=='reused'?'re':'ok')+'">'+(s.state=='failed'?'✗':s.state=='reused'?'↺':'✓')+'</b><span>'+esc(s.name)+(s.summary?' <span class=mut>— '+esc(s.summary)+'</span>':'')+'</span><span class=t>'+s.time+(s.state=='reused'?' · reused':'')+'</span></div>').join('')
   +(c&&!d.finished&&!d.failed?'<div class=step><b class=run>●</b><span>'+esc(c.name)+'</span><span class=t>running</span></div>':'');
  const a=d.archive;$('arch').style.display=a?'block':'none';
  if(a){$('archv').textContent=a.gb+' GB · '+a.files+' files';$('archn').textContent=a.rate!=null?'Writing about '+a.rate+' GB per minute.':'Measuring the pace…'}
  $('disk').textContent=d.disk;
  $('log').innerHTML=d.tail.map(l=>{l=esc(l);return l.includes('[RED]')||l.includes('ERROR')?'<span class=red>'+l+'</span>':l.includes('READY')?'<span class=fin>'+l+'</span>':l}).join('\\n');
 }catch(e){$('sub').textContent='the page server stopped'}
}
tick();setInterval(tick,2000);
</script>"""


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('folder', nargs='?', default='.', help='the game folder (the one that holds Bowshot-build)')
    ap.add_argument('--log', help='a build log, when it is not <game folder>/Bowshot-build/build.log')
    ap.add_argument('--port', type=int, default=8765)
    a = ap.parse_args()
    folder = Path(a.folder).expanduser().resolve()
    log = Path(a.log).expanduser() if a.log else find_log(folder)
    if not log: sys.exit(f'no Bowshot-build/build.log (or Bowshot-local/build.log) in {folder}: give the game folder, or --log FILE')
    pace = Pace()

    class H(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path.startswith('/status'): body, ctype = json.dumps(status(log, folder, pace)).encode(), 'application/json'
            else: body, ctype = PAGE.encode(), 'text/html; charset=utf-8'
            self.send_response(200); self.send_header('Content-Type', ctype); self.send_header('Cache-Control', 'no-store'); self.send_header('Content-Length', str(len(body))); self.end_headers(); self.wfile.write(body)
        def log_message(self, *args): pass

    print(f'Following {log}\nOpen http://127.0.0.1:{a.port}  (Ctrl-C to stop)', flush=True)
    try: http.server.ThreadingHTTPServer(('127.0.0.1', a.port), H).serve_forever()
    except KeyboardInterrupt: pass
    except OSError as e: sys.exit(f'cannot listen on 127.0.0.1:{a.port}: {e}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
