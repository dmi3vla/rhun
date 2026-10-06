#!/usr/bin/env python3
"""Headless composer and native RPC adapter tests, using a deterministic CLI."""
import json
import os
from pathlib import Path
import subprocess
import struct
import tempfile
import unittest
import zlib

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / 'build/rhun'
FAKE = '''#!/usr/bin/python3
import json, os, sys, time
assert sys.argv[1:] == ['app-server', '--listen', 'stdio://']
def emit(data):
    raw = json.dumps(data, ensure_ascii=False).encode() + b'\\n'
    for pos in range(0, len(raw), 7):
        os.write(1, raw[pos:pos+7])
os.write(2, b'diagnostic-not-json\\n')
for line in sys.stdin:
    msg = json.loads(line)
    with open(os.environ['CHAT_TRACE'], 'a') as trace:
        trace.write(json.dumps(msg) + '\\n')
    method = msg['method']
    if method == 'initialize':
        emit({'id': msg['id'], 'result': {'userAgent': 'fixture'}})
    elif method == 'initialized':
        pass
    elif method == 'thread/start':
        assert msg['params']['cwd'] == os.getcwd()
        assert msg['params']['sandbox'] == 'workspace-write'
        assert msg['params']['approvalPolicy'] == 'on-request'
        emit({'id': msg['id'], 'result': {'thread': {'id': 'thread-fixture'}}})
    elif method == 'turn/start':
        text = msg['params']['input'][0]['text']
        assert msg['params']['threadId'] == 'thread-fixture'
        emit({'id': msg['id'], 'result': {'turn': {'id': 'turn-fixture'}}})
        if text == 'approval':
            emit({'id': 99, 'method': 'item/commandExecution/requestApproval',
                  'params': {'command': 'echo test'}})
            continue
        if text == 'invalid':
            os.write(1, b'not json\\n')
            continue
        if text == 'trailing':
            os.write(1, b'{"method":"ignored","params":{}}garbage\\n')
            continue
        for chunk in ['Reply: ', text]:
            emit({'method': 'item/agentMessage/delta', 'params': {
                'threadId': 'thread-fixture', 'turnId': 'turn-fixture',
                'itemId': 'answer', 'delta': chunk}})
        emit({'method': 'turn/completed', 'params': {
            'threadId': 'thread-fixture', 'turn': {'id': 'turn-fixture',
            'status': 'completed'}}})
'''


class CodexChat(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='rhun-codex-chat-')
        self.home = Path(self.tmp.name)
        self.project = self.home / 'project café with spaces'
        self.project.mkdir()
        self.bin = self.home / 'bin'
        self.bin.mkdir()
        cli = self.bin / 'codex'
        cli.write_text(FAKE)
        cli.chmod(0o755)
        self.trace = self.home / 'trace.jsonl'
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.bin),
                        XDG_CONFIG_HOME=str(self.home / 'config'),
                        XDG_STATE_HOME=str(self.home / 'state'),
                        CHAT_TRACE=str(self.trace), SHELL='/nonexistent')
        config = self.home / 'config/rhun/config'
        config.parent.mkdir(parents=True)
        config.write_text('[updates]\ncheck = false\n[git]\nenabled = false\n')

    def tearDown(self):
        self.tmp.cleanup()

    def run_script(self, body):
        script = self.home / 'commands.rsc'
        script.write_text('cmd chat_new\nwait 500\n' + body + '\nquit\n')
        result = subprocess.run([EXE, self.project, '--headless', '1000x700',
                                 '--script', script], env=self.env,
                                capture_output=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.decode()

    def test_streamed_response_followup_and_prompt_escaping(self):
        text = 'Hello "Codex" \\ café'
        output = self.run_script(f'type {text}\nkey enter\nwait 400\n'
                                 'type Follow up\nkey enter\nwait 400\nprint-agents')
        self.assertIn('user ' + text, output)
        self.assertIn('agent Reply: ' + text, output)
        self.assertIn('user Follow up\nagent Reply: Follow up', output)
        trace = [json.loads(line) for line in self.trace.read_text().splitlines()]
        self.assertEqual([m['method'] for m in trace],
                         ['initialize', 'initialized', 'thread/start', 'turn/start', 'turn/start'])
        self.assertEqual(trace[3]['params']['input'][0]['text'], text)

    def test_shift_enter_keeps_multiline_input(self):
        self.run_script('type first\nkey shift+enter\ntype second\nkey enter\nwait 400')
        trace = [json.loads(line) for line in self.trace.read_text().splitlines()]
        self.assertEqual(trace[-1]['params']['input'][0]['text'], 'first\nsecond')

    def test_unimplemented_approval_is_visible_and_never_accepted(self):
        output = self.run_script('type approval\nkey enter\nwait 400\nprint-agents')
        self.assertIn('needs an approval/question UI', output)
        trace = [json.loads(line) for line in self.trace.read_text().splitlines()]
        self.assertFalse(any(m.get('id') == 99 for m in trace))

    def test_invalid_protocol_is_visible(self):
        output = self.run_script('type invalid\nkey enter\nwait 400\nprint-agents')
        self.assertIn('Invalid or oversized Codex protocol', output)

    def test_trailing_garbage_is_rejected(self):
        output = self.run_script('type trailing\nkey enter\nwait 400\nprint-agents')
        self.assertIn('Invalid or oversized Codex protocol', output)

    def test_chat_can_be_reopened_from_history(self):
        output = self.run_script('type Keep me\nkey enter\nwait 400\nkey escape\n'
                                 'cmd chat_focus\nprint-agents')
        self.assertIn('agent Reply: Keep me', output)

    def test_preview(self):
        preview = self.home / 'chat.ppm'
        self.run_script('type Hello from the new chat\nkey enter\nwait 400\n'
                        f'type Follow-up draft\nshot {preview}')
        self.assertTrue(preview.is_file())
        # Optional artifact for visual QA; normal CI stays in the temp directory.
        target = os.environ.get('RHUN_CHAT_PREVIEW')
        if target:
            magic, dimensions, maximum, pixels = preview.read_bytes().split(b'\n', 3)
            self.assertEqual((magic, maximum), (b'P6', b'255'))
            width, height = map(int, dimensions.split())
            def chunk(kind, data):
                return (struct.pack('!I', len(data)) + kind + data +
                        struct.pack('!I', zlib.crc32(kind + data)))
            rows = b''.join(b'\0' + pixels[y * width * 3:(y + 1) * width * 3]
                            for y in range(height))
            png = b'\x89PNG\r\n\x1a\n'
            png += chunk(b'IHDR', struct.pack('!2I5B', width, height, 8, 2, 0, 0, 0))
            png += chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b'')
            Path(target).write_bytes(png)

    def test_stop_and_new_conversation(self):
        output = self.run_script('cmd chat_stop\nwait 200\n'
                                 'cmd chat_new\nwait 400\n'
                                 'type Fresh\nkey enter\nwait 400\nprint-agents')
        self.assertIn('agent Reply: Fresh', output)


if __name__ == '__main__':
    unittest.main()
