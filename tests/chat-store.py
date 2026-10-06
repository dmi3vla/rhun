#!/usr/bin/env python3
"""Persistence/resume scenarios through the real headless editor and fake CLIs."""
import importlib.util
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile
import time
import unittest
ROOT=Path(__file__).resolve().parents[1]
EXE=ROOT/'build/rhun'
def fixture(name):
    spec=importlib.util.spec_from_file_location(name,ROOT/'tests'/f'chat-{name}.py')
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
    return mod.FAKE
class ChatStore(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='rhun-chat-store-')
        self.home=Path(self.tmp.name);self.project=self.home/'project café';self.project.mkdir()
        self.bin=self.home/'bin';self.bin.mkdir()
        for name in ('codex','opencode'):
            path=self.bin/name;path.write_text(fixture(name));path.chmod(0o755)
        self.config=self.home/'config/rhun/config';self.config.parent.mkdir(parents=True)
        self.config.write_text('[git]\nenabled = false\n[updates]\ncheck = false\n')
        self.trace=self.home/'trace'
        self.env=dict(os.environ,HOME=str(self.home),PATH=str(self.bin),
                      XDG_CONFIG_HOME=str(self.home/'config'),XDG_STATE_HOME=str(self.home/'state'),
                      CHAT_TRACE=str(self.trace),SHELL='/nonexistent')
    def tearDown(self):self.tmp.cleanup()
    def run_editor(self,body,project=None):
        script=self.home/'commands.rsc';script.write_text(body+'\nquit\n')
        p=subprocess.run([EXE,project or self.project,'--headless','1000x700','--script',script],
                         env=self.env,capture_output=True,timeout=20)
        self.assertEqual(p.returncode,0,p.stderr);return p.stdout.decode()
    def state_path(self):
        files=list((self.home/'state/rhun').glob('*.chats.json'))
        self.assertEqual(len(files),1);return files[0]
    def messages(self):return [json.loads(x) for x in self.trace.read_text().splitlines()]
    def test_codex_resume_with_transcript_and_draft(self):
        self.run_editor('cmd chat_new\nwait 500\ntype First\nkey enter\nwait 300\ntype Draft café-')
        path=self.state_path();data=json.loads(path.read_text())
        self.assertEqual(data['chats'][0]['id'],'thread-fixture')
        self.assertEqual(data['chats'][0]['draft'],'Draft café-')
        self.assertEqual(stat.S_IMODE(path.stat().st_mode),0o600)
        out=self.run_editor('cmd chat_resume\nwait 600\ntype continued\nkey enter\nwait 300\nprint-agents')
        self.assertIn('agent Reply: First',out)
        self.assertIn('agent Reply: Draft café-continued',out)
        self.assertTrue(any(m.get('method')=='thread/resume' for m in self.messages()))
    def test_opencode_resume_and_no_replay_duplicates(self):
        self.run_editor('cmd chat_opencode\nwait 500\ntype First\nkey enter\nwait 300')
        out=self.run_editor('cmd chat_resume\nwait 600\ntype Second\nkey enter\nwait 300\nprint-agents')
        self.assertEqual(out.count('agent Reply: First'),1)
        self.assertIn('agent Reply: Second',out)
        self.assertTrue(any(m.get('method')=='session/load' for m in self.messages()))
    def test_tabs_preserve_provider_and_messages(self):
        out=self.run_editor('cmd chat_new\nwait 500\ntype Codex turn\nkey enter\nwait 300\n'
                            'cmd chat_opencode\nwait 600\ntype OpenCode turn\nkey enter\nwait 300\n'
                            'cmd chat_previous_tab\nwait 600\nprint-agents')
        self.assertIn('agent Reply: Codex turn',out);self.assertNotIn('agent Reply: OpenCode turn',out)
        data=json.loads(self.state_path().read_text())
        self.assertEqual([c['provider'] for c in data['chats']],[0,1])
        self.assertEqual(data['active'],0)
    def test_saved_tab_picker(self):
        out=self.run_editor('cmd chat_new\nwait 500\ncmd chat_opencode\nwait 600\ncmd chat_tabs\nprint-palette\nkey escape')
        self.assertIn('1: Codex',out);self.assertIn('2: OpenCode',out)
    def test_corrupt_state_is_not_overwritten(self):
        self.run_editor('cmd chat_new\nwait 500')
        path=self.state_path();path.write_text('{corrupt')
        self.run_editor('cmd chat_focus\nwait 500')
        self.assertEqual(path.read_text(),'{corrupt')
    def test_restart_does_not_spawn_cli_until_requested(self):
        self.run_editor('cmd chat_new\nwait 500\ntype First\nkey enter\nwait 300')
        before=len(self.messages())
        out=self.run_editor('print-agents')
        self.assertEqual(len(self.messages()),before)
        self.assertIn('agent Reply: First',out)
    def test_close_last_tab_stays_closed_after_restart(self):
        self.run_editor('cmd chat_new\nwait 500\ncmd chat_close_tab\nwait 200')
        self.assertEqual(json.loads(self.state_path().read_text())['chats'],[])
        self.run_editor('print-agents')
        self.assertEqual(json.loads(self.state_path().read_text())['chats'],[])

    def test_autosave_survives_abrupt_exit(self):
        script=self.home/'crash.rsc'
        script.write_text('cmd chat_new\nwait 500\ntype First\nkey enter\nwait 300\ntype Crash draft\nwait 5000\nquit\n')
        p=subprocess.Popen([EXE,self.project,'--headless','1000x700','--script',script],env=self.env,
                           stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        saved=False
        try:
            deadline=time.monotonic()+5
            while time.monotonic()<deadline:
                paths=list((self.home/'state/rhun').glob('*.chats.json'))
                if paths:
                    data=json.loads(paths[0].read_text())
                    if data['chats'][0]['draft']=='Crash draft': saved=True;break
                time.sleep(.05)
            self.assertTrue(saved,'draft did not autosave before final shutdown')
        finally:
            p.kill();p.wait(timeout=5)
        out=self.run_editor('cmd chat_resume\nwait 600\nkey enter\nwait 300\nprint-agents')
        self.assertIn('agent Reply: Crash draft',out)

    def test_disconnect_keeps_native_id(self):
        self.run_editor('cmd chat_new\nwait 500\ntype First\nkey enter\nwait 300\ncmd chat_disconnect\nwait 200')
        self.assertEqual(json.loads(self.state_path().read_text())['chats'][0]['id'],'thread-fixture')
    def test_busy_switch_does_not_lose_active_turn(self):
        out=self.run_editor('cmd chat_opencode\nwait 500\ntype waiting\nkey enter\nwait 200\n'
                            'cmd chat_previous_tab\ncmd chat_stop\nwait 300\ntype Continue\nkey enter\nwait 300\nprint-agents')
        self.assertIn('agent Reply: Continue',out)
if __name__=='__main__':unittest.main()
