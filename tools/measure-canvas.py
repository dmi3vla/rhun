#!/usr/bin/env python3
"""Compare a separately built baseline with current canvas; requires GNU time/strip.
Usage: python3 tools/measure-canvas.py /path/to/baseline/build/rhun [output.json]
Build current test binaries first. Timings include headless startup through exit;
primitive frames exclude file I/O, fonts and desktop presentation.
"""
import json
import os
from pathlib import Path
import re
import statistics
import subprocess
import sys
import tempfile
import time
ROOT=Path(__file__).resolve().parents[1]
if len(sys.argv) not in (2,3):raise SystemExit(__doc__)
baseline=Path(sys.argv[1]).resolve()
output=Path(sys.argv[2] if len(sys.argv)==3 else ROOT/'docs/native-canvas-measurements.json')
report={'hardware':next((l.split(':',1)[1].strip() for l in Path('/proc/cpuinfo').read_text().splitlines() if l.startswith('model name')),'unknown')+', Linux x86-64, '+str(os.cpu_count())+' logical CPUs','baseline':'b56c5fa','binary_bytes':{},'startup':[],'primitive_frames':[]}
with tempfile.TemporaryDirectory(prefix='rhun-canvas-measure-') as tmp:
    work=Path(tmp);config=work/'config/rhun/config';config.parent.mkdir(parents=True)
    config.write_text('[ui]\nsidebar = false\nagents_panel = false\n[files]\nrestore_session = false\nrestore_project = false\n[updates]\ncheck = false\n[git]\nenabled = false\n')
    project=work/'project';project.mkdir();(project/'main.s').write_text('mov eax, 1\n'*200)
    script=work/'startup.rsc';script.write_text('move 400 300\nprint-frames\nquit\n')
    env=dict(os.environ,HOME=str(work),XDG_CONFIG_HOME=str(work/'config'),XDG_STATE_HOME=str(work/'state'),SHELL='/nonexistent')
    rss=work/'rss'
    for label,exe in [('before',baseline),('after',ROOT/'build/rhun')]:
        stripped=work/label;subprocess.run(['strip','-o',str(stripped),str(exe)],check=True)
        report['binary_bytes'][label]=stripped.stat().st_size;samples=[]
        for sample in range(5):
            sample_home=work/(label+'-home-'+str(sample));sample_config=sample_home/'config/rhun/config';sample_config.parent.mkdir(parents=True)
            sample_config.write_text(config.read_text())
            sample_env=dict(env,HOME=str(sample_home),XDG_CONFIG_HOME=str(sample_home/'config'),XDG_STATE_HOME=str(sample_home/'state'))
            start=time.perf_counter()
            p=subprocess.run(['/usr/bin/time','-f','%M','-o',str(rss),str(stripped),str(project),'--headless','1000x700','--script',str(script)],env=sample_env,capture_output=True,check=True)
            samples.append({'elapsed_ms':round((time.perf_counter()-start)*1000,3),'max_rss_kib':int(rss.read_text()),'exit':p.returncode})
        report['startup'].append({'build':label,'samples':samples,'median_ms':statistics.median(x['elapsed_ms'] for x in samples)})
    for _ in range(5):
        p=subprocess.run(['/usr/bin/time','-f','%M','-o',str(rss),str(ROOT/'build/canvas_benchmark')],capture_output=True,text=True,check=True)
        timings={n:int(ms)/200 for n,ms in re.findall(r'(\d+) elements / 200 frames total_ms=(\d+)',p.stderr+p.stdout)}
        if set(timings)!={'100','1000'}:raise RuntimeError(p.stderr+p.stdout)
        report['primitive_frames'].append({'max_rss_kib':int(rss.read_text()),'milliseconds_per_frame':timings})
output.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
