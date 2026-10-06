#!/usr/bin/env python3
"""Adversarial frames/context and tool/assistant ordering through the editor."""
import importlib.util
import json
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('store_fixture',ROOT/'tests/chat-store.py')
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
class Hardening(mod.ChatStore):
    def fixture(self,code):
        cli=self.bin/'codex'
        cli.write_text(cli.read_text().replace("for chunk in ['Reply: ', text]:",code+"\n        for chunk in ['Reply: ', text]:"))
    def turn(self,text='test',tail='print-agents'):
        return self.run_editor('cmd chat_new\nwait 500\ntype '+text+'\nkey enter\nwait 1500\n'+tail)
    def missing_rollout_fixture(self):
        cli=self.bin/'codex'
        cli.write_text(cli.read_text().replace("elif method in ('thread/start', 'thread/resume'):","elif method == 'thread/resume':\n        emit({'id':msg['id'],'error':{'code':-32600,'message':'no rollout found for thread id thread-fixture'}})\n    elif method == 'thread/start':"))
    def test_empty_codex_thread_recovery_preserves_draft(self):
        self.run_editor('cmd chat_new\nwait 500\ntype Retained draft')
        self.missing_rollout_fixture()
        out=self.run_editor('cmd chat_resume\nwait 600\nkey enter\nwait 300\nprint-agents')
        self.assertIn('agent Reply: Retained draft',out)
        self.assertEqual(sum(m.get('method')=='thread/start' for m in self.messages()),2)
    def test_missing_nonempty_codex_thread_never_starts_fresh(self):
        self.run_editor('cmd chat_new\nwait 500\ntype Existing conversation\nkey enter\nwait 300')
        self.missing_rollout_fixture()
        out=self.run_editor('cmd chat_resume\nwait 600\nprint-agents')
        self.assertIn('agent Reply: Existing conversation',out)
        self.assertEqual(sum(m.get('method')=='thread/start' for m in self.messages()),1)
    def test_foreign_turn_tool_and_delta_are_ignored(self):
        self.fixture("""emit({'method':'item/agentMessage/delta','params':{'threadId':'thread-fixture','turnId':'old-turn','itemId':'foreign','delta':'FOREIGN'}})
        emit({'method':'item/started','params':{'threadId':'thread-fixture','turnId':'old-turn','item':{'type':'commandExecution','command':'FOREIGN command'}}})""")
        out=self.turn();self.assertNotIn('FOREIGN',out);self.assertIn('agent Reply: test',out)
    def test_multiple_assistant_items_keep_earlier_text_and_tools(self):
        self.fixture("""emit({'method':'item/agentMessage/delta','params':{'threadId':'thread-fixture','turnId':'turn-fixture','itemId':'earlier','delta':'Earlier answer'}})
        emit({'method':'item/completed','params':{'threadId':'thread-fixture','turnId':'turn-fixture','item':{'type':'commandExecution','status':'completed','command':'echo fixture','aggregatedOutput':'Fixture output'}}})""")
        out=self.turn();self.assertIn('agent Earlier answer',out);self.assertIn('agent Reply: test',out)
        data=json.loads(self.state_path().read_text());text='\n'.join(m['text'] for m in data['chats'][0]['messages'])
        self.assertIn('echo fixture',text);self.assertIn('Fixture output',text)
    def test_foreign_thread_approval_is_not_shown_or_accepted(self):
        self.fixture("""pending_ids.add(919)
        emit({'id':919,'method':'item/commandExecution/requestApproval','params':{'threadId':'foreign-thread','command':'FOREIGN command'}})
        continue""")
        out=self.turn(tail='cmd chat_approve\nwait 300\nprint-agents')
        self.assertNotIn('FOREIGN command',out)
        reply=next(m for m in self.messages() if m.get('id')==919 and 'method' not in m)
        self.assertIn('error',reply)
    def test_invalid_utf8_protocol_closes_runtime(self):
        self.fixture("os.write(1,b'{\"method\":\"ignored\",\"params\":\"\\xff\"}\\n')\n        continue")
        out=self.turn();self.assertIn('Invalid or oversized provider protocol',out)
    def test_invalid_utf8_file_context_does_not_send_bytes(self):
        (self.project/'invalid.md').write_bytes(b'hello\xffworld')
        self.run_editor('cmd chat_new\nwait 500\ncmd chat_attach_file\ntype invalid\nkey enter\nkey enter\nwait 300')
        self.assertFalse(any(m.get('method')=='turn/start' for m in self.messages()))
    def test_nul_in_image_path_does_not_open_truncated_path(self):
        self.run_editor('cmd chat_new\nwait 500')
        path=self.state_path();data=json.loads(path.read_text())
        data['chats'][0]['draft']='@image: "missing\\u0000suffix.png"'
        path.write_text(json.dumps(data))
        self.run_editor('cmd chat_resume\nwait 500\nkey enter\nwait 300')
        self.assertFalse(any(m.get('method')=='turn/start' for m in self.messages()))
    def test_malformed_json_escapes_close_runtime(self):
        original=(self.bin/'codex').read_text()
        for escaped in [r'\q',r'\u00zz',r'\ud800',r'\udfff']:
            with self.subTest(escaped=escaped):
                (self.bin/'codex').write_text(original)
                raw=b'{"method":"ignored","params":"'+escaped.encode()+b'"}\n'
                self.fixture('os.write(1,'+repr(raw)+')\n        continue')
                out=self.turn();self.assertIn('Invalid or oversized provider protocol',out)
    def test_malformed_utf8_saved_state_is_retained(self):
        self.run_editor('cmd chat_new\nwait 500')
        path=self.state_path();raw=path.read_bytes().replace(b'"draft":""',b'"draft":"\xff"');path.write_bytes(raw)
        self.run_editor('print-agents');self.assertEqual(path.read_bytes(),raw)
    def test_transcript_message_limit_closes_without_losing_snapshot(self):
        self.fixture("""for i in range(2100):
            emit({'method':'item/completed','params':{'threadId':'thread-fixture','turnId':'turn-fixture','item':{'type':'commandExecution','command':'bounded tool'}}})
        continue""")
        self.turn(tail='print-chat-status')
        data=json.loads(self.state_path().read_text())
        self.assertEqual(len(data['chats'][0]['messages']),2048)
for name in vars(mod.ChatStore):
    if name.startswith('test_') and name not in vars(Hardening):setattr(Hardening,name,None)
if __name__=='__main__':unittest.main()
