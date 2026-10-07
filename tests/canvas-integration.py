#!/usr/bin/env python3
"""One project across drafting, reload, semantics, proposals, HTML, UI and graph."""
import importlib.util,json,copy,re,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('edit',Path(__file__).with_name('canvas-edit.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class CanvasIntegration(m.CanvasEdit):
    def test_complete_native_workflow(self):
        native=self.work/'workflow.rhun-canvas';html=self.work/'form.html'
        a=['cmd canvas_new','key f']+self.drag(80,170,680,580)
        a+=['key r']+self.drag(130,230,250,310)+['key e']+self.drag(400,230,520,310)
        a+=['key a']+self.drag(190,270,460,270)
        a+=['key t','click 150 390','type Заказ <42>','key ctrl+Return','key s','click 85 175','cmd canvas_frame_members']
        self.run_editor(a+self.save(native));base=json.loads(native.read_text())
        proto=copy.deepcopy(base['elements'][2]);proto.update(id=6,x=400,y=350,role=1)
        edge=copy.deepcopy(base['elements'][3]);edge.update(id=7,**{'from':2,'to':6})
        p=self.work/'detail.json';p.write_text(json.dumps(dict(type='rhun-proposal',version=1,revision=base['revision']+1,explanation='Связанный шаг',operations=[dict(op='add',element=edge),dict(op='add',element=proto)])))
        a=['key s','click 150 260','cmd canvas_ui_button','cmd canvas_proposal_import','key ctrl+a','type '+str(p),'key Return','cmd canvas_proposal_next','cmd canvas_proposal_accept_selected','cmd undo','cmd redo','click 85 175','cmd canvas_ui_refresh','cmd canvas_export_html','key ctrl+a','type '+str(html),'key Return','cmd prev_tab','cmd canvas_ui_preview','shot '+str(self.work/'ui.ppm'),'cmd save','print-canvas','cmd canvas_graph_demo','cmd canvas_graph_next_event','print-graph']
        out=self.run_editor(a,path=native)
        saved=json.loads(native.read_text());self.assertEqual(len(saved['elements']),7)
        self.assertEqual(json.loads(saved['ui'])['revision'],saved['revision'])
        self.assertIn('&lt;42&gt;',html.read_text());self.assertIn('rhun-button',html.read_text())
        graph=json.loads(next(l for l in out.splitlines() if l.startswith('{"type":"rhun-graph-view"')))
        self.assertEqual(graph['versions'],[8,8,8,8])
        self.assertEqual(self.scene([],path=native),saved)
    def test_assignments_can_extend_after_new_geometry(self):
        a=['cmd canvas_new','key f']+self.drag(80,170,680,580)+['key r']+self.drag(130,230,250,310)
        a+=['key s','click 85 175','cmd canvas_frame_members','click 150 260','cmd canvas_ui_button','key r']+self.drag(400,230,520,310)
        a+=['key s','click 450 260','cmd canvas_ui_input']
        ui=json.loads(self.scene(a)['ui']);self.assertEqual(len(ui['components']),3)
        self.assertEqual(ui['components'][-1]['source'],3)
        self.assertEqual(ui['components'][-1]['type'],'input')
    def test_idle_and_repeated_mixed_tab_lifecycle(self):
        a=['cmd canvas_graph_demo','wait 3500','print-frames','wait 200','print-frames']
        for i in range(30):a+=['cmd canvas_new','cmd close_tab','cmd canvas_graph_demo','cmd close_tab']
        a+=['cmd prev_tab','print-doc']
        out=self.run_editor(a)
        frames=re.findall(r'frames=(\d+)',out);self.assertGreaterEqual(len(frames),2);self.assertEqual(frames[1],'0')
        self.assertIn('cat Cat cat',out)
for name in vars(m.CanvasEdit):
    if name.startswith('test_') and name not in vars(CanvasIntegration):setattr(CanvasIntegration,name,None)
if __name__=='__main__':unittest.main()
