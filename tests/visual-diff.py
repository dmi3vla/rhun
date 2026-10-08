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

    def test_navigation_filter_toggle_and_export_keep_source(self):
        target = self.context()
        target['nodes'][0]['size'] = 64
        target['nodes'][1]['address'] = '0xffffffffffffffff'
        target['nodes'].append(dict(target['nodes'][0], id='ghost', label='AI phantom'))
        path = self.work / 'claims-nav.json';path.write_text(json.dumps(target))
        actions = ['cmd radare_demo'] + self.prompt('diff_load', path)
        report = self.compare(target, tail=['key d'])
        self.assertEqual(report['results'][report['cursor']]['reason'], 2)
        filtered = self.compare(target, tail=['cmd diff_filter','key d'])
        self.assertEqual(filtered['results'][filtered['cursor']]['status'], 4)
        report = self.compare(target, tail=['key d','key shift+d'])
        self.assertNotEqual(report['cursor'], -1)
        a,b = self.work/'overlay.ppm',self.work/'plain.ppm'
        exported = self.work/'report.json'
        output=self.run_editor(actions+['shot '+str(a),'cmd diff_toggle','shot '+str(b)]+
                               self.prompt('diff_export',exported)+['print-canvas'])
        self.assertNotEqual(a.read_bytes(),b.read_bytes())
        self.assertEqual(json.loads(exported.read_text())['show'],0)
        actual=json.loads(next(l for l in output.splitlines() if l.startswith('{"type":"rhun-canvas"')))
        self.assertEqual(actual,self.scene(['cmd radare_demo']))

    def test_memory_overlay_modes_folds_and_navigation_keep_evidence(self):
        actions=['cmd memory_demo']+['key ]']*5
        target=self.context(actions)
        next(n for n in target['nodes'] if n['id']=='H1')['address']='0x1000100'
        target['nodes'].append(dict(target['nodes'][0],id='phantom',label='AI-only object'))
        path=self.work/'memory-claims.json';path.write_text(json.dumps(target))
        load=actions+self.prompt('diff_load',path)
        before=self.scene(actions)
        a,b,c=self.work/'memory-2d.ppm',self.work/'memory-3d.ppm',self.work/'memory-fold.ppm'
        tail=['key d','shot '+str(a),'key v','shot '+str(b),'key f','shot '+str(c),'print-diff']
        result=self.scene(load+tail)
        self.assertEqual(result,before)
        self.assertNotEqual(a.read_bytes(),b.read_bytes())
        self.assertNotEqual(b.read_bytes(),c.read_bytes())
        self.assertEqual(self.compare(target,actions=actions,tail=['key d','key v','key f'])['stale'],0)

    def test_known_properties_confidence_and_unknown_liveness(self):
        source=json.loads((Path(__file__).resolve().parents[1]/'examples/memory/rhun-lifecycle.rhun-memory').read_text())
        source['provenance']=1
        source['snapshots']=[source['snapshots'][4]]
        h=next(n for n in source['snapshots'][0]['nodes'] if n['id']=='H1');h['certainty']=0
        path=self.work/'declared.rhun-memory';path.write_text(json.dumps(source))
        actions=self.prompt('memory_import',path)
        target=self.context(actions)
        self.assertTrue(all(r['status']==0 for r in self.compare(target,actions=actions)['results']))
        for field,value,reason in [('kind',2,3),('size',32,4),('capacity',64,5),('state',1,6)]:
            bad=copy.deepcopy(target);node=next(n for n in bad['nodes'] if n['id']=='H1')
            node[field]=value;node['confidence']=100
            report=self.compare(bad,actions=actions)
            self.assertTrue(any(r['status']==2 and r['reason']==reason for r in report['results']))
        h['state']=2
        for edge in source['snapshots'][0]['links']:
            if edge['to']=='H1' and edge['kind']==1:edge['kind']=2
        path.write_text(json.dumps(source));target=self.context(actions)
        next(n for n in target['nodes'] if n['id']=='H1')['state']=0
        self.assertTrue(any(r['status']==4 for r in self.compare(target,actions=actions)['results']))

    def test_limits_unknown_fields_references_and_markdown(self):
        target=self.context()
        variants=[]
        for field,value in [('address','0x10000000000000000'),('address','0xno'),('confidence',101),('label','x'*4097)]:
            bad=copy.deepcopy(target);bad['nodes'][0][field]=value;variants.append(bad)
        bad=copy.deepcopy(target);bad['links'][0]['from']='absent';variants.append(bad)
        bad=copy.deepcopy(target);bad['nodes'][0]['extra']=1;variants.append(bad)
        bad=copy.deepcopy(target);bad['scope']*=2;variants.append(bad)
        bad=copy.deepcopy(target);bad['nodes']*=129;variants.append(bad)
        bad=copy.deepcopy(target);bad['scope']=bad['scope'][:1];variants.append(bad)
        for bad in variants:
            path=self.work/'invalid.json';path.write_text(json.dumps(bad))
            self.assertEqual(self.compare(target,tail=self.prompt('diff_load',path))['targetGraph'],target)
        report_path=self.work/'diff.md'
        self.compare(target,tail=self.prompt('diff_export',report_path))
        text=report_path.read_text()
        self.assertIn('# Native Visual Diff',text)
        self.assertIn('Confidence is model metadata',text)
        self.assertIn('Base:',text)
        self.assertIn('AI:',text)

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
