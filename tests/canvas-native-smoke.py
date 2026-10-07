#!/usr/bin/env python3
"""Opt-in live Wayland/X11 smoke; isolated state, no clipboard or user files.
Run RHUN_CANVAS_NATIVE_SMOKE=1 python3 tests/canvas-native-smoke.py.
--script precedes the native event loop, so drive a running window via --control.
"""
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time
import unittest
ROOT=Path(__file__).resolve().parents[1]
ENABLED=os.environ.get('RHUN_CANVAS_NATIVE_SMOKE')=='1'
@unittest.skipUnless(ENABLED,'opt-in live display check')
class NativeCanvasSmoke(unittest.TestCase):
    def check_backend(self,backend):
        with tempfile.TemporaryDirectory(prefix='rhun-canvas-native-') as tmp:
            home=Path(tmp);config=home/'config/rhun/config';config.parent.mkdir(parents=True)
            config.write_text('[ui]\nsidebar = false\nagents_panel = false\n[files]\nrestore_session = false\nrestore_project = false\n[updates]\ncheck = false\n[git]\nenabled = false\n')
            env=dict(os.environ,HOME=str(home),XDG_CONFIG_HOME=str(home/'config'),XDG_STATE_HOME=str(home/'state'),SHELL='/nonexistent',RHUN_BACKEND=backend)
            if backend=='wayland':env.pop('DISPLAY',None)
            else:env.pop('WAYLAND_DISPLAY',None);env.pop('WAYLAND_SOCKET',None)
            control=home/'editor.sock'
            process=subprocess.Popen([ROOT/'build/rhun',home,'--wait','--empty','--control',control],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,text=True)
            client=None;reader=None
            try:
                deadline=time.monotonic()+5
                while not control.exists() and process.poll() is None and time.monotonic()<deadline:time.sleep(.02)
                self.assertTrue(control.exists(),'window/control startup failed')
                client=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM);client.settimeout(6);client.connect(str(control));reader=client.makefile('r')
                def command(value):
                    client.sendall((value+'\n').encode());result=[]
                    while True:
                        line=reader.readline()
                        if line=='ok\n':return ''.join(result)
                        self.assertNotIn(line,('', 'error\n'),value);result.append(line)
                for value in ['cmd canvas_new','key r','move 100 200','down','move 220 280','up']:
                    command(value);time.sleep(.15)
                output=command('print-canvas')
                scene=json.loads(next(l for l in output.splitlines() if l.startswith('{"type":"rhun-canvas"')))
                self.assertEqual(len(scene['elements']),1)
                self.assertEqual(scene['elements'][0]['kind'],1)
                command('cmd canvas_graph_demo');time.sleep(.3)
                graph=json.loads(command('print-graph'))
                self.assertEqual(len(graph['nodes']),11)
                self.assertEqual(graph['versions'],[8,8,8,7])
                command('cmd radare_demo');time.sleep(.2)
                command('cmd radare_trace_import');command('key ctrl+a')
                command('type '+str(ROOT/'examples/radare2/branch-demo.trace.json'));command('key Return');time.sleep(.2)
                trace=json.loads(command('print-radare-trace'))
                self.assertEqual((trace['events'],trace['unmapped']),(7,1))
                command('key ]');trace=json.loads(command('print-radare-trace'))
                self.assertEqual(trace['cursor'],1)
                command('quit');self.assertEqual(process.wait(timeout=5),0)
                self.assertEqual(process.stderr.read(),'')
            finally:
                if reader:reader.close()
                if client:client.close()
                if process.poll() is None:
                    process.terminate();process.wait(timeout=5)
                process.stderr.close()
    @unittest.skipUnless(os.environ.get('WAYLAND_DISPLAY'),'requires Wayland display')
    def test_wayland(self):self.check_backend('wayland')
    @unittest.skipUnless(os.environ.get('DISPLAY'),'requires X11 display')
    def test_x11(self):self.check_backend('x11')
if __name__=='__main__':unittest.main()
