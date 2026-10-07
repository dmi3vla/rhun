#!/usr/bin/env python3
"""Explicit Radare2 review selection crosses the real ACP transport boundary."""
import importlib.util,json,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('acp',Path(__file__).with_name('chat-opencode.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
TRACE=Path(__file__).resolve().parents[1]/'examples/radare2/branch-demo.trace.json'
class RadareChat(m.OpenCodeChat):
    def test_ready_chat_receives_review_and_imported_evidence(self):
        with self.config.open('a') as f:f.write('[ui]\nsidebar = false\nagents_panel = false\n')
        self.run_script('cmd radare_demo\ncmd radare_trace_import\nkey ctrl+a\ntype '+str(TRACE)+'\nkey Return\nclick 100 250\ncmd radare_review_chat\nwait 700\nprint-agents')
        prompts=[p for p in self.messages() if p.get('method')=='session/prompt']
        self.assertEqual(len(prompts),1)
        data=json.loads(prompts[0]['params']['prompt'][0]['text'])
        self.assertEqual(data['type'],'rhun-canvas-request')
        self.assertIn('Review the selected Radare2',data['task'])
        self.assertEqual(data['evidence'],dict(kind='imported-address-sequence',events=7,unmapped=1))
        self.assertTrue(data['selected'])
        self.assertIn('4096',json.dumps(data['elements']))
for name in vars(m.OpenCodeChat):
    if name.startswith('test_') and name not in vars(RadareChat):setattr(RadareChat,name,None)
if __name__=='__main__':unittest.main()
