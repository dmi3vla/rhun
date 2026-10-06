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
pending_ids = set()
def completed(status='completed'):
    emit({'method': 'turn/completed', 'params': {
        'threadId': 'thread-fixture', 'turn': {'id': 'turn-fixture', 'status': status}}})
for line in sys.stdin:
    msg = json.loads(line)
    with open(os.environ['CHAT_TRACE'], 'a') as trace:
        trace.write(json.dumps(msg) + '\\n')
    method = msg.get('method')
    if method is None:
        assert msg['id'] in pending_ids
        pending_ids.remove(msg['id'])
        if not pending_ids:
            value = msg.get('result', msg.get('error'))
            emit({'method': 'item/agentMessage/delta', 'params': {
                'threadId': 'thread-fixture', 'turnId': 'turn-fixture',
                'itemId': 'answer', 'delta': 'Decision: ' + json.dumps(value)}})
            completed()
        continue
    if method == 'initialize':
        emit({'id': msg['id'], 'result': {'userAgent': 'fixture'}})
    elif method == 'initialized':
        pass
    elif method == 'model/list':
        emit({'id': msg['id'], 'result': {'data': [
            {'model': 'fixture-small'}, {'model': 'fixture-large'}], 'nextCursor': None}})
    elif method == 'thread/start':
        assert msg['params']['cwd'] == os.getcwd()
        assert msg['params']['sandbox'] == 'workspace-write'
        assert msg['params']['approvalPolicy'] == 'on-request'
        emit({'id': msg['id'], 'result': {'thread': {'id': 'thread-fixture'}}})
    elif method == 'turn/start':
        text = msg['params']['input'][0]['text']
        assert msg['params']['threadId'] == 'thread-fixture'
        emit({'id': msg['id'], 'result': {'turn': {'id': 'turn-fixture'}}})
        if text in ('approval', 'queued'):
            pending_ids.add(99)
            emit({'id': 99, 'method': 'item/commandExecution/requestApproval',
                  'params': {'command': 'echo test', 'cwd': os.getcwd(),
                             'reason': 'Run a test command', 'threadId': 'thread-fixture'}})
            if text == 'approval':
                continue
        if text in ('fileapproval', 'queued'):
            pending_ids.add('file"\\\\')
            emit({'id': 'file"\\\\', 'method': 'item/fileChange/requestApproval',
                  'params': {'reason': 'Modify fixture.txt', 'grantRoot': os.getcwd(),
                             'threadId': 'thread-fixture'}})
            continue
        if text in ('questions', 'secret'):
            pending_ids.add('questions')
            emit({'id': 'questions', 'method': 'item/tool/requestUserInput',
                  'params': {'threadId': 'thread-fixture', 'questions': [
                      {'id': 'language', 'question': 'Choose a language', 'header': 'Language',
                       'isSecret': text == 'secret', 'options': [
                           {'label': 'Assembly', 'description': 'Native implementation'}]},
                      {'id': 'name', 'question': 'What name?', 'header': 'Name'}]}})
            continue
        if text == 'unknown':
            pending_ids.add(200)
            emit({'id': 200, 'method': 'item/newProtocol/request', 'params': {}})
            continue
        if text == 'waiting':
            emit({'method': 'turn/started', 'params': {
                'threadId': 'thread-fixture', 'turn': {'id': 'turn-fixture'}}})
            continue
        if text == 'invalid':
            os.write(1, b'not json\\n')
            continue
        if text == 'rpcerror':
            emit({'id': msg['id'], 'error': {'code': -32000, 'message': 'Model unavailable'}})
            continue
        if text == 'trailing':
            os.write(1, b'{"method":"ignored","params":{}}garbage\\n')
            continue
        for chunk in ['Reply: ', text]:
            emit({'method': 'item/agentMessage/delta', 'params': {
                'threadId': 'thread-fixture', 'turnId': 'turn-fixture',
                'itemId': 'answer', 'delta': chunk}})
        completed()
    elif method == 'turn/interrupt':
        assert msg['params'] == {'threadId': 'thread-fixture', 'turnId': 'turn-fixture'}
        emit({'id': msg['id'], 'result': {}})
        pending_ids.clear()
        completed('interrupted')
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

    def test_approval_waits_for_explicit_decision(self):
        output = self.run_script('type approval\nkey enter\nwait 400\nprint-agents')
        self.assertIn('Approve command?', output)
        trace = [json.loads(line) for line in self.trace.read_text().splitlines()]
        self.assertFalse(any(m.get('id') == 99 for m in trace))

    def test_approve_once_then_continue(self):
        output = self.run_script('type approval\nkey enter\nwait 300\ncmd chat_approve\n'
                                 'wait 300\ntype Continue\nkey enter\nwait 300\nprint-agents')
        self.assertIn('agent Reply: Continue', output)
        trace = [json.loads(line) for line in self.trace.read_text().splitlines()]
        reply = next(m for m in trace if m.get('id') == 99)
        self.assertEqual(reply['result'], {'decision': 'accept'})

    def test_queued_command_and_file_decisions_preserve_ids(self):
        self.run_script('type queued\nkey enter\nwait 300\ncmd chat_decline\n'
                        'cmd chat_approve\nwait 300')
        trace = [json.loads(line) for line in self.trace.read_text().splitlines()]
        replies = [m for m in trace if 'method' not in m]
        self.assertEqual(len(replies), 2)
        self.assertEqual(replies[0], {'id': 99, 'result': {'decision': 'decline'}})
        self.assertEqual(replies[1]['result'], {'decision': 'accept'})
        self.assertTrue(replies[1]['id'].startswith('file"'))

    def test_two_questions_are_answered_in_one_correlated_response(self):
        self.run_script('type questions\nkey enter\nwait 300\ntype Assembly\nkey enter\n'
                        'type Demo "café"\nkey enter\nwait 300')
        trace = [json.loads(line) for line in self.trace.read_text().splitlines()]
        reply = next(m for m in trace if m.get('id') == 'questions')
        self.assertEqual(reply['result']['answers'], {
            'language': {'answers': ['Assembly']}, 'name': {'answers': ['Demo "café"']}})

    def test_unknown_and_secret_requests_are_rejected_without_stopping_chat(self):
        for text in ('unknown', 'secret'):
            with self.subTest(text=text):
                self.trace.unlink(missing_ok=True)
                output = self.run_script(f'type {text}\nkey enter\nwait 300\n'
                                         'type Continue\nkey enter\nwait 300\nprint-agents')
                self.assertIn('Unsupported provider interaction', output)
                self.assertIn('agent Reply: Continue', output)
                trace = [json.loads(line) for line in self.trace.read_text().splitlines()]
                reply = next(m for m in trace if 'method' not in m)
                self.assertEqual(reply['error']['code'], -32601)

    def test_interrupt_keeps_same_thread_and_process(self):
        output = self.run_script('type waiting\nkey enter\nwait 300\ncmd chat_stop\n'
                                 'wait 300\ntype Continue\nkey enter\nwait 300\nprint-agents')
        self.assertIn('agent Reply: Continue', output)
        trace = [json.loads(line) for line in self.trace.read_text().splitlines()]
        methods = [m['method'] for m in trace if 'method' in m]
        self.assertEqual(methods.count('thread/start'), 1)
        self.assertEqual(methods.count('turn/interrupt'), 1)

    def test_stop_before_turn_id_arrives(self):
        self.run_script('type waiting\nkey enter\ncmd chat_stop\nwait 400\n'
                        'type Continue\nkey enter\nwait 300')
        trace = [json.loads(line) for line in self.trace.read_text().splitlines()]
        self.assertEqual(sum(m.get('method') == 'turn/interrupt' for m in trace), 1)
        self.assertEqual(sum(m.get('method') == 'thread/start' for m in trace), 1)

    def test_question_answer_keeps_normal_draft_separate(self):
        self.run_script('type questions\nkey enter\ntype Keep this draft\nwait 300\n'
                        'type Assembly\nkey enter\ntype Demo\nkey enter\nwait 300\n'
                        'key enter\nwait 300')
        trace = [json.loads(line) for line in self.trace.read_text().splitlines()]
        turns = [m for m in trace if m.get('method') == 'turn/start']
        self.assertEqual(turns[-1]['params']['input'][0]['text'], 'Keep this draft')

    def test_configured_model_effort_and_explicit_cli_path(self):
        config = self.home / 'config/rhun/config'
        config.write_text(config.read_text() + '[agents]\nmodel = fixture-large\n'
                          f'effort = high\ncodex_cli = {self.bin / "codex"}\n')
        self.env['PATH'] = '/nonexistent'
        self.run_script('type Custom model\nkey enter\nwait 300')
        trace = [json.loads(line) for line in self.trace.read_text().splitlines()]
        turn = next(m for m in trace if m.get('method') == 'turn/start')
        self.assertEqual(turn['params']['model'], 'fixture-large')
        self.assertEqual(turn['params']['effort'], 'high')

    def test_available_models_and_recoverable_turn_error(self):
        output = self.run_script('cmd chat_models\nwait 300\ntype rpcerror\nkey enter\n'
                                 'wait 300\ntype Continue\nkey enter\nwait 300\nprint-agents')
        self.assertIn('fixture-small', output)
        self.assertIn('Model unavailable', output)
        self.assertIn('agent Reply: Continue', output)

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

    def test_choose_model_sends_selected_model(self):
        self.run_script('cmd chat_choose_model\nwait 300\nkey enter\ntype After model\nkey enter\nwait 300')
        trace = [json.loads(line) for line in self.trace.read_text().splitlines()]
        turn = next(m for m in trace if m.get('method') == 'turn/start')
        self.assertTrue(turn['params'].get('model'))

    def test_preview(self):
        preview = self.home / 'chat.ppm'
        message = os.environ.get('RHUN_CHAT_PREVIEW_MESSAGE', 'Hello from the new chat')
        self.run_script(f'type {message}\nkey enter\nwait 400\n'
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
