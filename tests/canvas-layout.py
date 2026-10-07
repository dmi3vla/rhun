#!/usr/bin/env python3
import importlib.util,json,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('ui',Path(__file__).with_name('canvas-ui.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class CanvasLayout(m.CanvasUI):
    def layout(self,nodes,extra=None):
        p=self.ui(nodes)
        out=self.run_editor(self.load_ui(p)+(extra or [])+['print-ui'],path=m.FIXTURE)
        return json.loads(next(l for l in out.splitlines() if l.startswith('{"type":"rhun-ui-layout"')))['nodes']
    def test_column_gap_padding_and_frame_anchor(self):
        a=self.layout(self.base())
        self.assertEqual((a[0]['x'],a[0]['y'],a[0]['w'],a[0]['h']),(50,50,650,500))
        self.assertEqual((a[1]['x'],a[1]['y'],a[1]['w'],a[1]['h']),(62,62,626,44))
        self.assertEqual(a[2]['y'],114)
    def test_row_equal_share_and_explicit_width(self):
        nodes=self.base();nodes[0].update(type='row',width=320,height=100)
        a=self.layout(nodes);self.assertEqual([n['w'] for n in a[1:]],[144,144])
        self.assertEqual(a[2]['x'],214)
        nodes[1]['width']=80
        a=self.layout(nodes);self.assertEqual([n['w'] for n in a[1:]],[80,208])
    def test_utf8_wrapping_and_explicit_overflow_height(self):
        nodes=self.base();nodes[0].update(width=100);nodes[1].update(type='text',text='я'*20+'\nмир')
        a=self.layout(nodes);self.assertEqual(a[1]['h'],124)
        nodes[1]['height']=30;self.assertEqual(self.layout(nodes)[1]['h'],30)
    def test_preview_input_and_hover_do_not_edit_scene(self):
        p=self.ui(self.base());actions=self.load_ui(p)
        original=self.scene(actions,path=m.FIXTURE)
        preview=self.scene(actions+['cmd canvas_ui_preview','click 90 195','type changed','key Delete'],path=m.FIXTURE)
        self.assertEqual(preview,original)
    def test_preview_clip_and_mode_round_trip(self):
        p=self.ui(self.base());a,b,c=[self.work/(n+'.ppm') for n in ['draft','preview','returned']]
        actions=self.load_ui(p)+['shot '+str(a),'cmd canvas_ui_preview','move 900 600','shot '+str(b),'cmd canvas_ui_preview','shot '+str(c)]
        self.run_editor(actions,path=m.FIXTURE)
        self.assertEqual(a.read_bytes(),c.read_bytes())
        self.assertNotEqual(a.read_bytes(),b.read_bytes())
        pa,pb=[p.read_bytes().split(b'\n',3)[3] for p in [a,b]]
        self.assertEqual(pa[:1000*39*3],pb[:1000*39*3])
        self.assertEqual(pa[1000*678*3:],pb[1000*678*3:])
for name in vars(m.CanvasUI):
    if name.startswith('test_') and name not in vars(CanvasLayout):setattr(CanvasLayout,name,None)
if __name__=='__main__':unittest.main()
