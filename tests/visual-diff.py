#!/usr/bin/env python3
"""Native source-bound graph/claim comparison; no model or debugger required."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('edit', Path(__file__).with_name('canvas-edit.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class VisualDiff(m.CanvasEdit):
    def prompt(self, command, value):
        return ['cmd ' + command, 'key ctrl+a', 'type ' + str(value), 'key Return']

    def context(self, actions=None):
        actions = actions or ['cmd radare_demo']
        path = self.work / 'context.json'
        self.run_editor(actions + self.prompt('diff_context', path))
        return json.loads(path.read_text())

    def compare(self, target, actions=None, tail=None):
        path = self.work / 'claims.json'
        path.write_text(json.dumps(target))
        output = self.run_editor((actions or ['cmd radare_demo']) + self.prompt('diff_load', path) +
                                 (tail or []) + ['print-diff'])
        return json.loads(next(l for l in reversed(output.splitlines()) if l.startswith('{"type":"rhun-visual-diff"')))

    def test_identity_matches_and_does_not_change_evidence(self):
        target = self.context()
        self.assertEqual(len(target['nodes']), 4)
        self.assertEqual(len(target['links']), 4)
        report = self.compare(target)
        self.assertTrue(all(r['status'] == 0 for r in report['results']))
        path = self.work / 'same.json';path.write_text(json.dumps(target))
        self.assertEqual(self.scene(['cmd radare_demo'] + self.prompt('diff_load', path)),
                         self.scene(['cmd radare_demo']))

    def test_ghost_missing_and_divergent_edge(self):
        target = self.context()
        removed = target['nodes'].pop()
        target['links'] = [e for e in target['links'] if removed['id'] not in (e['from'], e['to'])]
        ghost = dict(target['nodes'][0], id='ai-ghost', address='0xfffffffffffffff0', label='Invented branch')
        target['nodes'].append(ghost)
        target['links'][0]['to'] = 'ai-ghost'
        report = self.compare(target)
        statuses = {r['status'] for r in report['results']}
        self.assertTrue({1, 2, 3} <= statuses)

    def test_partial_and_subset_scope_do_not_invent_missing(self):
        target = self.context();target['complete'] = 0
        target['nodes'] = target['nodes'][:1];target['links'] = []
        self.assertFalse(any(r['status'] == 3 for r in self.compare(target)['results']))
        target['complete'] = 1;target['scope'] = [target['nodes'][0]['id']]
        self.assertFalse(any(r['status'] == 3 for r in self.compare(target)['results']))

    def test_numeric_address_comparison_and_unverifiable_allocation(self):
        target = self.context()
        target['nodes'][0]['address'] = '0x0000000000001000'
        target['nodes'][0]['confidence'] = 100
        self.assertTrue(all(r['status'] == 0 for r in self.compare(target)['results']))
        target['nodes'][0]['size'] = 64
        self.assertEqual(self.compare(target)['results'][0]['status'], 4)
        target['nodes'][0]['address'] = '0x1001'
        self.assertEqual(self.compare(target)['results'][0]['status'], 2)

    def test_bad_input_is_atomic(self):
        original = self.context();good = self.work / 'good.json';good.write_text(json.dumps(original))
        for change in [dict(base='wrong'), dict(profile=1), dict(snapshot='other'), dict(scope=['missing']),
                       dict(version=2), dict(complete=2), dict(extra=1), dict(scope=[]),
                       dict(nodes=[original['nodes'][0]] * 2), dict(links=original['links'] * 2)]:
            bad = dict(original, **change);path=self.work/'bad.json';path.write_text(json.dumps(bad))
            report = self.compare(original, tail=self.prompt('diff_load', path))
            self.assertEqual(report['targetGraph'], original)

    def test_stale_revision_and_memory_snapshot(self):
        target = self.context()
        report = self.compare(target, tail=['click 100 250','cmd radare_note','type New note','key Return'])
        self.assertEqual(report['stale'], 1)
        actions = ['cmd memory_demo']
        target = self.context(actions)
        self.assertEqual(self.compare(target, actions=actions, tail=['key ]'])['stale'], 1)

    def test_memory_generation_not_merged_by_address(self):
        actions = ['cmd memory_demo'] + ['key ]'] * 7
        target = self.context(actions)
        a, b = [next(n for n in target['nodes'] if n['id'] == id) for id in ('H1','H2')]
        self.assertEqual(a['address'], b['address'])
        report = self.compare(target, actions=actions)
        self.assertTrue(all(r['status'] == 0 for r in report['results']))
        target['nodes'] = [n for n in target['nodes'] if n['id'] != 'H1']
        target['links'] = [e for e in target['links'] if 'H1' not in (e['from'],e['to'])]
        self.assertTrue(any(r['status'] == 3 and r['kind'] == 0 for r in self.compare(target,actions=actions)['results']))

for name in dir(m.CanvasEdit):
    if name.startswith('test_') and name not in vars(VisualDiff):setattr(VisualDiff,name,None)
if __name__ == '__main__':unittest.main()
