#!/usr/bin/env python3
"""Real pointer gestures exercise tree selection and composer attachments."""
import importlib.util
import json
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('store',ROOT/'tests/chat-store.py')
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
class ChatDrop(mod.ChatStore):
    def draft(self):return json.loads(self.state_path().read_text())['chats'][0]['draft']
    def drag(self,y,target='850 500'):
        return f'move 70 {y}\ndown\nmove {target}\nup\nwait 100\n'
    def test_tree_drop_attaches_without_sending(self):
        (self.project/'a.txt').write_text('Drop exact text café')
        self.run_editor('cmd chat_new\nwait 500\n'+self.drag(90))
        self.assertIn('Drop exact text café',self.draft())
        self.assertFalse(any(m.get('method')=='turn/start' for m in self.messages()))
    def test_shift_range_drop(self):
        (self.project/'a.txt').write_text('First file')
        (self.project/'b.txt').write_text('Second file')
        self.run_editor('cmd chat_new\nwait 500\nclick 70 90\nclick 70 118 shift\n'+self.drag(90))
        self.assertIn('First file',self.draft());self.assertIn('Second file',self.draft())
    def test_ctrl_toggle_excludes_file(self):
        for n in ('a','b','c'):(self.project/(n+'.txt')).write_text(n+' selected')
        self.run_editor('cmd chat_new\nwait 500\nclick 70 90 ctrl\nclick 70 118 ctrl\nclick 70 146 ctrl\nclick 70 118 ctrl\n'+self.drag(90))
        self.assertIn('a selected',self.draft());self.assertIn('c selected',self.draft())
        self.assertNotIn('b selected',self.draft())
    def test_drop_outside_chat_does_not_attach(self):
        (self.project/'a.txt').write_text('Not dropped')
        self.run_editor('cmd chat_new\nwait 500\n'+self.drag(90,'450 500'))
        self.assertEqual(self.draft(),'')
    def test_binary_media_reference(self):
        path=self.project/'a.mp4';path.write_bytes(b'\x00\xffmedia')
        self.run_editor('cmd chat_new\nwait 500\n'+self.drag(90))
        self.assertIn('@file: '+json.dumps(str(path),ensure_ascii=False),self.draft())
    def test_directory_reference(self):
        path=self.project/'folder';path.mkdir()
        self.run_editor('cmd chat_new\nwait 500\n'+self.drag(90))
        self.assertIn('@file: '+json.dumps(str(path),ensure_ascii=False),self.draft())
for name in vars(mod.ChatStore):
    if name.startswith('test_') and name not in vars(ChatDrop):setattr(ChatDrop,name,None)
if __name__=='__main__':unittest.main()
