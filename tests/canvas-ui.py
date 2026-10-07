#!/usr/bin/env python3
"""UI schema, separate semantic assignments and deterministic safe generation."""
import importlib.util,json,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('edit',Path(__file__).with_name('canvas-edit.py'))
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
FIXTURE=Path(__file__).resolve().parents[1]/'examples/canvas/interchange.excalidraw'
def component(id,source,parent,kind,text='',**props):
    return dict(id=id,source=source,parent=parent,type=kind,text=text,width=0,height=0,padding=12,gap=8,action='',**props)
class CanvasUI(module.CanvasEdit):
    def ui(self,nodes,revision=1):
        p=self.work/'ui.json';p.write_text(json.dumps(dict(type='rhun-ui',version=1,revision=revision,root=100,components=nodes)))
        return p
    def load_ui(self,p):return ['cmd canvas_ui_import','key ctrl+a','type '+str(p),'key Return']
    def export(self,p):return ['cmd canvas_export_html','key ctrl+a','type '+str(p),'key Return']
    def base(self):return [component(100,1,0,'column'),component(101,2,100,'input','<поле> "&"'),component(102,4,100,'button','Сохранить')]
    def test_valid_ir_save_reopen_deterministic_html(self):
        p=self.ui(self.base());a,b=self.work/'a.html',self.work/'b.html'
        native=self.work/'ui.rhun-canvas'
        self.run_editor(self.load_ui(p)+self.save(native)+self.export(a)+['cmd prev_tab']+self.export(b),path=FIXTURE)
        self.assertEqual(a.read_bytes(),b.read_bytes())
        html=a.read_text();self.assertIn('data-scene-id="2"',html)
        self.assertIn('&lt;поле&gt; &quot;&amp;&quot;',html)
        self.assertNotIn('<script',html)
        self.assertEqual(json.loads(self.scene([],path=native)['ui'])['components'],self.base())
    def test_bad_schema_cycle_and_unknown_source_leave_scene_unchanged(self):
        before=self.scene([],path=FIXTURE)
        bads=[]
        nodes=self.base();nodes[1]['type']='script';bads.append(nodes)
        nodes=self.base();nodes[0]['parent']=102;bads.append(nodes)
        nodes=self.base();nodes[1]['id']=100;bads.append(nodes)
        nodes=self.base();nodes[1]['source']=99999;bads.append(nodes)
        nodes=self.base();nodes[1]['unexpected']=True;bads.append(nodes)
        nodes=self.base();nodes[1]['parent']=102;bads.append(nodes)
        for nodes in bads:
            with self.subTest(nodes=nodes):self.assertEqual(self.scene(self.load_ui(self.ui(nodes)),path=FIXTURE),before)
    def test_manual_assignment_is_one_undo_and_geometry_unchanged(self):
        a=['cmd canvas_new','key f']+self.drag(80,170,680,580)+['key r']+self.drag(130,230,300,320)
        a+=['key s','click 85 175','cmd canvas_frame_members','click 150 260']
        original=self.scene(a)['elements']
        assigned=self.scene(a+['cmd canvas_ui_button'])
        self.assertEqual(assigned['elements'],original)
        ui=json.loads(assigned['ui']);self.assertEqual(ui['components'][1]['type'],'button')
        self.assertEqual(self.scene(a+['cmd canvas_ui_button','cmd undo'])['ui'],'')
    def test_stale_ir_rejected_for_export_and_can_be_refreshed(self):
        p=self.ui(self.base());a=self.work/'stale.html'
        actions=self.load_ui(p)+['key s','click 150 280','cmd canvas_rotate']
        self.run_editor(actions+self.export(a),path=FIXTURE);self.assertFalse(a.exists())
        self.run_editor(actions+['cmd canvas_ui_refresh']+self.export(a),path=FIXTURE);self.assertTrue(a.exists())
    def test_generated_code_navigation_returns_to_source(self):
        p=self.ui(self.base());a=self.work/'nav.html'
        out=self.run_editor(self.load_ui(p)+self.export(a)+['cmd prev_tab','key s','click 150 280','cmd canvas_ui_code','print-state','cmd canvas_ui_source','print-canvas'],path=FIXTURE)
        self.assertIn('canvas elements=7',out)
        self.assertIn('line=',out)
    def test_referenced_deletion_is_rejected_without_dangling_ids(self):
        p=self.ui(self.base());actions=self.load_ui(p)+['key s','click 150 280']
        original=self.scene(actions,path=FIXTURE)
        self.assertEqual(self.scene(actions+['key Delete'],path=FIXTURE)['elements'],original['elements'])
    def test_manual_html_is_preserved(self):
        p=self.ui(self.base());a=self.work/'hand.html';a.write_text('manual <script>custom</script>')
        self.run_editor(self.load_ui(p)+self.export(a),path=FIXTURE)
        self.assertEqual(a.read_text(),'manual <script>custom</script>')
        self.assertIn('data-scene-id',Path(str(a)+'.rhun-generated.html').read_text())
for name in vars(module.CanvasEdit):
    if name.startswith('test_') and name not in vars(CanvasUI):setattr(CanvasUI,name,None)
if __name__=='__main__':unittest.main()
