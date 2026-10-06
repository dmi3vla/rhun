#!/usr/bin/env python3
"""Reviewed selection edits and temporary side-conversation isolation."""
import importlib.util
import json
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('chat_store_fixture',ROOT/'tests/chat-store.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class ChatEdit(module.ChatStore):
    def setUp(self):
        super().setUp()
        cli=self.bin/'codex'
        cli.write_text(cli.read_text().replace("for chunk in ['Reply: ', text]:", "for chunk in ['```asm\\n', 'replacement\\n', '```']:"))
        self.source=self.project/'source.s';self.source.write_text('original\n')
    def prepare(self):
        return f'open {self.source}\ncmd select_all\ncmd chat_new\nwait 500\ncmd chat_edit_selection\nkey enter\nwait 300\n'
    def test_review_apply_and_one_undo(self):
        out=self.run_editor(self.prepare()+'cmd chat_edit_preview\nprint-doc\ncmd chat_edit_apply\nprint-doc\ncmd undo\nprint-doc')
        self.assertIn('--- Original selection ---\noriginal',out)
        self.assertIn('--- Proposed replacement ---\nreplacement',out)
        self.assertTrue(out.endswith('replacement\n\n<eod>\noriginal\n\n<eod>\n'),out)
        self.assertEqual(self.source.read_text(),'original\n')
    def test_apply_without_preview_is_rejected(self):
        out=self.run_editor(self.prepare()+'cmd chat_edit_apply\nprint-doc')
        self.assertEqual(out,'original\n\n<eod>\n')
    def test_stale_source_cannot_be_overwritten(self):
        out=self.run_editor(self.prepare()+'click 350 160\ncmd select_all\ntype changed\ncmd chat_edit_preview\ncmd chat_edit_apply\nprint-doc')
        self.assertIn('--- Proposed replacement ---',out)
        self.assertNotEqual(out,'replacement\n')
    def test_discard_prevents_apply(self):
        out=self.run_editor(self.prepare()+'cmd chat_edit_preview\ncmd chat_edit_discard\ncmd chat_edit_apply\nprint-doc')
        self.assertIn('--- Original selection ---',out)
    def test_side_chat_keeps_main_draft_and_is_not_persisted(self):
        out=self.run_editor('cmd chat_new\nwait 500\ntype Main draft\ncmd chat_side_start\nwait 600\ntype Side prompt\nkey enter\nwait 300\ncmd chat_side_return\nwait 600\nkey enter\nwait 300\nprint-agents')
        data=json.loads(self.state_path().read_text())
        self.assertEqual(len(data['chats']),1)
        self.assertIn('Main draft',out)
        self.assertNotIn('Side prompt',out)
    def test_exiting_side_chat_does_not_restore_side(self):
        self.run_editor('cmd chat_opencode\nwait 500\ntype Main draft\ncmd chat_side_start\nwait 600\ntype Private side draft')
        data=json.loads(self.state_path().read_text())
        self.assertEqual(len(data['chats']),1)
        self.assertEqual(data['chats'][0]['draft'],'Main draft')
        self.assertEqual(data['chats'][0]['provider'],1)
for name in vars(module.ChatStore):
    if name.startswith('test_') and name not in vars(ChatEdit):setattr(ChatEdit,name,None)
if __name__=='__main__':unittest.main()
