#!/usr/bin/env python3
"""Native canvas lifecycle, pointer zoom, independent viewports and clipping."""
import importlib.util
import re
import unittest
from pathlib import Path
spec = importlib.util.spec_from_file_location('editor_matrix', Path(__file__).with_name('editor-matrix.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class CanvasViewport(module.EditorMatrix):
    # Reuse only fixture helpers, not the editor matrix's test methods.
    def test_two_canvases_keep_independent_viewports(self):
        out = self.run_editor(['cmd canvas_new', 'print-canvas', 'move 400 300',
            'scroll -1', 'print-canvas', 'cmd canvas_new', 'print-canvas',
            'cmd prev_tab', 'print-canvas', 'cmd close_tab', 'print-canvas',
            'cmd close_tab', 'print-doc'])
        states = re.findall(r'canvas elements=2 zoom=(\d+) pan=(-?\d+),(-?\d+)', out)
        self.assertEqual(len(states), 5, out)
        self.assertEqual(states[0], ('65536', '0', '0'))
        self.assertEqual(states[2], states[0])
        self.assertEqual(states[3], states[1])
        self.assertEqual(states[4], states[0])
        self.assertNotEqual(states[1], states[0])
        self.assertIn('cat Cat cat\nβeta beta\n', out)

    def test_pan_and_zoom_clamp(self):
        out = self.run_editor(['cmd canvas_new', 'move 400 300', 'down 2',
            'move 470 340', 'up 2', 'print-canvas',
            *(['scroll -1'] * 30), 'print-canvas',
            *(['scroll 1'] * 50), 'print-canvas'])
        self.assertIn('zoom=65536 pan=70,40', out)
        self.assertIn('zoom=262144 ', out)
        self.assertIn('zoom=16384 ', out)

    def test_plain_input_does_not_modify_text_tab(self):
        out = self.run_editor(['cmd canvas_new', 'type тест', 'key BackSpace',
                              'cmd close_tab', 'print-doc', 'print-state'])
        self.assertIn('cat Cat cat\nβeta beta\n', out)
        self.assertIn('dirty=0 ', out)

    def test_resize_and_clip(self):
        before, after = self.work / 'before.ppm', self.work / 'after.ppm'
        self.run_editor(['cmd canvas_new', 'shot ' + str(before), 'move 400 300',
            *(['scroll -1'] * 30), 'shot ' + str(after),
            'resize 640 480', 'print-canvas'])
        def pixels(path):
            return path.read_bytes().split(b'\n', 3)[3]
        a, b = pixels(before), pixels(after)
        # Top shell and bottom status bar must not be painted by zoomed geometry.
        self.assertEqual(a[:1000*39*3], b[:1000*39*3])
        self.assertEqual(a[1000*678*3:], b[1000*678*3:])

# Avoid inheriting the independent editor regression suite.
for name in list(vars(module.EditorMatrix)):
    if name.startswith('test_') and name not in vars(CanvasViewport):
        setattr(CanvasViewport, name, None)
if __name__ == '__main__':
    unittest.main()
