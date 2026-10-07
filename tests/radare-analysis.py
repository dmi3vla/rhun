#!/usr/bin/env python3
"""Real async analysis with fake process failures and opt-in actual r2."""
import importlib.util,json,os,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('frames',Path(__file__).with_name('radare-frames.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class RadareAnalysis(m.RadareFrames):
    def setUp(self):
        super().setUp();self.binary=self.work/'binary café $(touch NEVER)';self.binary.write_bytes(b'fixture')
        self.args=self.work/'args.json';self.fixture=self.work/'r2-fixture'
        self.fixture.write_text('#!/usr/bin/python3\nimport json,os,sys,time\nfrom pathlib import Path\n'
          'Path(os.environ["RHUN_R2_TEST_ARGS"]).write_text(json.dumps(sys.argv[1:]))\n'
          'mode=os.environ.get("RHUN_R2_TEST_MODE", "ok")\n'
          'if mode=="hang": time.sleep(30)\n'
          'if mode=="fail": sys.exit(3)\n'
          'if mode=="oversize": print("x"*(9*1024*1024));sys.exit(0)\n'
          'if mode=="mutate": Path(sys.argv[-1]).write_bytes(b"changed")\n'
          'print(Path(os.environ["RHUN_R2_TEST_FIXTURE"]).read_text())\n')
        self.fixture.chmod(0o755);self.env.update(RHUN_RADARE2=str(self.fixture),RHUN_R2_TEST_ARGS=str(self.args),RHUN_R2_TEST_FIXTURE=str(m.DEMO))
    def start(self):return ['cmd radare_analyze','key ctrl+a','type '+str(self.binary),'key Return']
    def states(self,out):return [json.loads(l) for l in out.splitlines() if l.startswith('{"running"')]
    def test_async_literal_argv_and_source_path(self):
        out=self.run_editor(self.start()+['print-radare','cmd new_file','wait 400','print-radare','print-canvas'])
        self.assertEqual([s['running'] for s in self.states(out)],[1,0]);self.assertIn('CFG ready',out)
        args=json.loads(self.args.read_text());self.assertEqual(args,['-N','-2','-q','-c','aa;agfj @ entry0',str(self.binary)])
        self.assertFalse((self.work/'NEVER').exists())
        scene=json.loads(next(l for l in out.splitlines() if l.startswith('{"type":"rhun-canvas"')))
        self.assertEqual(json.loads(scene['analysis'])['binary'],str(self.binary))
    def test_cancel_keeps_existing_tabs(self):
        self.env['RHUN_R2_TEST_MODE']='hang';out=self.run_editor(self.start()+['cmd radare_demo','cmd radare_cancel','print-radare','print-canvas'])
        self.assertEqual(self.states(out)[0]['running'],0);self.assertIn('analysis cancelled',out)
        self.assertIn('canvas elements=13',out)
    def test_missing_executable(self):
        self.env['RHUN_RADARE2']='/missing/r2';out=self.run_editor(self.start()+['wait 100','print-radare','print-doc'])
        self.assertIn('executable missing',out);self.assertIn('cat Cat cat',out)
    def test_failure_oversize_and_deadline(self):
        for mode,message in [('fail','analyzer failed'),('oversize','exceeded 8 MiB'),('hang','deadline exceeded')]:
            with self.subTest(mode=mode):
                self.env['RHUN_R2_TEST_MODE']=mode;self.env['RHUN_RADARE_TIMEOUT_MS']='100' if mode=='hang' else '30000'
                out=self.run_editor(self.start()+['wait 500','print-radare','print-doc'])
                self.assertIn(message,out);self.assertEqual(self.states(out)[0]['running'],0);self.assertIn('cat Cat cat',out)
    def test_binary_change_discards_result(self):
        self.env['RHUN_R2_TEST_MODE']='mutate';out=self.run_editor(self.start()+['wait 400','print-radare','print-doc'])
        self.assertIn('binary changed',out);self.assertIn('cat Cat cat',out)
    def test_function_address_is_validated_without_command_injection(self):
        out=self.run_editor(self.start()+['wait 300','cmd radare_address','type 0x1010','key Return','wait 300','print-radare'])
        self.assertIn('CFG ready',out);self.assertEqual(json.loads(self.args.read_text())[-2],'aa;af @ 0x1010;agfj @ 0x1010')
        out=self.run_editor(self.start()+['wait 300','cmd radare_address','type 0x1010;!touch NEVER','key Return','print-radare'])
        self.assertIn('numeric function address',out);self.assertFalse((self.work/'NEVER').exists())
    @unittest.skipUnless(os.environ.get('RHUN_REAL_RADARE2'),'requires actual r2')
    def test_actual_r2_read_only_entry(self):
        self.env['RHUN_RADARE2']=os.environ['RHUN_REAL_RADARE2'];self.binary=Path('/bin/true')
        out=self.run_editor(self.start()+['wait 1000','print-radare','print-canvas'])
        self.assertIn('CFG ready',out);scene=json.loads(next(l for l in out.splitlines() if l.startswith('{"type":"rhun-canvas"')))
        self.assertEqual(scene['elements'][0]['text'],'entry0');self.assertTrue(scene['elements'][1]['raw'])
for name in dir(m.RadareFrames):
    if name.startswith('test_') and name not in vars(RadareAnalysis):setattr(RadareAnalysis,name,None)
if __name__=='__main__':unittest.main()
