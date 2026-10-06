#!/usr/bin/env python3
"""Read-only app-server handshake probe. Does not start a model turn."""
import json
import selectors
import shutil
import subprocess
import time


def main():
    cli = shutil.which('codex')
    if cli is None:
        raise SystemExit('Codex CLI not found in PATH')
    process = subprocess.Popen([cli, 'app-server', '--listen', 'stdio://'],
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.DEVNULL)
    try:
        message = {'id': 1, 'method': 'initialize', 'params': {
            'clientInfo': {'name': 'rhun', 'title': 'rhun', 'version': '0.1.0'}}}
        process.stdin.write(json.dumps(message).encode() + b'\n')
        process.stdin.flush()
        selector = selectors.DefaultSelector()
        selector.register(process.stdout, selectors.EVENT_READ)
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            if not selector.select(max(0, deadline - time.monotonic())):
                break
            line = process.stdout.readline()
            if not line:
                raise SystemExit('App-server closed stdout during initialization')
            reply = json.loads(line)
            if reply.get('id') != 1:
                continue
            if 'error' in reply:
                raise SystemExit('Initialization failed: ' + str(reply['error']))
            process.stdin.write(b'{"method":"initialized","params":{}}\n')
            process.stdin.flush()
            print('PASS: Codex app-server initialize/initialized over stdio')
            return
        raise SystemExit('Initialization timed out')
    finally:
        process.stdin.close()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


if __name__ == '__main__':
    main()
