#!/usr/bin/env python3
"""Installed-CLI smoke through rhun itself: create and resume, no model prompt."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--provider',choices=['codex','opencode','pi'],required=True)
    parser.add_argument('--cli')
    parser.add_argument('--prompt-turn',action='store_true',help='Send one tiny model prompt in an empty temporary project')
    parser.add_argument('--exe',default=str(ROOT/'build/rhun'))
    args=parser.parse_args()
    cli=args.cli or shutil.which(args.provider)
    if not cli:raise SystemExit(f'{args.provider}: CLI not installed')
    with tempfile.TemporaryDirectory(prefix='rhun-native-chat-') as folder:
        base=Path(folder);project=base/'empty project';project.mkdir()
        cfg=base/'config/rhun/config';cfg.parent.mkdir(parents=True)
        key={'codex':'codex_cli','opencode':'opencode_cli'}.get(args.provider)
        config='[git]\nenabled = false\n[updates]\ncheck = false\n'
        if key:config+=f'[agents]\n{key} = {Path(cli).resolve()}\n'
        cfg.write_text(config)
        env=dict(os.environ,XDG_CONFIG_HOME=str(base/'config'),XDG_STATE_HOME=str(base/'state'))
        env['PATH']=str(Path(cli).parent)+os.pathsep+env.get('PATH','')
        def run(command,send=False):
            script=base/'commands.rsc'
            actions=f'cmd {command}\nwait 8000\n'
            if send:actions+='type Reply exactly RHUN_SMOKE_OK. Do not use tools or inspect files.\nkey enter\nwait 30000\n'
            script.write_text(actions+'print-chat-status\nprint-agents\nquit\n')
            result=subprocess.run([args.exe,project,'--headless','1000x700','--script',script],
                                  env=env,capture_output=True,timeout=55)
            if result.returncode:raise RuntimeError(f'Editor exited with code {result.returncode}')
            if b'chat-state=3\n' not in result.stdout:
                raise RuntimeError('Native runtime did not become ready: '+result.stdout.decode(errors='replace').strip())
            files=list((base/'state/rhun').glob('*.chats.json'))
            if len(files)!=1:raise RuntimeError('Expected one saved chat snapshot')
            data=json.loads(files[0].read_text())
            if len(data['chats'])!=1 or not data['chats'][0]['id']:
                raise RuntimeError('Native session initialization did not complete')
            messages=data['chats'][0]['messages']
            if args.prompt_turn:
                if not any(m['role']==2 and 'RHUN_SMOKE_OK' in m['text'] for m in messages):
                    raise RuntimeError('Expected assistant smoke reply was not received: '+result.stdout.decode(errors='replace').strip())
            elif messages:raise RuntimeError('Smoke probe must not send a model prompt')
            return data['chats'][0]['id']
        session=run({'codex':'chat_new','opencode':'chat_opencode','pi':'chat_pi'}[args.provider],send=args.prompt_turn)
        resumed=run('chat_resume')
        if resumed!=session and (args.provider!='codex' or args.prompt_turn):raise RuntimeError('Resume changed native session identity')
        workflow='create + empty draft recovery' if resumed!=session else 'create + native resume'
        detail='one tiny real model turn' if args.prompt_turn else 'no model prompt'
        print(f'PASS: {args.provider} {workflow} through assembly UI; {detail}')
if __name__=='__main__':main()
