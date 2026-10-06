#!/usr/bin/env python3
"""Explicit file/selection/image context via the assembly composer."""
import base64
import importlib.util
import json
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('chat_store_fixture',ROOT/'tests/chat-store.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class ChatContext(module.ChatStore):
    # Exercise context only, rather than inheriting the storage test inventory.
    def test_file_picker_reads_selected_text(self):
        path=self.project/'context café.md';path.write_text('Context text café\n')
        out=self.run_editor('cmd chat_new\nwait 500\ncmd chat_attach_file\ntype context\nkey enter\nkey enter\nwait 300\nprint-agents')
        turn=next(m for m in self.messages() if m.get('method')=='turn/start')
        self.assertIn('Context text café',turn['params']['input'][0]['text'])
    def test_codex_image_is_native_local_image(self):
        path=self.project/'image café.png'
        path.write_bytes(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='))
        self.run_editor('cmd chat_new\nwait 500\ncmd chat_attach_file\ntype image\nkey enter\nkey enter\nwait 300')
        turn=next(m for m in self.messages() if m.get('method')=='turn/start')
        self.assertEqual(turn['params']['input'][1],{'type':'localImage','path':str(path)})
    def test_opencode_image_base64_matches_bytes(self):
        path=self.project/'image.png'
        raw=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=')
        path.write_bytes(raw)
        self.run_editor('cmd chat_opencode\nwait 500\ncmd chat_attach_file\ntype image\nkey enter\nkey enter\nwait 300')
        turn=next(m for m in self.messages() if m.get('method')=='session/prompt')
        image=turn['params']['prompt'][1]
        self.assertEqual(image['mimeType'],'image/png')
        self.assertEqual(base64.b64decode(image['data']),raw)
    def test_unsupported_image_does_not_send_turn(self):
        self.env['CHAT_NO_IMAGES']='1'
        path=self.project/'image.png';path.write_bytes(b'\x89PNG\r\n\x1a\n123456')
        self.run_editor('cmd chat_opencode\nwait 500\ncmd chat_attach_file\ntype image\nkey enter\nkey enter\nwait 300')
        self.assertFalse(any(m.get('method')=='session/prompt' for m in self.messages()))
        self.assertIn('@image:',json.loads(self.state_path().read_text())['chats'][0]['draft'])
    def test_at_sign_opens_context_picker(self):
        (self.project/'mention.md').write_text('Mention content')
        out=self.run_editor('cmd chat_new\nwait 500\ntype @\nprint-palette\ntype mention\nkey enter\nkey enter\nwait 300\nprint-agents')
        self.assertIn('mention.md',out)
        turn=next(m for m in self.messages() if m.get('method')=='turn/start')
        self.assertIn('Mention content',turn['params']['input'][0]['text'])
    def test_active_buffer_includes_unsaved_changes(self):
        path=self.project/'buffer.md';path.write_text('Disk text')
        out=self.run_editor(f'open {path}\ncmd select_all\ntype Unsaved replacement\ncmd chat_new\nwait 500\ncmd chat_attach_active\nkey enter\nwait 300\nprint-agents')
        turn=next(m for m in self.messages() if m.get('method')=='turn/start')
        self.assertIn('Unsaved replacement',turn['params']['input'][0]['text'])
        self.assertEqual(path.read_text(),'Disk text')
    def test_selection_context_keeps_tabs(self):
        path=self.project/'selected.s';path.write_text('mov\trax, rbx\n')
        self.run_editor(f'open {path}\ncmd select_all\ncmd chat_new\nwait 500\ncmd chat_attach_selection\nkey enter\nwait 300')
        turn=next(m for m in self.messages() if m.get('method')=='turn/start')
        self.assertIn('mov\trax, rbx',turn['params']['input'][0]['text'])
    def test_slash_inserts_project_prompt_template(self):
        folder=self.project/'.rhun/prompts';folder.mkdir(parents=True)
        (folder/'review.md').write_text('Review this project carefully.')
        self.run_editor('cmd chat_new\nwait 500\ntype /\nkey enter\nkey enter\nwait 300')
        turn=next(m for m in self.messages() if m.get('method')=='turn/start')
        self.assertEqual(turn['params']['input'][0]['text'],'Review this project carefully.')
    def test_dollar_attaches_project_skill(self):
        folder=self.project/'.agents/skills/test';folder.mkdir(parents=True)
        (folder/'SKILL.md').write_text('Skill instruction example.')
        self.run_editor('cmd chat_new\nwait 500\ntype $\nkey enter\nkey enter\nwait 300')
        turn=next(m for m in self.messages() if m.get('method')=='turn/start')
        self.assertIn('Skill instruction example.',turn['params']['input'][0]['text'])
# Reuse setup/helpers without running the parent's independent test inventory.
for name in vars(module.ChatStore):
    if name.startswith('test_') and name not in vars(ChatContext):
        setattr(ChatContext,name,None)
if __name__=='__main__':unittest.main()
