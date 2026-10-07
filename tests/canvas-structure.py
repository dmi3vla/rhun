#!/usr/bin/env python3
"""Groups, frame membership, clipping, repeatable sketch and z-order."""
import importlib.util
from pathlib import Path
import unittest
spec = importlib.util.spec_from_file_location('edit',Path(__file__).with_name('canvas-edit.py'))
module = importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class CanvasStructure(module.CanvasEdit):
    def test_group_selection_moves_together(self):
        a=['cmd canvas_new','key r']+self.drag(100,200,200,260)+self.drag(400,200,500,260)
        a+=['key s']+self.drag(80,180,520,280)+['cmd canvas_group']
        grouped=self.scene(a)['elements']
        self.assertEqual([e['group'] for e in grouped],[3,3])
        a+=['click 800 500']+self.drag(125,215,145,245)
        moved=self.scene(a)['elements']
        self.assertEqual([e['x']-o['x'] for e,o in zip(moved,grouped)],[20,20])
        self.assertEqual(self.scene(a+['cmd undo'])['elements'],grouped)
    def test_z_order_is_reversible(self):
        a=['cmd canvas_new','key r']+self.drag(100,200,200,260)+self.drag(400,200,500,260)
        self.assertEqual([e['id'] for e in self.scene(a+['cmd canvas_lower'])['elements']],[2,1])
        self.assertEqual([e['id'] for e in self.scene(a+['cmd canvas_lower','cmd undo'])['elements']],[1,2])
    def test_frame_members_move_and_detach_on_delete(self):
        a=['cmd canvas_new','key f']+self.drag(80,170,680,580)+['key r']+self.drag(130,230,300,320)
        a+=['key s','click 85 175','cmd canvas_frame_members']
        framed=self.scene(a)['elements']
        self.assertEqual(framed[1]['frame'],1)
        a+=self.drag(85,175,105,205)
        moved=self.scene(a)['elements']
        self.assertEqual([e['x']-o['x'] for e,o in zip(moved,framed)],[20,20])
        # Shift-click child toggles it off, so deleting only the frame detaches it.
        a+=['click 150 270 shift','key Delete']
        remaining=self.scene(a)['elements']
        self.assertEqual(len(remaining),1)
        self.assertEqual(remaining[0]['frame'],0)
    def test_sketch_is_repeatable_and_undoable(self):
        first,second=self.work/'first.ppm',self.work/'second.ppm'
        a=['cmd canvas_new','key r']+self.drag(100,200,200,260)+['cmd canvas_sketch']
        scene=self.scene(a)
        self.assertNotEqual(scene['elements'][0]['seed'],0)
        self.run_editor(a+['shot '+str(first),'move 850 500','shot '+str(second)])
        self.assertEqual(first.read_bytes(),second.read_bytes())
        self.assertEqual(self.scene(a+['cmd undo'])['elements'][0]['seed'],0)
    def test_rotation_persists_and_is_undoable(self):
        a=['cmd canvas_new','key r']+self.drag(100,200,200,260)+['cmd canvas_rotate']*3
        self.assertEqual(self.scene(a)['elements'][0]['angle'],45)
        self.assertEqual(self.scene(a+['cmd undo'])['elements'][0]['angle'],30)
for name in vars(module.CanvasEdit):
    if name.startswith('test_') and name not in vars(CanvasStructure):setattr(CanvasStructure,name,None)
if __name__=='__main__':unittest.main()
