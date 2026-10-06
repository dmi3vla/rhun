#!/usr/bin/env python3
"""Probe installed OpenCode ACP without a model turn or project file access.

By default only initialize. --new-session creates an empty native session in a
throwaway directory; it may add session metadata to OpenCode's own database.
"""
import argparse
import json
import os
from pathlib import Path
import selectors
import shutil
import signal
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cli', default=shutil.which('opencode'))
    parser.add_argument('--new-session', action='store_true')
    args = parser.parse_args()
    if not args.cli:
        raise SystemExit('OpenCode CLI not found')
    with tempfile.TemporaryDirectory(prefix='rhun-opencode-probe-') as folder:
        p = subprocess.Popen([str(Path(args.cli).resolve()), 'acp'], cwd=folder,
                             stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                             stderr=subprocess.DEVNULL, start_new_session=True)
        selector = selectors.DefaultSelector()
        selector.register(p.stdout, selectors.EVENT_READ)
        pending = bytearray()
        os.set_blocking(p.stdout.fileno(), False)
        def request(ident, method, params):
            p.stdin.write(json.dumps({'jsonrpc':'2.0','id':ident,'method':method,
                                      'params':params}).encode()+b'\n')
            p.stdin.flush()
            deadline = time.monotonic()+20
            while time.monotonic()<deadline:
                while b'\n' in pending:
                    line, _, rest = pending.partition(b'\n'); pending[:] = rest
                    frame = json.loads(line)
                    if 'method' in frame and 'id' in frame:
                        p.stdin.write(json.dumps({'jsonrpc':'2.0','id':frame['id'],
                            'error':{'code':-32601,'message':'Probe has no client capabilities'}}).encode()+b'\n')
                        p.stdin.flush()
                    if frame.get('id') == ident and 'method' not in frame:
                        if 'error' in frame:
                            raise RuntimeError(f'{method}: {frame["error"]}')
                        return frame['result']
                if not selector.select(max(0, deadline-time.monotonic())):
                    break
                data = os.read(p.stdout.fileno(), 16384)
                if not data: raise RuntimeError('OpenCode closed stdout')
                pending.extend(data)
                if len(pending)>1048576: raise RuntimeError('Oversized ACP frame')
            raise RuntimeError(f'{method}: timed out')
        try:
            result = request('init','initialize',{'protocolVersion':1,'clientCapabilities':{},
                             'clientInfo':{'name':'rhun-probe','version':'0.1.0'}})
            if result.get('protocolVersion')!=1:
                raise RuntimeError('Unsupported ACP protocol version')
            print('PASS: ACP initialize', json.dumps(result.get('agentInfo',{})))
            if args.new_session:
                result = request('new','session/new',{'cwd':folder,'mcpServers':[]})
                if not isinstance(result.get('sessionId'),str) or not result['sessionId']:
                    raise RuntimeError('Missing sessionId')
                print('PASS: session/new in empty temporary directory; no prompt sent')
                print('Session response fields:', ', '.join(sorted(result)))
        finally:
            selector.close()
            p.stdin.close()
            if p.poll() is None:
                os.killpg(p.pid,signal.SIGTERM)
            try: p.wait(timeout=3)
            except subprocess.TimeoutExpired:
                os.killpg(p.pid,signal.SIGKILL); p.wait()

if __name__=='__main__': main()
