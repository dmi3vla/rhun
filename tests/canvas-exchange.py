#!/usr/bin/env python3
"""Semantic Excalidraw round trips, retained metadata and copied external IDs."""
import importlib.util
import json
from pathlib import Path
import unittest
spec=importlib.util.spec_from_file_location('edit',Path(__file__).with_name('canvas-edit.py'))
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
FIXTURE=Path(__file__).resolve().parents[1]/'examples/canvas/interchange.excalidraw'
class CanvasExchange(module.CanvasEdit):
    def export(self,path):return ['cmd canvas_export_excalidraw','key ctrl+a','type '+str(path),'key Return']
    def test_import_and_native_save_keeps_external_ids_and_metadata(self):
        scene=self.scene([],path=FIXTURE)
        self.assertEqual([e['kind'] for e in scene['elements']],[5,1,2,3,4,7,9])
        self.assertEqual([e['xid'] for e in scene['elements']],['frame-a','node-a','node-b','edge-a','text-a','stroke-a','unsupported-a'])
        self.assertEqual((scene['elements'][3]['from'],scene['elements'][3]['to']),(2,4))
        self.assertEqual(scene['elements'][1]['group'],scene['elements'][2]['group'])
        self.assertEqual(scene['elements'][4]['text'],'Черновик <экран>')
        self.assertEqual(json.loads(scene['exchange'])['rhunFixtureExtension'],{'kept':True})
        native=self.work/'retained.rhun-canvas'
        self.run_editor(self.save(native),path=FIXTURE)
        self.assertEqual(self.scene([],path=native),json.loads(native.read_text()))
    def test_export_reimport_preserves_geometry_bindings_and_unknown_data(self):
        target=self.work/'export.excalidraw'
        self.run_editor(self.export(target),path=FIXTURE)
        data=json.loads(target.read_text())
        original=json.loads(FIXTURE.read_text())
        self.assertEqual(data['rhunFixtureExtension'],original['rhunFixtureExtension'])
        self.assertEqual(data['elements'][-1],original['elements'][-1])
        self.assertEqual(data['elements'][1]['customData'],{'note':'retained'})
        self.assertEqual(data['elements'][1]['groupIds'], original['elements'][1]['groupIds'])
        self.assertEqual(data['elements'][0]['name'],original['elements'][0]['name'])
        self.assertEqual(data['elements'][1]['boundElements'],[{'id':'edge-a','type':'arrow'}])
        self.assertEqual(data['elements'][3]['startBinding']['elementId'],'node-a')
        before=self.scene([],path=FIXTURE)['elements']
        after=self.scene([],path=target)['elements']
        fields=['xid','kind','x','y','w','h','seed','angle','text','points','color','fontsize']
        self.assertEqual([{k:e[k] for k in fields} for e in before],[{k:e[k] for k in fields} for e in after])
        self.assertEqual(after[1]['group'],after[2]['group'])
    def test_svg_frame_selection_and_xml_escaping(self):
        import xml.etree.ElementTree as ET
        target=self.work/'frame.svg'
        self.run_editor(['key s','click 85 200','cmd canvas_export_svg','key ctrl+a','type '+str(target),'key Return'],path=FIXTURE)
        root=ET.fromstring(target.read_text())
        self.assertEqual(root.attrib['viewBox'].split(),['50','50','650','500'])
        ids=[g.attrib['data-scene-id'] for g in root.findall('{http://www.w3.org/2000/svg}g')]
        self.assertNotIn('1',ids)
        self.assertIn('Черновик <экран>',''.join(root.itertext()))
    def test_svg_multiline_text_and_embedded_image(self):
        import base64
        import xml.etree.ElementTree as ET
        image=self.work/'tiny.png'
        image.write_bytes(base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII='))
        target=self.work/'image.svg'
        native=self.work/'image.rhun-canvas'
        a=['cmd canvas_new','cmd canvas_add_image','key ctrl+a','type '+str(image),'key Return']
        a+=['key t','click 400 350','type <текст>','key Return','type \"строка\"','key ctrl+Return']
        self.run_editor(a+self.save(native)+['cmd canvas_export_svg','key ctrl+a','type '+str(target),'key Return'])
        root=ET.fromstring(target.read_text())
        imgs=root.findall('.//{http://www.w3.org/2000/svg}image')
        self.assertEqual(len(imgs),1)
        self.assertEqual(base64.b64decode(imgs[0].attrib['href'].split(',')[1]),image.read_bytes())
        self.assertEqual(len(root.findall('.//{http://www.w3.org/2000/svg}tspan')),2)
        self.assertEqual(self.scene([],path=native)['elements'][0]['kind'],8)
        before,after=self.work/'before.ppm',self.work/'after.ppm'
        self.run_editor(a+['shot '+str(before),'cmd undo','cmd redo','shot '+str(after)])
        self.assertEqual(before.read_bytes(),after.read_bytes())
    def test_export_is_deterministic(self):
        a,b=self.work/'a.excalidraw',self.work/'b.excalidraw'
        self.run_editor(self.export(a)+self.export(b),path=FIXTURE)
        self.assertEqual(a.read_bytes(),b.read_bytes())
    def test_native_draft_exports_and_opens(self):
        target=self.work/'native.excalidraw'
        a=['cmd canvas_new','key r']+self.drag(100,200,200,260)+['cmd canvas_rotate']*3
        self.run_editor(a+self.export(target))
        data=json.loads(target.read_text())
        self.assertEqual(data['elements'][0]['id'],'rhun-1')
        self.assertAlmostEqual(data['elements'][0]['angle'],.785398,places=6)
        scene=self.scene([],path=target)
        self.assertEqual(scene['elements'][0]['angle'],45)
    def test_fractional_geometry_has_explicit_integer_projection(self):
        data=json.loads(FIXTURE.read_text());data['elements'][1]['x']=120.4
        p=self.work/'fraction.excalidraw';p.write_text(json.dumps(data))
        self.assertEqual(self.scene([],path=p)['elements'][1]['x'],120)
for name in vars(module.CanvasEdit):
    if name.startswith('test_') and name not in vars(CanvasExchange):setattr(CanvasExchange,name,None)
if __name__=='__main__':unittest.main()
