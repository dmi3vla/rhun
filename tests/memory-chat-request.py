#!/usr/bin/env python3
import importlib.util,json,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('acp',Path(__file__).with_name('chat-opencode.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class MemoryChat(m.OpenCodeChat):
    def test_explicit_bounded_evidence_crosses_acp(self):
        with self.config.open('a') as f:f.write('[ui]\nsidebar = false\nagents_panel = false\n')
        a=['cmd memory_demo']+['cmd memory_next']*6+['cmd memory_select_next']*6+['cmd memory_review_chat','wait 700','print-agents']
        self.run_script('\n'.join(a))
        prompts=[p for p in self.messages() if p.get('method')=='session/prompt'];self.assertEqual(len(prompts),1)
        d=json.loads(prompts[0]['params']['prompt'][0]['text'])
        self.assertEqual((d['type'],d['provenance'],d['allocator']),('rhun-memory-review',2,'rhun-v1'))
        self.assertEqual(d['selected'],'buf');self.assertEqual({n['id'] for n in d['nodes']},{'buf','H1'})
        self.assertEqual(d['links'][0]['kind'],3);self.assertEqual(d['allowed'],[])
        self.assertIn('missing evidence',d['task'])
    def test_no_selection_does_not_send(self):
        self.run_script('cmd memory_demo\ncmd memory_review_chat\nwait 100')
        self.assertFalse([p for p in self.messages() if p.get('method')=='session/prompt'])
for name in vars(m.OpenCodeChat):
    if name.startswith('test_') and name not in vars(MemoryChat):setattr(MemoryChat,name,None)
if __name__=='__main__':unittest.main()
