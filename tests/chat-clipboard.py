#!/usr/bin/env python3
"""Typed native clipboard delivery, URI decoding, private images and retention."""
import base64
import importlib.util
import json
from pathlib import Path
import stat
import unittest
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('store',ROOT/'tests/chat-store.py')
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
PNG=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=')
class ChatClipboard(mod.ChatStore):
    def payload(self,data):
        p=self.home/'payload';p.write_bytes(data);return p
    def draft(self):return json.loads(self.state_path().read_text())['chats'][0]['draft']
    def paste(self,kind,data):return f'paste-file {kind} {self.payload(data)}\n'
    def test_text_and_web_links_are_literal(self):
        text='hello café\nhttps://example.org/a?q=x#section\n'
        self.run_editor('cmd chat_new\nwait 500\n'+self.paste(0,text.encode())+'key enter\nwait 300')
        turn=next(m for m in self.messages() if m.get('method')=='turn/start')
        self.assertEqual(turn['params']['input'][0]['text'],text)
    def test_file_uri_list_multiple_and_spaces(self):
        a=self.project/'a café.txt';a.write_text('First context')
        b=self.project/'b.txt';b.write_text('Second context')
        uri=('# comment\r\n'+a.as_uri()+'\r\n'+b.as_uri()+'\n').encode()
        self.run_editor('cmd chat_new\nwait 500\n'+self.paste(1,uri))
        self.assertIn('First context',self.draft());self.assertIn('Second context',self.draft())
    def test_remote_uri_and_nul_rejected(self):
        for value in (b'file://remote/share/file\n',b'file:///tmp/%00bad\n'):
            self.run_editor('cmd chat_new\nwait 500\n'+self.paste(1,value))
        data=json.loads(self.state_path().read_text())
        self.assertTrue(all(not c['draft'] for c in data['chats']))
    def test_clipboard_image_saved_private_and_native(self):
        self.run_editor('cmd chat_new\nwait 500\n'+self.paste(2,PNG)+'key enter\nwait 300')
        turn=next(m for m in self.messages() if m.get('method')=='turn/start')
        image=Path(turn['params']['input'][1]['path'])
        self.assertEqual(image.read_bytes(),PNG)
        self.assertEqual(stat.S_IMODE(image.stat().st_mode),0o600)
    def test_image_draft_survives_restart(self):
        self.run_editor('cmd chat_new\nwait 500\n'+self.paste(2,PNG))
        draft=self.draft();self.assertIn('@image: ',draft)
        self.run_editor('cmd chat_resume\nwait 600\nkey enter\nwait 300')
        turn=next(m for m in self.messages() if m.get('method')=='turn/start')
        self.assertEqual(Path(turn['params']['input'][1]['path']).read_bytes(),PNG)
    def test_multiple_images_native(self):
        cmd=self.paste(2,PNG)
        self.run_editor('cmd chat_opencode\nwait 500\n'+cmd+cmd+'key enter\nwait 300')
        turn=next(m for m in self.messages() if m.get('method')=='session/prompt')
        images=turn['params']['prompt'][1:]
        self.assertEqual(len(images),2)
        self.assertTrue(all(base64.b64decode(i['data'])==PNG for i in images))
    def test_bad_image_and_utf8_leave_draft(self):
        self.run_editor('cmd chat_new\nwait 500\ntype Retain me\n'+self.paste(2,b'not an image')+self.paste(0,b'bad\xff'))
        self.assertEqual(self.draft(),'Retain me')
    def test_localhost_and_binary_reference(self):
        p=self.project/'video.mp4';p.write_bytes(b'\0binary media')
        uri=p.as_uri().replace('file:///','file://localhost/')+'\n'
        self.run_editor('cmd chat_new\nwait 500\n'+self.paste(1,uri.encode()))
        self.assertIn('@file: '+json.dumps(str(p),ensure_ascii=False),self.draft())
for name in vars(mod.ChatStore):
    if name.startswith('test_') and name not in vars(ChatClipboard):setattr(ChatClipboard,name,None)
if __name__=='__main__':unittest.main()
