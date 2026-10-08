#!/usr/bin/env python3
"""Reproducible native Radare2/Memory acceptance on a supplied ELF.

Requires r2 (RHUN_RADARE2 or --r2) and the current build/rhun. Does not execute
the supplied ELF. Generated scenes, logs and a hash manifest stay under build/.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', nargs='?', type=Path, default=ROOT / 'rhun')
    parser.add_argument('--r2', default=os.environ.get('RHUN_RADARE2', 'r2'))
    parser.add_argument('--out', type=Path, default=ROOT / 'build/radare-workshop')
    args = parser.parse_args()
    binary, out = args.binary.resolve(), args.out.resolve()
    r2 = shutil.which(args.r2)
    if not r2:
        parser.error('r2 missing: set RHUN_RADARE2 or --r2; see docs/rhun-radare2-walkthrough-ru.md')
    out.mkdir(parents=True, exist_ok=True)
    digest = lambda: hashlib.sha256(binary.read_bytes()).hexdigest()
    original = digest()
    env = dict(os.environ)
    env.pop('R2_ARGS', None)
    env['RHUN_RADARE2'] = str(Path(r2).resolve())
    symbols = {}
    for line in subprocess.check_output(['nm', '-n', binary], text=True).splitlines():
        fields = line.split()
        if len(fields) == 3:
            symbols[fields[2]] = int(fields[0], 16)
    manifest = dict(binary=str(binary), sha256=original,
                    r2=subprocess.check_output([r2, '-v'], env=env, text=True).splitlines()[0],
                    execution_recorded=False, functions=[], checks=[])
    with tempfile.TemporaryDirectory(prefix='rhun-workshop-') as temp:
        home = Path(temp)
        config = home / 'config/rhun/config'
        config.parent.mkdir(parents=True)
        config.write_text('[ui]\nsidebar = false\nagents_panel = false\n'
                          '[files]\nrestore_session = false\nrestore_project = false\n'
                          '[updates]\ncheck = false\n[git]\nenabled = false\n')
        env.update(HOME=str(home), XDG_CONFIG_HOME=str(home / 'config'),
                   XDG_STATE_HOME=str(home / 'state'))

        def run(name, actions, path=None):
            script = home / 'actions.rsc'
            script.write_text('\n'.join(actions + ['quit']) + '\n')
            result = subprocess.run([ROOT / 'build/rhun', ROOT, path or config,
                                     '--headless', '1200x800', '--script', script],
                                    env=env, capture_output=True, text=True, timeout=45)
            (out / (name + '.log')).write_text(result.stdout + result.stderr)
            assert result.returncode == 0, (name, result.stderr)
            assert 'unknown\n' not in result.stdout, name
            return result.stdout

        def record(text, kind):
            return [json.loads(line) for line in text.splitlines()
                    if line.startswith('{"type":"' + kind + '"')][-1]

        def prompt(command, value):
            return ['cmd ' + command, 'key ctrl+a', 'type ' + str(value), 'key Return']

        def save(path):
            return prompt('save_as', path)

        def check(label):
            manifest['checks'].append(label)
            print('OK:', label, flush=True)

        entry = out / 'entry.rhun-canvas'
        text = run('entry', prompt('radare_analyze', binary) +
                   ['wait 5000', 'print-radare', 'print-canvas'] + save(entry))
        assert 'CFG ready' in text, text[-2000:]
        scene = record(text, 'rhun-canvas')
        assert json.loads(scene['analysis'])['binary'] == str(binary)
        check('actual asynchronous entry analysis and native save')

        # An actual address request in the UI, independently of agfj imports.
        address = symbols['mem_alloc']
        text = run('address', prompt('radare_address', hex(address)) +
                   ['wait 5000', 'print-radare', 'print-canvas'], entry)
        assert 'CFG ready' in text, text[-2000:]
        assert any(e.get('xid') == str(address) for e in record(text, 'rhun-canvas')['elements'])
        check('actual asynchronous mem_alloc address analysis')

        for name in ['_start', 'sys_init', 'main', 'app_init', 'mem_alloc', 'mem_free']:
            address = symbols[name]
            raw = subprocess.check_output([r2, '-N', '-2', '-q', '-c',
                                           f'aa;af @ {hex(address)};agfj @ {hex(address)}', binary],
                                          env=env, text=True, timeout=30)
            functions = json.loads(raw)
            assert functions and functions[0]['blocks'], name
            source = out / (name + '.agfj.json')
            source.write_text(raw)
            cfg = out / (name + '.rhun-canvas')
            run(name + '-import', prompt('radare_import', source) + save(cfg))
            before = json.loads(cfg.read_text())
            text = run(name + '-navigate', ['key n', 'key f', 'key f',
                       'move 450 300', 'down 2', 'move 480 330', 'up 2',
                       'scroll 1', 'print-canvas'], cfg)
            assert record(text, 'rhun-canvas') == before, name
            memory = out / (name + '-memory.rhun-canvas')
            text = run(name + '-memory', ['cmd memory_project', 'print-memory',
                       'cmd memory_select_next', 'key f', 'key v', 'print-graph',
                       'key f', 'move 450 300', 'down 2', 'move 520 340', 'up 2',
                       'scroll -1', 'key n', 'print-memory', 'print-canvas',
                       'shot ' + str(out / (name + '-3d.ppm'))] + save(memory), cfg)
            evidence = json.loads(record(text, 'rhun-canvas')['memory'])
            snap = evidence['snapshots'][0]
            assert evidence['provenance'] == 0
            assert snap['sp'] == snap['bp'] == '0x0'
            assert all(n['kind'] == 0 for n in snap['nodes'])
            reopened = run(name + '-reopen', ['print-canvas'], memory)
            assert record(reopened, 'rhun-canvas')['memory'] == record(text, 'rhun-canvas')['memory']
            manifest['functions'].append(dict(name=name, address=hex(address),
                    blocks=len(functions[0]['blocks']), nodes=len(snap['nodes']),
                    links=len(snap['links']), cfg=cfg.name, memory=memory.name))
            check(name + ': import, fold, pan/zoom, 2D/3D, static projection, save/reopen')

        # This route is intentionally synthetic, never called a captured trace.
        first = next(e for e in scene['elements'] if e['gxid'] == 'r2:block')
        trace = out / 'entry-SYNTHETIC.trace.json'
        trace.write_text(json.dumps(dict(type='rhun-r2-trace', version=1,
                        binary=str(binary), addresses=[int(first['xid'])] * 2)))
        reviewed = out / 'entry-reviewed.rhun-canvas'
        text = run('trace-review', prompt('radare_trace_import', trace) +
                   ['key ]', 'key [', 'click 100 250'] +
                   prompt('radare_note', 'SYNTHETIC route; inspect sys_init then main in src/start.s') +
                   prompt('radare_review_export', out / 'entry-review.md') +
                   ['print-radare-trace', 'print-canvas'] + save(reviewed), entry)
        assert record(text, 'rhun-r2-trace-view')['events'] == 2
        reviewed_scene = record(text, 'rhun-canvas')
        assert any(e['gxid'] == 'r2:note' for e in reviewed_scene['elements'])
        assert reviewed_scene['elements'][1]['raw'] == scene['elements'][1]['raw']
        check('explicit synthetic trace, timeline, source-linked note and Markdown export')

        text = run('selected-review', ['cmd memory_select_next'] +
                   prompt('memory_review_export', out / 'mem_alloc-review.json') +
                   ['print-memory'], out / 'mem_alloc-memory.rhun-canvas')
        assert json.loads((out / 'mem_alloc-review.json').read_text())['nodes']
        check('bounded selected static evidence JSON export')

        text = run('lifecycle', ['cmd memory_demo'] + ['key ]'] * 6 +
                   ['print-memory', 'key ]', 'print-memory', 'key [', 'key v',
                    'cmd memory_select_next', 'key f', 'key f', 'print-graph'] +
                   save(out / 'TEACHING-lifecycle.rhun-canvas'))
        views = [json.loads(l) for l in text.splitlines() if l.startswith('{"type":"rhun-memory-view"')]
        assert views[0]['provenance'] == 2
        assert next(n for n in views[0]['nodes'] if n['id'] == 'H1')['state'] == 1
        assert {n['id'] for n in views[1]['nodes']} >= {'H1', 'H2'}
        check('teaching lifecycle: free, dangling reference, address reuse, timeline, 3D')
        text = run('header', prompt('memory_import', ROOT / 'examples/memory/captured-header.json') + ['print-memory'])
        node = record(text, 'rhun-memory-view')['nodes'][0]
        assert node['state'] == 2 and node['certainty'] == 1
        check('header fixture import retains unknown allocation liveness')
    assert digest() == original, 'input binary changed'
    check('input SHA256 unchanged')
    (out / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print('Artifacts:', out)


if __name__ == '__main__':
    main()
