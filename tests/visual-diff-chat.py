#!/usr/bin/env python3
"""Actual ACP boundary with a deterministic fixture, explicit response selection."""
import importlib.util,json,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('acp',Path(__file__).with_name('chat-opencode.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class VisualDiffChat(m.OpenCodeChat):
    def setUp(self):
        super().setUp()
        fixture=m.FAKE.replace("update('Reply: ');update(text)","""
        data=json.loads(text.split('\\n',1)[1])
        if os.environ.get('DIFF_CHAT_BAD'): update('Ordinary explanation, not structured claims')
        else: update(json.dumps(data))
""")
        (self.bin/'opencode').write_text(fixture)
        with self.config.open('a') as f:f.write('[ui]\nsidebar = false\nagents_panel = false\n')
    def test_explicit_send_and_completed_response_roundtrip(self):
        report=self.home/'diff.json'
        out=self.run_script('cmd radare_demo\ncmd diff_chat_send\nwait 700\ncmd diff_chat_compare\ntype 1\nkey Return\nprint-diff\ncmd diff_export\nkey ctrl+a\ntype '+str(report)+'\nkey Return')
        data=json.loads(report.read_text())
        self.assertTrue(all(r['status']==0 for r in data['results']))
        prompts=[p for p in self.messages() if p.get('method')=='session/prompt']
        self.assertEqual(len(prompts),1)
        sent=prompts[0]['params']['prompt'][0]['text']
        self.assertIn('ONLY one bare rhun-agent-claims',sent)
        self.assertEqual(json.loads(sent.split('\n',1)[1]),data['targetGraph'])
    def test_prose_and_missing_response_never_create_a_diff(self):
        self.env['DIFF_CHAT_BAD']='1'
        out=self.run_script('cmd radare_demo\ncmd diff_chat_send\nwait 700\ncmd diff_chat_compare\ntype 1\nkey Return\nprint-diff\ncmd diff_chat_compare\ntype 99\nkey Return\nprint-diff')
        self.assertNotIn('"type":"rhun-visual-diff"',out)
        self.assertEqual(len([p for p in self.messages() if p.get('method')=='session/prompt']),1)
for name in vars(m.OpenCodeChat):
    if name.startswith('test_') and name not in vars(VisualDiffChat):setattr(VisualDiffChat,name,None)
if __name__=='__main__':unittest.main()
