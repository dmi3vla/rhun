#!/usr/bin/env python3
"""Acceptance regressions discovered during final native-canvas integration."""
import importlib.util,json,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('exchange',Path(__file__).with_name('canvas-exchange.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class CanvasFinalBoundaries(m.CanvasExchange):
    def test_large_id_seed_round_trips(self):
        source=self.scene(['cmd canvas_new','key r']+self.drag(100,200,220,280))
        source['elements'][0]['id']=1000;source['next']=1001
        native=self.work/'seed.rhun-canvas';native.write_text(json.dumps(source))
        target=self.work/'seed.excalidraw'
        self.run_editor(['key s','click 150 230','cmd canvas_sketch']+self.export(target),path=native)
        external=json.loads(target.read_text())
        self.assertGreater(external['elements'][0]['seed'],0)
        self.assertLessEqual(external['elements'][0]['seed'],0x7fffffff)
        restored=self.scene([],path=target)
        self.assertEqual(len(restored['elements']),1)
        self.assertEqual(restored['elements'][0]['seed'],external['elements'][0]['seed'])
for name in dir(m.CanvasExchange):
    if name.startswith('test_') and name not in vars(CanvasFinalBoundaries):setattr(CanvasFinalBoundaries,name,None)
if __name__=='__main__':unittest.main()
