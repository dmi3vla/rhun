#!/usr/bin/env python3
"""OpenCode ACP UI scenarios with a fragmented, deterministic native CLI."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / 'build/rhun'
FAKE = r'''#!/usr/bin/python3
import json, os, sys
assert sys.argv[1:] == ['acp']
active = False
pending = []
def emit(data):
    raw = json.dumps(dict(jsonrpc='2.0', **data), ensure_ascii=False).encode()+b'\n'
    for pos in range(0,len(raw),5): os.write(1,raw[pos:pos+5])
def complete(reason='end_turn'):
    global active
    emit({'id':'turn','result':{'stopReason':reason}})
    active=False
def update(text, session='open-fixture'):
    emit({'method':'session/update','params':{'sessionId':session,'update':{
        'sessionUpdate':'agent_message_chunk','content':{'type':'text','text':text}}}})
def permission(ident, always=False):
    pending.append(ident)
    emit({'id':ident,'method':'session/request_permission','params':{
        'sessionId':'open-fixture','toolCall':{'title':'Run echo test', 'rawInput':{'command':'echo test'}},
        'options':[{'kind':'allow_always','optionId':'NEVER'},
                   {'kind':'allow_once','optionId':'allow "one" \\ café'},
                   {'kind':'reject_once','optionId':'deny one'}] if not always else [
                       {'kind':'allow_always','optionId':'NEVER'}]}})
os.write(2,b'non-json diagnostics\n')
for line in sys.stdin:
    msg=json.loads(line)
    assert msg.get('jsonrpc')=='2.0'
    with open(os.environ['CHAT_TRACE'],'a') as f: f.write(json.dumps(msg)+'\n')
    method=msg.get('method')
    if method is None:
        if msg['id'] in pending:
            pending.remove(msg['id'])
            outcome=msg['result']['outcome']
            assert outcome['outcome'] in ('selected','cancelled')
            if outcome['outcome']=='cancelled' and text=='always': complete()
            if outcome['outcome']=='selected':
                assert outcome['optionId'] in ('allow "one" \\ café','deny one')
                if not pending: complete()
        else:
            assert msg['error']['code']==-32601
            complete()
    elif method=='initialize':
        assert msg['params']['protocolVersion']==1
        assert msg['params']['clientCapabilities']=={}
        emit({'id':msg['id'],'result':{'protocolVersion':1}})
    elif method=='session/new':
        assert msg['params']['cwd']==os.getcwd()
        assert msg['params']['mcpServers']==[]
        emit({'id':msg['id'],'result':{'sessionId':'open-fixture','models':{
            'availableModels':[{'modelId':'provider/model-fixture','name':'Fixture'}]},
            'configOptions':[{'id':'model','type':'select','options':[
                {'group':'models','name':'Models','options':[{'value':'provider/model-fixture','name':'Fixture'}]}]}]}})
    elif method=='session/set_config_option':
        assert msg['params']=={'sessionId':'open-fixture','configId':'model','value':'provider/model-fixture'}
        emit({'id':msg['id'],'result':{}})
    elif method=='session/prompt':
        assert not active
        active=True
        assert msg['params']['sessionId']=='open-fixture'
        text=msg['params']['prompt'][0]['text']
        if text=='waiting': continue
        if text in ('permission','queued','always'):
            permission('rpc "permission" \\ café', text=='always')
            if text=='queued': permission(42)
            continue
        if text=='unknown':
            emit({'id':77,'method':'filesystem/unadvertised','params':{}})
            continue
        if text=='error':
            emit({'id':msg['id'],'error':{'code':-32000,'message':'OpenCode model unavailable'}})
            active=False
            continue
        update('FOREIGN', 'another-session')
        update('Reply: ');update(text)
        complete()
    elif method=='session/cancel':
        assert 'id' not in msg
        assert not pending
        assert msg['params']['sessionId']=='open-fixture'
        complete('cancelled')
'''

class OpenCodeChat(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='rhun-opencode-chat-')
        self.home=Path(self.tmp.name)
        self.project=self.home/'project café with spaces'; self.project.mkdir()
        self.bin=self.home/'bin'; self.bin.mkdir()
        cli=self.bin/'opencode'; cli.write_text(FAKE); cli.chmod(0o755)
        self.trace=self.home/'trace.jsonl'
        self.env=dict(os.environ, HOME=str(self.home),PATH=str(self.bin),
                      XDG_CONFIG_HOME=str(self.home/'config'),XDG_STATE_HOME=str(self.home/'state'),
                      CHAT_TRACE=str(self.trace),SHELL='/nonexistent')
        self.config=self.home/'config/rhun/config'; self.config.parent.mkdir(parents=True)
        self.config.write_text('[updates]\ncheck = false\n[git]\nenabled = false\n')
    def tearDown(self): self.tmp.cleanup()
    def run_script(self,body,initial='chat_opencode'):
        script=self.home/'actions.rsc'
        script.write_text(f'cmd {initial}\nwait 500\n'+body+'\nquit\n')
        r=subprocess.run([EXE,self.project,'--headless','1000x700','--script',script],
                         env=self.env,capture_output=True,timeout=15)
        self.assertEqual(r.returncode,0,r.stderr)
        return r.stdout.decode()
    def messages(self): return [json.loads(x) for x in self.trace.read_text().splitlines()]
    def test_stream_followup_and_foreign_session(self):
        text='Hello "OpenCode" \\ café'
        out=self.run_script(f'type {text}\nkey enter\nwait 300\ntype Follow up\nkey enter\nwait 300\nprint-agents')
        self.assertIn('agent Reply: '+text,out)
        self.assertIn('agent Reply: Follow up',out);self.assertNotIn('FOREIGN',out)
        self.assertEqual([m['method'] for m in self.messages()],['initialize','session/new','session/prompt','session/prompt'])
    def test_permission_is_explicit_and_once(self):
        self.run_script('type permission\nkey enter\nwait 300\nkey enter\nwait 100')
        self.assertFalse(any('method' not in m for m in self.messages()))
    def test_accept_then_continue(self):
        out=self.run_script('type permission\nkey enter\nwait 300\ncmd chat_approve\nwait 300\ntype Continue\nkey enter\nwait 300\nprint-agents')
        self.assertIn('agent Reply: Continue',out)
        reply=next(m for m in self.messages() if 'method' not in m)
        self.assertEqual(reply['result']['outcome'],{'outcome':'selected','optionId':'allow "one" \\ café'})
    def test_queued_reject_and_accept(self):
        self.run_script('type queued\nkey enter\nwait 300\ncmd chat_decline\ncmd chat_approve\nwait 300')
        replies=[m for m in self.messages() if 'method' not in m]
        self.assertEqual(replies[0]['result']['outcome']['optionId'],'deny one')
        self.assertEqual(replies[1]['id'],42)
    def test_cancel_pending_permissions_and_continue(self):
        out=self.run_script('type queued\nkey enter\nwait 300\ncmd chat_stop\nwait 300\ntype Continue\nkey enter\nwait 300\nprint-agents')
        self.assertIn('agent Reply: Continue',out)
        replies=[m for m in self.messages() if 'method' not in m]
        self.assertEqual(len(replies),2)
        self.assertTrue(all(m['result']['outcome']=={'outcome':'cancelled'} for m in replies))
    def test_always_only_permission_is_cancelled(self):
        self.run_script('type always\nkey enter\nwait 300')
        replies=[m for m in self.messages() if 'method' not in m]
        self.assertEqual(replies[0]['result']['outcome'],{'outcome':'cancelled'})
    def test_cancel_turn_keeps_runtime(self):
        out=self.run_script('type waiting\nkey enter\nwait 300\ncmd chat_stop\nwait 300\ntype Continue\nkey enter\nwait 300\nprint-agents')
        self.assertIn('agent Reply: Continue',out)
        self.assertEqual(sum(m.get('method')=='initialize' for m in self.messages()),1)
    def test_error_and_unknown_request_are_recoverable(self):
        out=self.run_script('type unknown\nkey enter\nwait 300\ntype error\nkey enter\nwait 300\ntype Continue\nkey enter\nwait 300\nprint-agents')
        self.assertIn('OpenCode model unavailable',out);self.assertIn('agent Reply: Continue',out)
    def test_cli_setting_and_catalog(self):
        self.config.write_text(self.config.read_text()+f'[agents]\nopencode_cli = {self.bin / "opencode"}\n')
        self.env['PATH']='/nonexistent'
        out=self.run_script('cmd chat_models\nprint-agents')
        self.assertIn('provider/model-fixture',out)
    def test_switch_from_codex_uses_new_runtime(self):
        spec=importlib.util.spec_from_file_location('codex_fixture',ROOT/'tests/chat-codex.py')
        mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
        cli=self.bin/'codex';cli.write_text(mod.FAKE);cli.chmod(0o755)
        out=self.run_script('type Before\nkey enter\nwait 300\ncmd chat_opencode\nwait 600\ntype After\nkey enter\nwait 300\nprint-agents',initial='chat_new')
        self.assertIn('agent Reply: After',out);self.assertNotIn('agent Reply: Before',out)
        self.assertTrue(any(m.get('method')=='session/new' for m in self.messages()))
    def test_choose_model_then_prompt(self):
        out=self.run_script('cmd chat_choose_model\nprint-palette\nkey enter\nwait 300\ntype After model\nkey enter\nwait 300\nprint-agents')
        self.assertIn('provider/model-fixture',out)
        self.assertIn('agent Reply: After model',out)
        self.assertTrue(any(m.get('method')=='session/set_config_option' for m in self.messages()))
    def test_preview(self):
        target=os.environ.get('RHUN_OPENCODE_PREVIEW')
        shot=Path(target) if target else self.home/'permission.ppm'
        self.run_script(f'type permission\nkey enter\nwait 300\nshot {shot}')
        self.assertTrue(shot.is_file())

if __name__=='__main__': unittest.main()
