#!/usr/bin/env python3
"""Shared segment folds, exact boundary source indices and native 2D hit tests."""
import importlib.util,json,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('g',Path(__file__).with_name('memory-graph.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class MemoryFold(m.MemoryGraph):
    def start(self):return ['cmd memory_demo']+['cmd memory_next']*5
    def selected(self):return self.start()+['cmd memory_select_next']*2
    def test_2d_fold_aggregates_typed_boundary_sources_like_3d(self):
        a=self.selected()+['key f'];v=self.views(a)[0]
        self.assertEqual((v['selected'],v['view']['fold']),(258,4))
        self.assertEqual({n['id'] for n in v['view']['nodes']},{1,5,6,258})
        edge=next(e for e in v['view']['links'] if e['from']==258 and e['to']==6)
        self.assertEqual((edge['kind'],edge['sourceIds']),(1,[2,3]))
        g=self.graphs(a+['key v'])[0]
        normal=lambda edges,keys:{(e[keys[0]],e[keys[1]],e['kind'],tuple(map(str,e['sourceIds']))) for e in edges}
        self.assertEqual(normal(v['view']['links'],('from','to')),normal(g['edges'],('a','b')))
        self.assertEqual({n['id'] for n in g['nodes']},{1,5,6,258})
    def test_mode_switch_and_unfold_restore_original_focus_and_geometry(self):
        first=self.views(self.selected())[0]
        folded=self.views(self.selected()+['key f','key v','key v'])[0]
        self.assertEqual(folded['selected'],258)
        last=self.views(self.selected()+['key f','key v','key v','key f'])[0]
        self.assertEqual((last['selected'],last['view']),(first['selected'],first['view']))
        self.assertEqual(self.scene(self.selected()+['key f','key v']),self.scene(self.start()))
    def test_summary_and_expanded_header_clicks_select_shared_segment(self):
        a=self.selected()+['key f','cmd memory_select_next','click 400 220']
        self.assertEqual(self.views(a)[0]['selected'],258)
        v=self.views(a+['key f'])[0];self.assertEqual((v['selected'],v['view']['fold']),(2,0))
        v=self.views(self.start()+['click 400 165','key f'])[0]
        self.assertEqual((v['selected'],v['view']['fold']),(258,4))
    def test_empty_segment_fold_does_not_fabricate_source_nodes(self):
        a=['cmd memory_demo','click 650 165','key f'];v=self.views(a)[0]
        self.assertEqual((len(v['nodes']),v['selected'],v['view']['fold']),(2,259,8))
        self.assertIn(259,{n['id'] for n in v['view']['nodes']})
        self.assertIn(259,{n['id'] for n in self.graphs(a+['key v'])[0]['nodes']})
        self.assertEqual(self.views(a+['key f'])[0]['view']['fold'],0)
    def test_keyboard_selection_skips_hidden_cards_and_cycles_all_visible(self):
        a=self.selected()+['key f']
        out=self.views(a+['print-memory','cmd memory_select_next','print-memory','cmd memory_select_next','print-memory','cmd memory_select_next'])
        self.assertEqual([v['selected'] for v in out],[258,1,5,6])
        v=self.views(a+['cmd memory_select_next']*4)[0];self.assertEqual(v['selected'],258)
    def test_fold_preserves_pan_zoom_and_save_reopen_resets_view_only(self):
        a=self.selected()+['move 400 300','down 2','move 450 330','up 2','scroll 1']
        p,q=self.work/'before.ppm',self.work/'after.ppm'
        self.run_editor(a+['shot '+str(p),'key f','key f','shot '+str(q)])
        self.assertEqual(p.read_bytes(),q.read_bytes())
        path=self.work/'folded.rhun-canvas';self.run_editor(a+['key f']+self.save(path))
        self.assertEqual(self.views([],path=path)[0]['view']['fold'],0)
        self.assertEqual(self.scene([],path=path)['memory'],self.scene(self.start())['memory'])
    def test_multiple_folds_restore_each_segments_own_focus(self):
        a=self.selected()+['key f']+['cmd memory_select_next']*3+['key f']
        v=self.views(a)[0];self.assertEqual((v['selected'],v['view']['fold']),(259,12))
        self.assertEqual({n['id'] for n in v['view']['nodes']},{1,258,259})
        self.assertEqual(next(e['sourceIds'] for e in v['view']['links'] if e['kind']==1),[2,3])
        v=self.views(a+['key v','key f','key v'])[0]
        self.assertEqual((v['selected'],v['view']['fold']),(6,4))
        v=self.views(a+['key f','cmd memory_select_next','key f'])[0]
        self.assertEqual((v['selected'],v['view']),(2,self.views(self.selected())[0]['view']))
    def test_snapshot_navigation_resets_folds_and_local_focus(self):
        v=self.views(self.selected()+['key f','cmd memory_next'])[0]
        self.assertEqual((v['cursor'],v['selected'],v['view']['fold']),(6,0,0))
    def test_common_graph_commands_use_memory_view_state(self):
        a=self.start()+['cmd canvas_graph_select_next']*2+['cmd canvas_graph_fold','cmd canvas_graph_mode']
        v=self.views(a)[0];self.assertEqual((v['selected'],v['view']['fold'],v['mode']),(258,4,1))
        v=self.views(a+['cmd canvas_graph_mode','cmd canvas_graph_fold'])[0]
        self.assertEqual((v['selected'],v['view']['fold'],v['mode']),(2,0,0))
        v=self.views(a+['cmd canvas_graph_next_event'])[0]
        self.assertEqual((v['cursor'],v['selected'],v['view']['fold']),(6,0,0))
        self.assertEqual(self.views(a+['cmd canvas_graph_next_event','cmd canvas_graph_prev_event'])[0]['cursor'],5)
    def test_parallel_different_kinds_do_not_merge(self):
        # memory-graph imports the memory-view module as m.
        data=json.loads(m.m.DEMO.read_text());s=data['snapshots'][5]
        s['links'].append(dict(kind=2,**{'from':'buf','to':'H1'}))
        p=self.work/'typed.rhun-memory';p.write_text(json.dumps(data))
        a=self.load(p)+['cmd memory_next']*5+['cmd memory_select_next']*2+['key f']
        v=self.views(a)[0]['view'];edges=[e for e in v['links'] if e['from']==258 and e['to']==6]
        self.assertEqual({e['kind'] for e in edges},{1,2})
        self.assertEqual(sorted(len(e['sourceIds']) for e in edges),[1,2])
for name in dir(m.MemoryGraph):
    if name.startswith('test_') and name not in vars(MemoryFold):setattr(MemoryFold,name,None)
if __name__=='__main__':unittest.main()
