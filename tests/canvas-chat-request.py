#!/usr/bin/env python3
"""Existing ACP transport carries the bounded canvas request, with no network."""
import importlib.util,json,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('acp',Path(__file__).with_name('chat-opencode.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class CanvasChat(m.OpenCodeChat):
    def test_ready_chat_receives_structured_selected_context(self):
        with self.config.open('a') as f:f.write('[ui]\nsidebar = false\nagents_panel = false\n')
        self.run_script('cmd canvas_new\nkey e\nmove 100 200\ndown\nmove 220 280\nup\ncmd canvas_request_chat\nwait 700\nprint-agents')
        prompts=[p for p in self.messages() if p.get('method')=='session/prompt']
        self.assertEqual(len(prompts),1)
        data=json.loads(prompts[0]['params']['prompt'][0]['text'])
        self.assertEqual(data['type'],'rhun-canvas-request')
        self.assertEqual(data['selected'],[1]);self.assertEqual(data['revision'],1)
for name in vars(m.OpenCodeChat):
    if name.startswith('test_') and name not in vars(CanvasChat):setattr(CanvasChat,name,None)
if __name__=='__main__':unittest.main()
