#!/usr/bin/env python3
"""Native memory frames, ordered evidence and view-only navigation."""
import copy,importlib.util,json,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('edit',Path(__file__).with_name('canvas-edit.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
DEMO=Path(__file__).resolve().parents[1]/'examples/memory/rhun-lifecycle.rhun-memory'
class MemoryView(m.CanvasEdit):
    def views(self,actions,path=None):
        out=self.run_editor(actions+['print-memory'],path=path)
        return [json.loads(l) for l in out.splitlines() if l.startswith('{"type":"rhun-memory-view"')]
    def load(self,path):return ['cmd memory_import','key ctrl+a','type '+str(path),'key Return']
    def test_demo_entry_and_stack(self):
        v=self.views(['cmd memory_demo'])[0]
        self.assertEqual((v['cursor'],v['provenance'],v['entrypoints']),(0,2,3))
        self.assertEqual(v['snapshot']['thread'],'T1');self.assertEqual([n['kind'] for n in v['nodes']],[0,1])
    def test_lifetimes_dangling_pointer_and_address_reuse(self):
        v=self.views(['cmd memory_demo']+['key ]']*4)[0]
        h=next(n for n in v['nodes'] if n['id']=='H1');self.assertEqual((h['size'],h['capacity'],h['state']),(64,128,0))
        v=self.views(['cmd memory_demo']+['key ]']*6)[0]
        self.assertEqual(next(n for n in v['nodes'] if n['id']=='H1')['state'],1)
        self.assertIn(dict(kind=3,**{'from':'buf','to':'H1'}),v['links'])
        v=self.views(['cmd memory_demo']+['key ]']*7)[0]
        a,b=[next(n for n in v['nodes'] if n['id']==id) for id in ['H1','H2']]
        self.assertEqual(a['address'],b['address']);self.assertNotEqual(a['state'],b['state'])
    def test_timeline_mode_and_camera_do_not_change_saved_evidence(self):
        before=self.scene(['cmd memory_demo'])
        after=self.scene(['cmd memory_demo']+['key ]']*5+['key v','move 400 300','scroll -1','key ['])
        self.assertEqual(before,after);self.assertEqual(before['elements'],[])
        self.assertEqual(json.loads(before['memory'])['type'],'rhun-memory')
    def test_native_save_reopen_and_cursor_clamp(self):
        path=self.work/'memory.rhun-canvas';self.run_editor(['cmd memory_demo']+['key ]']*5+self.save(path))
        self.assertEqual(json.loads(path.read_text())['version'],7)
        self.assertEqual(self.views([],path=path)[0]['cursor'],0)
        self.assertEqual(self.views(['cmd memory_demo']+['key ]']*30)[0]['cursor'],8)
        self.assertEqual(self.views(['cmd memory_demo','key ['])[0]['cursor'],0)
        self.assertEqual(self.views([],path=DEMO)[0]['provenance'],2)
    def test_invalid_import_keeps_current_evidence(self):
        base=self.scene(['cmd memory_demo']);data=json.loads(DEMO.read_text());data['snapshots'][0]['nodes'][0]['parent']='missing'
        bad=self.work/'bad.json';bad.write_text(json.dumps(data))
        self.assertEqual(self.scene(['cmd memory_demo']+self.load(bad)),base)
    def test_native_frames_render_and_snapshot_changes_pixels(self):
        a,b=self.work/'a.ppm',self.work/'b.ppm'
        self.run_editor(['cmd memory_demo','shot '+str(a)]+['key ]']*4+['shot '+str(b)])
        self.assertNotEqual(a.read_bytes(),b.read_bytes())
        pixels=a.read_bytes().split(b'\n',3)[3]
        self.assertGreater(len(set(pixels[1000*160*3:1000*500*3])),12)
for name in dir(m.CanvasEdit):
    if name.startswith('test_') and name not in vars(MemoryView):setattr(MemoryView,name,None)
if __name__=='__main__':unittest.main()
