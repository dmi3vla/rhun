#!/usr/bin/env python3
import importlib.util,json,struct,unittest,os
from pathlib import Path
spec=importlib.util.spec_from_file_location('v',Path(__file__).with_name('memory-view.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class MemoryAdapter(m.MemoryView):
    def test_static_cfg_exact_identity_and_no_invented_runtime(self):
        s=self.scene(['cmd radare_demo','cmd memory_project']);d=json.loads(s['memory'])
        self.assertEqual((d['provenance'],d['allocator']),(0,'generic'))
        snap=d['snapshots'][0];self.assertEqual(len(snap['nodes']),5);self.assertEqual(len(snap['links']),4)
        self.assertTrue(all(n['kind']==0 and n['certainty']==0 and n['state']==2 for n in snap['nodes']))
        self.assertEqual(snap['sp'],'0x0');self.assertEqual(snap['nodes'][1]['address'],'0x1000')
        self.assertIn('cmp edi, 0',snap['nodes'][1]['label'])
        ids={n['id'] for n in snap['nodes']};self.assertTrue(all(e['from'] in ids and e['to'] in ids for e in snap['links']))
    @unittest.skipUnless(os.environ.get('RHUN_REAL_RADARE2'),'requires actual r2')
    def test_real_binary_static_projection(self):
        self.env['RHUN_RADARE2']=os.environ['RHUN_REAL_RADARE2']
        a=['cmd radare_analyze','key ctrl+a','type /bin/true','key Return','wait 1500','cmd memory_project']
        d=json.loads(self.scene(a)['memory'])
        self.assertEqual((d['binary'],d['provenance']),('/bin/true',0))
        self.assertTrue(any(e['kind']==0 for e in d['entrypoints']))
        self.assertTrue(all(n['kind']==0 for n in d['snapshots'][0]['nodes']))
    def header(self,tag=2,size=64,**changes):
        d=dict(type='rhun-heap-header',version=1,binary='capture',address='0x1000010',header=struct.pack('<QQ',tag,size).hex());d.update(changes)
        p=self.work/'header.json';p.write_text(json.dumps(d));return p
    def test_custom_header_small_large_and_no_liveness_claim(self):
        for tag,size,capacity in [(0,1,32),(2,64,128),(11,65520,65536),(69632,65521,69632)]:
            s=self.scene(self.load(self.header(tag,size)));d=json.loads(s['memory']);n=d['snapshots'][0]['nodes'][0]
            self.assertEqual((n['size'],n['capacity'],n['state'],n['certainty']),(size,capacity,2,1))
            self.assertEqual((d['allocator'],d['provenance']),('rhun-v1',1))
    def test_bad_header_is_atomic(self):
        base=self.scene(['cmd memory_demo'])
        for tag,size,changes in [(12,64,{}),(3,64,{}),(2,1073741825,{}),(2,64,{'header':'g'*32}),(2,64,{'header':'00'}),(2,64,{'address':'0x8'}),(2,64,{'extra':1})]:
            p=self.header(tag,size,**changes);self.assertEqual(self.scene(['cmd memory_demo']+self.load(p)),base)
for name in dir(m.MemoryView):
    if name.startswith('test_') and name not in vars(MemoryAdapter):setattr(MemoryAdapter,name,None)
if __name__=='__main__':unittest.main()
