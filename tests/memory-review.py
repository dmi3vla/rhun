#!/usr/bin/env python3
import importlib.util,json,copy,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('v',Path(__file__).with_name('memory-view.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class MemoryReview(m.MemoryView):
    def export(self,path):return ['cmd memory_review_export','key ctrl+a','type '+str(path),'key Return']
    def test_selected_source_and_snapshot_survive_export_modes(self):
        p=self.work/'review.json'
        a=['cmd memory_demo']+['cmd memory_next']*6+['cmd memory_select_next']*6+['key v']
        self.run_editor(a+self.export(p));d=json.loads(p.read_text())
        self.assertEqual(d['selected'],'buf');self.assertEqual(d['snapshot']['thread'],'T1')
        self.assertEqual(next(n for n in d['nodes'] if n['id']=='H1')['state'],1)
        self.assertEqual(d['links'],[dict(kind=3,**{'from':'buf','to':'H1'})])
    def test_no_selection_and_context_limits_preserve_output_file(self):
        p=self.work/'review.json';p.write_text('existing')
        self.run_editor(['cmd memory_demo']+self.export(p));self.assertEqual(p.read_text(),'existing')
        for count,length in [(66,5),(16,4000)]:
            d=json.loads(m.DEMO.read_text());snap=d['snapshots'][0];d['snapshots']=[snap]
            n=copy.deepcopy(snap['nodes'][0]);snap['nodes']=[dict(n,id='n'+str(i),label='x'*length) for i in range(count)]
            snap['links']=[dict(kind=0,**{'from':'n0','to':'n'+str(i)}) for i in range(1,count)]
            src=self.work/'large.rhun-memory';src.write_text(json.dumps(d))
            self.run_editor(self.load(src)+['cmd memory_select_next']+self.export(p));self.assertEqual(p.read_text(),'existing')
for name in dir(m.MemoryView):
    if name.startswith('test_') and name not in vars(MemoryReview):setattr(MemoryReview,name,None)
if __name__=='__main__':unittest.main()
