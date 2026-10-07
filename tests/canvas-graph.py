#!/usr/bin/env python3
import importlib.util,json,copy,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('edit',Path(__file__).with_name('canvas-edit.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
FIXTURE=Path(__file__).resolve().parents[1]/'examples/canvas/distributed-state.rhun-graph'
class CanvasGraph(m.CanvasEdit):
    def views(self,a,path=None):
        out=self.run_editor(a+['print-graph'],path=path)
        return [json.loads(l) for l in out.splitlines() if l.startswith('{"type":"rhun-graph-view"')]
    def test_demo_versions_timeline_and_source_immutability(self):
        a=['cmd canvas_graph_demo','print-graph','cmd canvas_graph_next_event','print-graph','cmd canvas_graph_prev_event']
        views=self.views(a)
        self.assertEqual(views[0]['versions'],[8,8,8,7]);self.assertEqual(views[1]['versions'],[8,8,8,8])
        self.assertEqual(len(views[0]['nodes']),11);self.assertEqual(len(views[0]['edges']),14)
        scene=self.scene(a+['cmd canvas_graph_mode','move 400 300','down 2','move 500 350','up 2'])
        self.assertEqual(json.loads(scene['graph']),json.loads(FIXTURE.read_text()))
    def test_fold_keeps_boundary_source_ids_and_unfold_restores_graph(self):
        views=self.views(['cmd canvas_graph_demo','print-graph','cmd canvas_graph_fold','print-graph','cmd canvas_graph_mode','print-graph','cmd canvas_graph_mode','cmd canvas_graph_fold'])
        initial,folded=views[:2]
        self.assertEqual(len(folded['nodes']),9);self.assertEqual(folded['fold'],8)
        self.assertIn(259,[n['id'] for n in folded['nodes']])
        original_ids={i for e in initial['edges'] for i in e['sourceIds']}
        retained={i for e in folded['edges'] for i in e['sourceIds']}
        self.assertEqual(original_ids-retained,{'e7','e8'})
        self.assertEqual(views[2]['selected'],folded['selected'])
        self.assertEqual(views[-1],initial)
    def test_aggregation_and_single_schema_across_all_segments(self):
        data=json.loads(FIXTURE.read_text());data['edges'].append(dict(id='parallel',a='front-copy',b='validate',kind=0))
        p=self.work/'aggregate.rhun-graph';p.write_text(json.dumps(data))
        a=['cmd canvas_graph_fold']+['cmd canvas_graph_select_next']*3+['cmd canvas_graph_fold']+['cmd canvas_graph_select_next']*3+['cmd canvas_graph_fold']
        view=self.views(a,path=p)[-1]
        self.assertEqual(len(view['nodes']),4)
        self.assertEqual(sum(n['id']==11 for n in view['nodes']),1)
        edge=next(e for e in view['edges'] if e['a']==257 and e['b']==258 and e['kind']==0)
        self.assertEqual(set(edge['sourceIds']),{'e2','parallel'})
    def test_orbit_zoom_hit_and_mode(self):
        first=self.views(['cmd canvas_graph_demo'])[-1];cache=next(n for n in first['nodes'] if n['id']==9)
        a=['cmd canvas_graph_demo',f"click {cache['x']} {cache['y']}",'move 400 300','down 2','move 500 350','up 2']+['scroll -1']*30
        view=self.views(a)[-1];self.assertEqual(view['selected'],9);self.assertNotEqual(view['yaw'],first['yaw']);self.assertEqual(view['zoom'],262144)
        self.assertEqual(self.views(a+['cmd canvas_graph_mode'])[-1]['mode'],0)
    def test_native_save_and_reopen_preserves_owned_graph(self):
        p=self.work/'graph.rhun-canvas'
        self.run_editor(['cmd canvas_graph_demo']+self.save(p))
        self.assertEqual(json.loads(self.scene([],path=p)['graph']),json.loads(FIXTURE.read_text()))
        self.assertEqual(len(self.views([],path=p)[-1]['nodes']),11)
    def test_invalid_trace_refs_duplicates_and_near_plane(self):
        bads=[];data=json.loads(FIXTURE.read_text());data['events'][0]['versions']=[7]*3;bads.append(data)
        data=json.loads(FIXTURE.read_text());data['events'][0]['active']=['missing'];bads.append(data)
        data=json.loads(FIXTURE.read_text());data['edges'][0]['a']='missing';bads.append(data)
        data=json.loads(FIXTURE.read_text());data['segments'][1]['id']=1;bads.append(data)
        data=json.loads(FIXTURE.read_text());data['nodes'][1]['id']='form';bads.append(data)
        base=self.scene(['cmd canvas_graph_demo'])
        for i,data in enumerate(bads):
            p=self.work/f'bad{i}.rhun-graph';p.write_text(json.dumps(data))
            self.assertEqual(self.scene(['cmd canvas_graph_demo','open '+str(p)]),base)
        data=json.loads(FIXTURE.read_text());data['nodes'][0]['position']=[0,0,-10000]
        p=self.work/'near.rhun-graph';p.write_text(json.dumps(data))
        view=self.views([],path=p)[-1]
        self.assertLess(len(view['nodes']),11)
        self.assertTrue(all(abs(n['x'])<100000 and abs(n['y'])<100000 for n in view['nodes']))
for name in vars(m.CanvasEdit):
    if name.startswith('test_') and name not in vars(CanvasGraph):setattr(CanvasGraph,name,None)
if __name__=='__main__':unittest.main()
