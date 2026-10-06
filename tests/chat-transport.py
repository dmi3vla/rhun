#!/usr/bin/env python3
"""Exercise the assembly transport without credentials or inference."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
EXE = ROOT / 'build/chat_transport_test'


class Transport(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='rhun-chat-')
        self.path = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def run_bytes(self, mode, data):
        fixture = self.path / 'input'
        fixture.write_bytes(data)
        return subprocess.run([EXE, mode, fixture], capture_output=True, timeout=20)

    def test_fragmented_utf8_crlf_multiple_records_and_partial_tail(self):
        result = self.run_bytes('frames', 'one\r\n\n日本 café\nunfinished'.encode())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, 'one\n日本 café\n'.encode())

    def test_record_limits(self):
        for size, status in ((1 << 20, 0), ((1 << 20) + 1, 1)):
            with self.subTest(size=size):
                result = self.run_bytes('frames', b'a' * size + b'\n')
                self.assertEqual(result.returncode, status, result.stderr)

    def test_json_escape_all_control_bytes_quotes_slashes_unicode(self):
        data = bytes(range(32)) + '"\\日本 café'.encode()
        result = self.run_bytes('quote', data)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), data.decode())

    def test_pipe_backpressure_and_separate_stderr(self):
        helper = self.path / 'helper.py'
        helper.write_text('''import os, sys, time
time.sleep(.1)
data = sys.stdin.buffer.read(200000)
assert data == b'x' * 200000
for start in range(0, len(data), 317):
    os.write(1, data[start:start+317])
os.write(2, b'diagnostic-only')
''')
        result = subprocess.run([EXE, 'pipe', '/usr/bin/python3', helper],
                                capture_output=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b'x' * 200000 + b'diagnostic-only')

    def test_closed_child_input_does_not_kill_editor(self):
        helper = self.path / 'closed.py'
        helper.write_text('import os, time\nos.close(0)\ntime.sleep(.2)\n')
        result = subprocess.run([EXE, 'pipe', '/usr/bin/python3', helper],
                                capture_output=True, timeout=20)
        self.assertEqual(result.returncode, 1, result.stderr)


if __name__ == '__main__':
    unittest.main()
