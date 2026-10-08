#!/usr/bin/env python3
import importlib.util,json,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('v',Path(__file__).with_name('memory-view.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class MemoryGraph(m.MemoryView):
    def graphs(self,a):
        out=self.run_editor(a+['print-graph'])
        return [json.loads(l) for l in out.splitlines() if l.startswith('{"type":"rhun-graph-view"')]
    def test_shared_ids_typed_edges_and_deterministic_geometry(self):
        a=['cmd memory_demo']+['key ]']*5+['key v']
        g=self.graphs(a)[0];v=self.views(a)[0]
        self.assertEqual({n['name'] for n in g['nodes']},{n['id'] for n in v['nodes']})
        self.assertEqual(sorted(e['kind'] for e in g['edges']),sorted(e['kind'] for e in v['links']))
        self.assertEqual(g['versions'],[]);self.assertEqual(g,self.graphs(a)[0])
    def test_selection_survives_modes_and_fold_retains_boundary_edges(self):
        a=['cmd memory_demo']+['key ]']*5+['cmd memory_select_next']*2
        self.assertEqual(self.views(a+['key v','key v'])[0]['selected'],2)
        first,folded,last=self.graphs(a+['key v','print-graph','cmd memory_fold','print-graph','cmd memory_fold'])
        self.assertLess(len(folded['nodes']),len(first['nodes']))
        self.assertTrue(any(n['id']==258 for n in folded['nodes']))
        self.assertEqual(first,last)
        self.assertTrue(any(e['sourceIds'] for e in folded['edges']))
    def test_orbit_and_snapshot_keep_camera_without_editing_evidence(self):
        a=['cmd memory_demo','key v','move 400 300','down 2','move 480 330','up 2']
        before,after=self.graphs(a+['print-graph','key ]'])
        self.assertEqual((before['yaw'],before['pitch'],before['zoom']),(after['yaw'],after['pitch'],after['zoom']))
        self.assertEqual(self.scene(a+['key ]']),self.scene(['cmd memory_demo']))
for name in dir(m.MemoryView):
    if name.startswith('test_') and name not in vars(MemoryGraph):setattr(MemoryGraph,name,None)
if __name__=='__main__':unittest.main()
