#!/usr/bin/env python3
"""Exercise real input, transactional edits, bindings and scene files."""
import importlib.util
import json
from pathlib import Path
import unittest
spec = importlib.util.spec_from_file_location('viewport', Path(__file__).with_name('canvas-viewport.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
class CanvasEdit(module.CanvasViewport):
    def scene(self, actions, path=None):
        output = self.run_editor(actions + ['print-canvas'], path=path)
        records = [json.loads(line) for line in output.splitlines() if line.startswith('{"type":"rhun-canvas"')]
        self.assertTrue(records, output)
        return records[-1]
    def drag(self, x0, y0, x1, y1):
        return [f'move {x0} {y0}', 'down', f'move {x1} {y1}', 'up']
    def save(self, path):
        return ['cmd save_as', 'key ctrl+a', 'type ' + str(path), 'key Return']
    def test_rectangle_drag_is_one_undo(self):
        actions = ['cmd canvas_new', 'key r'] + self.drag(100,200,220,280)
        scene = self.scene(actions)
        self.assertEqual([(e['kind'], e['w'], e['h']) for e in scene['elements']], [(1,120,80)])
        self.assertEqual(self.scene(actions + ['cmd undo'])['elements'], [])
        self.assertEqual(self.scene(actions + ['cmd undo','cmd redo'])['elements'], scene['elements'])
    def test_escape_cancels_preview_and_does_not_consume_id(self):
        scene = self.scene(['cmd canvas_new', 'key r', 'move 100 200', 'down',
                            'move 220 280', 'key Escape', 'up'])
        self.assertEqual(scene['elements'], [])
        self.assertEqual(scene['next'], 1)
    def test_arrow_bindings_follow_move_and_detach_on_delete(self):
        actions = ['cmd canvas_new','key r'] + self.drag(100,200,200,260)
        actions += self.drag(400,200,500,260) + ['key a'] + self.drag(150,230,450,230)
        original = self.scene(actions)['elements']
        self.assertEqual((original[2]['from'], original[2]['to']), (1,2))
        actions += ['key s'] + self.drag(125,215,165,255)
        moved = self.scene(actions)['elements']
        self.assertEqual(moved[2]['x'] - original[2]['x'], 40)
        self.assertEqual(moved[2]['y'] - original[2]['y'], 40)
        self.assertEqual(moved[2]['x'] + moved[2]['w'], original[2]['x'] + original[2]['w'])
        deleted = self.scene(actions + ['key Delete'])['elements']
        self.assertEqual(len(deleted), 2)
        self.assertEqual(deleted[1]['from'], 0)
        self.assertEqual(deleted[1]['to'], 2)
        self.assertEqual(self.scene(actions + ['key Delete','cmd undo'])['elements'], moved)
    def test_resize_selection(self):
        actions = ['cmd canvas_new','key r'] + self.drag(100,200,200,260)
        actions += ['key s'] + self.drag(200,260,240,290)
        element = self.scene(actions)['elements'][0]
        self.assertEqual((element['w'], element['h']), (140,90))
    def test_native_text_newlines_paste_and_undo(self):
        actions = ['cmd canvas_new','key t','click 300 350','type Привет',
                   'key Return','type мир','key ctrl+Return']
        element = self.scene(actions)['elements'][0]
        self.assertEqual(element['text'], 'Привет\nмир')
        self.assertEqual(self.scene(actions + ['cmd undo'])['elements'], [])
    def test_freehand_owned_points_round_trip(self):
        actions = ['cmd canvas_new','key p','move 100 200','down',
                   'move 130 210','move 110 240','move 150 230','up']
        scene = self.scene(actions)
        self.assertEqual(scene['elements'][0]['kind'], 7)
        self.assertGreaterEqual(len(scene['elements'][0]['points']), 4)
        path = self.work / 'stroke.rhun-canvas'
        self.run_editor(actions + self.save(path))
        self.assertEqual(json.loads(path.read_text())['elements'], scene['elements'])
        self.assertEqual(self.scene([], path=path)['elements'], scene['elements'])
    def test_save_open_and_invalid_open_preserve_scene(self):
        path = self.work / 'diagram.rhun-canvas'
        actions = ['cmd canvas_new','key f'] + self.drag(100,200,550,550)
        actions += ['key e'] + self.drag(150,250,250,310)
        self.run_editor(actions + self.save(path))
        saved = json.loads(path.read_text())
        self.assertEqual(self.scene([],path=path), saved)
        bad = self.work / 'bad.rhun-canvas'
        bad.write_text('{"type":"rhun-canvas","version":999,"next":1,"elements":[]}')
        self.assertEqual(self.scene(['open ' + str(bad)],path=path), saved)
    def test_marquee_moves_multiple_elements(self):
        actions = ['cmd canvas_new','key r'] + self.drag(100,200,200,260)
        actions += self.drag(400,200,500,260)
        original = self.scene(actions)['elements']
        actions += ['key s'] + self.drag(80,180,520,280) + self.drag(125,215,145,245)
        moved = self.scene(actions)['elements']
        self.assertEqual([e['x']-o['x'] for e,o in zip(moved,original)], [20,20])
        self.assertEqual([e['y']-o['y'] for e,o in zip(moved,original)], [30,30])
    def test_plus_node_and_connection_are_atomic(self):
        actions = ['cmd canvas_new','key e'] + self.drag(100,200,220,280)
        actions += ['key s'] + self.drag(230,240,450,350) + ['key 2']
        scene = self.scene(actions)['elements']
        self.assertEqual(len(scene), 3)
        self.assertEqual(scene[1]['role'], 2)
        self.assertEqual((scene[2]['from'],scene[2]['to']), (1,2))
        self.assertEqual(len(self.scene(actions + ['cmd undo'])['elements']), 1)
        self.assertEqual(len(self.scene(actions + ['cmd undo','cmd redo'])['elements']), 3)
        cancelled = self.scene(actions[:-1] + ['key Escape'])
        self.assertEqual(len(cancelled['elements']),1)
    def test_dirty_close_asks_and_saved_checkpoint_clears_dirty(self):
        actions = ['cmd canvas_new','key r'] + self.drag(100,200,200,260)
        out = self.run_editor(actions + ['print-state','cmd close_tab','print-state','key Escape','print-canvas'])
        self.assertIn('canvas=1 dirty=1', out)
        self.assertIn('focus=5 ', out)
        path = self.work / 'saved.rhun-canvas'
        out = self.run_editor(actions + self.save(path) + ['print-state','cmd close_tab','print-doc'])
        self.assertIn('canvas=1 dirty=0', out)
        self.assertIn('cat Cat cat', out)

    def test_invalid_scene_fields_leave_active_canvas_untouched(self):
        import copy
        path = self.work / 'valid.rhun-canvas'
        actions = ['cmd canvas_new','key r'] + self.drag(100,200,200,260)
        self.run_editor(actions + self.save(path))
        valid = json.loads(path.read_text())
        variants = []
        for field,value in [('id',0),('kind',999),('x',float('inf')),('w',-1),
                            ('x',1.5),('x',1000001),('from',999),('text','a\0b')]:
            data = copy.deepcopy(valid)
            data['elements'][0][field] = value
            variants.append(json.dumps(data))
        duplicate = copy.deepcopy(valid)
        duplicate['elements'].append(copy.deepcopy(duplicate['elements'][0]))
        variants += [json.dumps(duplicate), json.dumps(valid) + '{}', '{broken',
                     json.dumps(valid).replace('"id": 1','"id": 1, "id": 2')]
        for i,body in enumerate(variants):
            with self.subTest(variant=i):
                bad = self.work / f'bad-{i}.rhun-canvas'
                bad.write_text(body)
                self.assertEqual(self.scene(['open ' + str(bad)],path=path), valid)

    def test_text_paste_preserves_cyrillic_and_newlines(self):
        paste = self.work / 'paste.txt'
        paste.write_text('Привет\r\nмир\tкод')
        element = self.scene(['cmd canvas_new','key t','click 300 350',
            'paste-file 0 ' + str(paste),'key ctrl+Return'])['elements'][0]
        self.assertEqual(element['text'], 'Привет\nмир\tкод')

    def test_invalid_reload_preserves_live_document(self):
        from concurrent.futures import ThreadPoolExecutor
        import time
        path = self.work / 'live.rhun-canvas'
        self.run_editor(['cmd canvas_new','key r'] + self.drag(100,200,200,260) + self.save(path))
        saved = json.loads(path.read_text())
        marker = self.work / 'loaded.ppm'
        with ThreadPoolExecutor(max_workers=1) as pool:
            future = pool.submit(self.scene, ['shot ' + str(marker), 'wait 500', 'cmd canvas_reload'], path)
            deadline = time.monotonic() + 5
            while not marker.exists() and time.monotonic() < deadline:
                time.sleep(.005)
            self.assertTrue(marker.exists(), 'Loaded-document barrier missing')
            path.write_text('{broken')
            self.assertEqual(future.result(timeout=10), saved)

    def test_saved_canvas_restores_with_session(self):
        import subprocess
        config = self.work / 'config/rhun/config'
        config.write_text(config.read_text().replace('restore_session = false','restore_session = true'))
        path = self.work / 'session.rhun-canvas'
        self.run_editor(['cmd canvas_new','key r'] + self.drag(100,200,200,260) + self.save(path))
        script = self.work / 'restore.rsc'
        script.write_text('print-state\nprint-canvas\nquit\n')
        result = subprocess.run([str(module.module.EXE), str(self.work), '--headless', '1000x700',
            '--script',str(script)], env=self.env,capture_output=True,timeout=10)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('active=session.rhun-canvas canvas=1 dirty=0',result.stdout.decode())
        self.assertIn('"kind":1',result.stdout.decode())

    def test_history_cap_keeps_newest_32_gestures(self):
        actions = ['cmd canvas_new','key r']
        for i in range(40):
            actions += self.drag(100+i,200,200+i,260)
        scene = self.scene(actions + ['cmd undo']*40)
        self.assertEqual(len(scene['elements']),8)
        self.assertEqual(scene['next'],41)

    def test_pending_text_close_asks_before_discard(self):
        out = self.run_editor(['cmd canvas_new','key t','click 300 350','type Привет',
                               'cmd close_tab','print-state','key Escape'])
        self.assertIn('canvas=1 dirty=1 focus=5',out)

    def test_image_save_as_cannot_overwrite_image(self):
        import base64
        image = self.work / 'pixel.png'
        data = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=')
        image.write_bytes(data)
        self.run_editor(self.save(image),path=image)
        self.assertEqual(image.read_bytes(),data)

    def test_bound_arrowhead_is_visible_outside_target(self):
        before,after = self.work / 'before-arrow.ppm',self.work / 'after-arrow.ppm'
        actions = ['cmd canvas_new','key r'] + self.drag(130,230,300,320)
        actions += ['key e'] + self.drag(440,230,600,320)
        actions += ['shot ' + str(before),'key a'] + self.drag(215,275,520,275)
        self.run_editor(actions + ['shot ' + str(after)])
        a,b = [p.read_bytes().split(b'\n',3)[3] for p in (before,after)]
        def pixel(buf,x,y): return buf[(y*1000+x)*3:(y*1000+x)*3+3]
        self.assertEqual(pixel(a,215,275),pixel(b,215,275), 'Arrow starts inside source')
        self.assertNotEqual(pixel(a,431,266),pixel(b,431,266), 'Arrowhead concealed inside target')

for name in vars(module.CanvasViewport):
    if name.startswith('test_') and name not in vars(CanvasEdit):
        setattr(CanvasEdit,name,None)
if __name__ == '__main__':
    unittest.main()
