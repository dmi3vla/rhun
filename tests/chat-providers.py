#!/usr/bin/env python3
"""Grok ACP and Pi JSONL RPC adapters, without network/model calls."""
import importlib.util
import json
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
def load(name):
    spec=importlib.util.spec_from_file_location('fixture_'+name,ROOT/'tests'/('chat-'+name+'.py'))
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod);return mod
store=load('store');acp=load('opencode')
PI=r'''#!/usr/bin/python3
import json,os,sys
assert sys.argv[1:5]==['--mode','rpc','--tools','read,grep,find,ls']
if len(sys.argv)>5: assert sys.argv[5:]==['--session','/fixture/pi-session.jsonl']
def emit(msg):
    raw=json.dumps(msg,ensure_ascii=False).encode()+b'\n'
    for i in range(0,len(raw),3):os.write(1,raw[i:i+3])
def response(msg,success=True,data=None):
    emit(dict(type='response',id=msg.get('id'),command=msg['type'],success=success,data=data or {}))
def finish(text):
    emit({'type':'message_start','message':{'role':'assistant'}})
    for chunk in ['Pi reply: ',text]:emit({'type':'message_update','assistantMessageEvent':{'type':'text_delta','delta':chunk}})
    emit({'type':'agent_end'})
    emit({'type':'agent_settled'})
for line in sys.stdin:
    msg=json.loads(line)
    with open(os.environ['CHAT_TRACE'],'a') as f:f.write(json.dumps(msg)+'\n')
    kind=msg['type']
    if kind=='get_state':response(msg,data={'sessionFile':'/fixture/pi-session.jsonl'})
    elif kind=='get_available_models':response(msg,data={'models':[{'provider':'vendor','id':'model/café'}]})
    elif kind=='set_model':
        assert msg['provider']=='vendor' and msg['modelId']=='model/café'
        response(msg)
    elif kind=='abort':response(msg);emit({'type':'agent_settled'})
    elif kind=='extension_ui_response':finish(json.dumps(msg,ensure_ascii=False))
    elif kind=='prompt':
        text=msg['message']
        if text=='error':response(msg,False);continue
        response(msg,data={'disposition':'handled' if text=='handled' else 'started'})
        if text=='foreign':emit({'id':'foreign','type':'response','command':'prompt','success':False});continue
        if text=='tool':emit({'type':'tool_execution_end','toolName':'read','result':{'content':[{'type':'text','text':'Pi tool output'}]}})
        if text=='waiting':emit({'type':'agent_end'});continue
        if text=='handled':continue
        if text in ['confirm','input','select']:
            emit({'type':'extension_ui_request','id':'request café','method':text,'title':'Native extension question','options':['One','Two café']})
            emit({'type':'extension_ui_request','id':'status update','method':'setStatus','text':'working'})
            continue
        finish(text)
'''
class Grok(acp.OpenCodeChat):
    def setUp(self):
        super().setUp()
        cli=self.bin/'grok'
        cli.write_text(acp.FAKE.replace("['acp']","['agent','--no-leader','stdio']").replace("'session/update'","'_x.ai/session/update'"))
        cli.chmod(0o755)
    def run_script(self,body,initial='chat_grok'):
        return super().run_script(body,initial)
    def test_cli_setting_and_catalog(self):
        out=self.run_script('cmd chat_models\nprint-agents')
        self.assertIn('provider/model-fixture',out)
    def test_switch_from_codex_uses_new_runtime(self):
        mod=load('codex');cli=self.bin/'codex';cli.write_text(mod.FAKE);cli.chmod(0o755)
        out=self.run_script('cmd chat_grok\nwait 600\ntype Grok turn\nkey enter\nwait 300\nprint-agents',initial='chat_new')
        self.assertIn('agent Reply: Grok turn',out)
    def test_mirrored_notifications_are_not_duplicated(self):
        cli=self.bin/'grok'
        text=cli.read_text().replace("def emit(data):", "def emit_one(data):")
        idx=text.index("def complete(")
        text=text[:idx]+"""def emit(data):
    emit_one(data)
    if data.get('method')=='_x.ai/session/update':
        emit_one(dict(data,method='session/update'))
"""+text[idx:]
        cli.write_text(text)
        out=self.run_script('type mirrored\nkey enter\nwait 300\nprint-agents')
        self.assertIn('agent Reply: mirrored',out)
        self.assertNotIn('Reply: Reply:',out)
class Pi(store.ChatStore):
    def setUp(self):
        super().setUp();cli=self.bin/'pi';cli.write_text(PI);cli.chmod(0o755)
    def run_pi(self,body):return self.run_editor('cmd chat_pi\nwait 500\n'+body)
    def test_native_tool_result_is_rendered(self):
        self.run_pi('type tool\nkey enter\nwait 300')
        data=json.loads(self.state_path().read_text())
        self.assertTrue(any('Pi tool output' in m['text'] for m in data['chats'][0]['messages']))
    def test_foreign_error_does_not_finish_active_turn(self):
        self.run_pi('type foreign\nkey enter\nwait 300\ntype Continued draft\nkey enter\nwait 100\ncmd chat_stop\nwait 300\nkey enter\nwait 300')
        self.assertTrue(any(m['type']=='abort' for m in self.messages()))
        self.assertEqual(sum(m['type']=='prompt' for m in self.messages()),2)
    def test_auto_prefers_installed_opencode(self):
        self.run_editor('cmd chat_auto\nwait 500')
        self.assertTrue(any(m.get('method')=='session/new' for m in self.messages()))
    def test_prompt_followup_and_escaping(self):
        out=self.run_pi('type café "quoted"\nkey enter\nwait 300\ntype second\nkey enter\nwait 300\nprint-agents')
        self.assertIn('agent Pi reply: café "quoted"',out);self.assertIn('agent Pi reply: second',out)
    def test_native_resume_and_provider_persistence(self):
        self.run_pi('type first\nkey enter\nwait 300\ntype Draft')
        data=json.loads(self.state_path().read_text())
        self.assertEqual(data['chats'][0]['provider'],3)
        self.assertEqual(data['chats'][0]['id'],'/fixture/pi-session.jsonl')
        out=self.run_editor('cmd chat_resume\nwait 600\nkey enter\nwait 300\nprint-agents')
        self.assertIn('agent Pi reply: Draft',out)
    def test_abort_and_continue(self):
        out=self.run_pi('type waiting\nkey enter\nwait 300\ncmd chat_stop\nwait 300\ntype continued\nkey enter\nwait 300\nprint-agents')
        self.assertIn('agent Pi reply: continued',out)
    def test_model_selection(self):
        self.run_pi('cmd chat_choose_model\nwait 300\nkey enter\nwait 300\ntype model turn\nkey enter\nwait 300')
        self.assertTrue(any(m['type']=='set_model' for m in self.messages()))
        self.assertTrue(any(m['type']=='prompt' for m in self.messages()))
    def test_confirm_requires_explicit_approval(self):
        self.run_pi('type confirm\nkey enter\nwait 300\nkey enter\nwait 100\ncmd chat_approve\nwait 300')
        reply=next(m for m in self.messages() if m['type']=='extension_ui_response')
        self.assertEqual(reply['confirmed'],True);self.assertEqual(reply['id'],'request café')
    def test_input_uses_separate_reply(self):
        self.run_pi('type input\nkey enter\nwait 300\ntype answer café\nkey enter\nwait 300')
        reply=next(m for m in self.messages() if m['type']=='extension_ui_response')
        self.assertEqual(reply['value'],'answer café')
    def test_cancel_closes_owned_selection_picker(self):
        out=self.run_pi('type select\nkey enter\nwait 300\ncmd chat_stop\nwait 300\nprint-palette\ntype Continue\nkey enter\nwait 300\nprint-agents')
        self.assertIn('none',out);self.assertIn('agent Pi reply: Continue',out)
        self.assertTrue(any(m.get('cancelled') for m in self.messages()))
    def test_native_dialog_timeout_does_not_block_next_turn(self):
        cli=self.bin/'pi'
        cli.write_text(cli.read_text().replace("            emit({'type':'extension_ui_request','id':'status update'","            if text=='input':emit({'type':'agent_settled'});continue\n            emit({'type':'extension_ui_request','id':'status update'"))
        out=self.run_pi('type input\nkey enter\nwait 300\ntype Continue\nkey enter\nwait 300\nprint-agents')
        self.assertIn('agent Pi reply: Continue',out)
    def test_selection_uses_native_option(self):
        self.run_pi('type select\nkey enter\nwait 300\nkey down\nkey enter\nwait 300')
        reply=next(m for m in self.messages() if m['type']=='extension_ui_response')
        self.assertEqual(reply['value'],'Two café')
    def test_stop_cancels_pending_input(self):
        self.run_pi('type input\nkey enter\nwait 300\ncmd chat_stop\nwait 300')
        self.assertTrue(any(m.get('cancelled') for m in self.messages()))
    def test_handled_and_failed_commands_allow_next_turn(self):
        out=self.run_pi('type handled\nkey enter\nwait 300\ntype error\nkey enter\nwait 300\ntype continue\nkey enter\nwait 300\nprint-agents')
        self.assertIn('agent Pi reply: continue',out)
for name in vars(store.ChatStore):
    if name.startswith('test_') and name not in vars(Pi):setattr(Pi,name,None)
if __name__=='__main__':unittest.main()
