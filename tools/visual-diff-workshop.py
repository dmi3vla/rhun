#!/usr/bin/env python3
"""Generate deliberate good/bad agent claims on the supplied rhun analysis.

Preparation uses existing build/radare-workshop scenes. --native checks live
Wayland/X11. --open cfg|memory opens a prepared interactive Diff window.
All example mistakes are synthetic; no cloud model or target execution is used.
"""
import argparse
import copy
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/visual-diff-workshop'
SOURCES=ROOT/'build/radare-workshop'


def parse_report(text):
    return json.loads(next(l for l in text.splitlines() if l.startswith('{"type":"rhun-visual-diff"')))


def prompt(command,value):
    return ['cmd '+command,'key ctrl+a','type '+str(value),'key Return']


def native(scene, claims, profile, backend=None, interactive=False):
    with tempfile.TemporaryDirectory(prefix='rhun-diff-native-') as temp:
        home=Path(temp);env=dict(os.environ)
        if not interactive:
            config=home/'config/rhun/config';config.parent.mkdir(parents=True)
            config.write_text('[ui]\nsidebar = false\nagents_panel = false\n[files]\nrestore_session = false\nrestore_project = false\n[updates]\ncheck = false\n[git]\nenabled = false\n')
            env.update(HOME=str(home),XDG_CONFIG_HOME=str(home/'config'),XDG_STATE_HOME=str(home/'state'),SHELL='/nonexistent')
        if backend:
            env['RHUN_BACKEND']=backend
            for var in (['DISPLAY'] if backend=='wayland' else ['WAYLAND_DISPLAY','WAYLAND_SOCKET']):env.pop(var,None)
        control=home/'editor.sock'
        process=subprocess.Popen([ROOT/'build/rhun',ROOT,scene,'--wait','--control',control],env=env,
                                 stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,text=True)
        try:
            deadline=time.monotonic()+8
            while not control.exists() and process.poll() is None and time.monotonic()<deadline:time.sleep(.02)
            with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as client:
                client.settimeout(10);client.connect(str(control))
                with client.makefile('r') as reader:
                    def command(value):
                        client.sendall((value+'\n').encode());lines=[]
                        while True:
                            line=reader.readline()
                            if line=='ok\n':
                                time.sleep(.12)
                                return ''.join(lines)
                            assert line not in ('','error\n'),value
                            lines.append(line)
                    for value in prompt('diff_load',claims):command(value)
                    command('cmd diff_filter')
                    initial=parse_report(command('print-diff'))
                    assert not initial['stale']
                    command('key d')
                    if profile=='memory':command('key v')
                    if interactive:
                        print('Diff ready. D / Shift+D: navigate; V: Memory 2D/3D; middle drag: orbit/pan; close window to exit.',flush=True)
                    else:
                        prefix=OUT/(backend+'-'+profile)
                        command('shot '+str(prefix.with_suffix('.ppm')))
                        if profile=='memory':
                            command('key f')
                            folded=parse_report(command('print-diff'))
                            assert folded['results']==initial['results'] and not folded['stale']
                            command('shot '+str(OUT/(backend+'-memory-fold.ppm')))
                        command('key shift+d')
                        command('cmd diff_toggle')
                        hidden=parse_report(command('print-diff'))
                        assert hidden['show']==0 and hidden['results']==initial['results']
                        command('quit')
            assert process.wait(timeout=None if interactive else 8)==0
            diagnostics=process.stderr.read()
            assert not diagnostics,diagnostics
        finally:
            if process.poll() is None:process.terminate();process.wait(timeout=8)
            process.stderr.close()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native',action='store_true')
    parser.add_argument('--open',choices=['cfg','memory'])
    args=parser.parse_args()
    scenes={'cfg':SOURCES/'main.rhun-canvas','memory':SOURCES/'mem_alloc-memory.rhun-canvas'}
    if args.open:
        claims=OUT/(args.open+'-bad.claims.json')
        if not claims.exists():parser.error('Run this script without --open first to prepare examples')
        native(scenes[args.open],claims,args.open,interactive=True)
        return
    if not all(p.exists() for p in scenes.values()):parser.error('Prepare source scenes with tools/radare-workshop.py first')
    binary=ROOT/'rhun'
    source_manifest=json.loads((SOURCES/'manifest.json').read_text())
    sha=hashlib.sha256(binary.read_bytes()).hexdigest()
    if sha!=source_manifest['sha256']:parser.error('ELF changed: regenerate Radare2 workshop before this Diff')
    OUT.mkdir(parents=True,exist_ok=True)
    manifest=dict(binary=str(binary),sha256=sha,synthetic_agent_responses=True,profiles={},native=[])
    with tempfile.TemporaryDirectory(prefix='rhun-diff-workshop-') as temp:
        home=Path(temp);config=home/'config/rhun/config';config.parent.mkdir(parents=True)
        config.write_text('[ui]\nsidebar = false\nagents_panel = false\n[files]\nrestore_session = false\nrestore_project = false\n[updates]\ncheck = false\n[git]\nenabled = false\n')
        env=dict(os.environ,HOME=str(home),XDG_CONFIG_HOME=str(home/'config'),XDG_STATE_HOME=str(home/'state'))
        def run(name,scene,actions):
            script=home/'actions.rsc';script.write_text('\n'.join(actions+['quit'])+'\n')
            result=subprocess.run([ROOT/'build/rhun',ROOT,scene,'--headless','1366x768','--script',script],env=env,
                                  capture_output=True,text=True,timeout=30)
            (OUT/(name+'.log')).write_text(result.stdout+result.stderr)
            assert result.returncode==0,result.stderr
            return result.stdout
        for profile,scene in scenes.items():
            template=OUT/(profile+'-context.json')
            run(profile+'-context',scene,prompt('diff_context',template))
            good=json.loads(template.read_text())
            good_path=OUT/(profile+'-good.claims.json');good_path.write_text(json.dumps(good,indent=2))
            text=run(profile+'-good',scene,prompt('diff_load',good_path)+['print-diff'])
            assert all(r['status']==0 for r in parse_report(text)['results'])
            bad=copy.deepcopy(good)
            omitted=bad['nodes'].pop()['id']
            bad['links']=[e for e in bad['links'] if omitted not in (e['from'],e['to'])]
            bad['nodes'][0].update(size=64,confidence=100)
            bad['nodes'][1].update(address=hex(int(bad['nodes'][1]['address'],16)+1),confidence=100)
            ghost=dict(bad['nodes'][0],id='AI_GHOST',address='0xfffffffffffff000',
                       label='SYNTHETIC AI invention; absent from supplied Base',kind=3,size=64,capacity=128,state=0)
            bad['nodes'].append(ghost)
            assert bad['links']
            bad['links'][0]['to']='AI_GHOST'
            bad_path=OUT/(profile+'-bad.claims.json');bad_path.write_text(json.dumps(bad,indent=2))
            actions=prompt('diff_load',bad_path)+['cmd diff_filter']
            actions+=prompt('diff_export',OUT/(profile+'-report.json'))
            actions+=prompt('diff_export',OUT/(profile+'-report.md'))
            actions+=['key d','shot '+str(OUT/(profile+'-bad-2d.ppm'))]
            if profile=='memory':actions+=['key v','shot '+str(OUT/'memory-bad-3d.ppm')]
            actions+=['print-diff','print-canvas']
            text=run(profile+'-bad',scene,actions)
            report=parse_report(text)
            counts={str(status):sum(r['status']==status for r in report['results']) for status in range(5)}
            assert all(counts[str(status)] for status in (1,2,3,4)),counts
            source=json.loads(scene.read_text())
            output_scene=json.loads(next(l for l in text.splitlines() if l.startswith('{"type":"rhun-canvas"')))
            assert source==output_scene,'Diff changed evidence'
            manifest['profiles'][profile]=dict(scene=str(scene),claims=str(bad_path),counts=counts,
                    omitted=omitted,ghost='AI_GHOST',source_unchanged=True)
            print(profile,counts,flush=True)
    if args.native:
        backends=[b for b,v in [('wayland','WAYLAND_DISPLAY'),('x11','DISPLAY')] if os.environ.get(v)]
        assert backends,'--native requires a display'
        for backend in backends:
            for profile,scene in scenes.items():
                native(scene,OUT/(profile+'-bad.claims.json'),profile,backend=backend)
                manifest['native'].append(backend+' '+profile)
                print('Native OK:',backend,profile,flush=True)
    assert hashlib.sha256(binary.read_bytes()).hexdigest()==sha
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('Artifacts:',OUT)

if __name__=='__main__':main()
