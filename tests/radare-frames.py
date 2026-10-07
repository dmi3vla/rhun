#!/usr/bin/env python3
"""Owned Radare2 CFG projection, branches, frames and native persistence."""
import copy,importlib.util,json,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('edit',Path(__file__).with_name('canvas-edit.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
DEMO=Path(__file__).resolve().parents[1]/'examples/radare2/branch-demo.agfj.json'
class RadareFrames(m.CanvasEdit):
    def load(self,path):return ['cmd radare_import','key ctrl+a','type '+str(path),'key Return']
    def test_native_frames_and_true_false_edges(self):
        scene=self.scene(['cmd radare_demo'])
        frames=[e for e in scene['elements'] if e['kind']==5];blocks=[e for e in scene['elements'] if e['gxid']=='r2:block']
        edges=[e for e in scene['elements'] if e['kind']==3]
        self.assertEqual(len(frames),1);self.assertEqual(len(blocks),4);self.assertEqual(len(edges),4)
        self.assertEqual([e['xid'] for e in blocks],['4096','4104','4112','4120'])
        self.assertEqual((edges[0]['from'],edges[0]['to'],edges[0]['color']),(2,6,0xff78c88d))
        self.assertEqual((edges[1]['from'],edges[1]['to'],edges[1]['color']),(2,4,0xffe18b83))
        self.assertIn('cmp edi, 0',scene['elements'][2]['text'])
        self.assertEqual(json.loads(blocks[0]['raw'])['r2']['addr'],4096)
    def test_assembly_is_not_overprinted_by_generic_step_label(self):
        shot=self.work/'blocks.ppm';self.run_editor(['cmd radare_demo','shot '+str(shot)])
        pixels=shot.read_bytes().split(b'\n',3)[3]
        def pixel(x,y):return pixels[(y*1000+x)*3:(y*1000+x)*3+3]
        background=pixel(700,410)
        # The single-instruction return block has no third assembly line.
        self.assertTrue(all(pixel(x,y)==background for y in range(403,420) for x in range(536,576)))
    def test_save_reopen_retains_analysis_and_source(self):
        path=self.work/'review.rhun-canvas';self.run_editor(['cmd radare_demo']+self.save(path))
        stored=json.loads(path.read_text());self.assertEqual(stored['version'],6)
        self.assertEqual(self.scene([],path=path),stored)
        self.assertEqual(json.loads(stored['analysis'])['trace'],[])
    def test_invalid_inputs_keep_existing_scene(self):
        valid=json.loads(DEMO.read_text());variants=[{},[],[{}]]
        for field,value in [('addr',-1),('size',0),('ops','wrong'),('jump',1.5)]:
            data=copy.deepcopy(valid);data[0]['blocks'][0][field]=value;variants.append(data)
        data=copy.deepcopy(valid);data[0]['blocks'].append(copy.deepcopy(data[0]['blocks'][0]));variants.append(data)
        before=self.scene(['cmd radare_demo'])
        for i,data in enumerate(variants):
            p=self.work/f'bad{i}.json';p.write_text(json.dumps(data))
            self.assertEqual(self.scene(['cmd radare_demo']+self.load(p)),before)
    def test_multiple_function_frames_and_external_target(self):
        data=json.loads(DEMO.read_text());other=copy.deepcopy(data[0]);other['name']='Функция <2>'
        other['addr']=8192
        for b in other['blocks']:
            b['addr']+=4096
            for k in ['jump','fail']:
                if k in b:b[k]+=4096
        data.append(other);data[0]['blocks'][0]['fail']=99999
        p=self.work/'many.json';p.write_text(json.dumps(data))
        scene=self.scene(self.load(p));frames=[e for e in scene['elements'] if e['kind']==5]
        self.assertEqual(len(frames),2);self.assertEqual(frames[1]['text'],'Функция <2>')
        self.assertEqual(len([e for e in scene['elements'] if e['kind']==3]),7)
        p.write_text('\n'.join(json.dumps([function]) for function in data))
        self.assertEqual(self.scene(self.load(p)),scene)
    def test_collapse_is_view_only_and_undo_keeps_source(self):
        before=self.scene(['cmd radare_demo']);after=self.scene(['cmd radare_demo','key s','click 65 185','cmd canvas_detail_toggle','cmd canvas_detail_toggle'])
        self.assertEqual(before,after)
for name in dir(m.CanvasEdit):
    if name.startswith('test_') and name not in vars(RadareFrames):setattr(RadareFrames,name,None)
if __name__=='__main__':unittest.main()
