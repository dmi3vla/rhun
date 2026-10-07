#!/usr/bin/env python3
"""Imported evidence, loops/unmapped addresses and source-linked review transactions."""
import copy,importlib.util,json,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('frames',Path(__file__).with_name('radare-frames.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
TRACE=m.DEMO.with_name('branch-demo.trace.json')
class RadareTraceReview(m.RadareFrames):
    def trace(self,path=TRACE):return ['cmd radare_trace_import','key ctrl+a','type '+str(path),'key Return']
    def trace_view(self,actions):
        out=self.run_editor(['cmd radare_demo']+actions+['print-radare-trace'])
        return json.loads(next(l for l in out.splitlines() if l.startswith('{"type":"rhun-r2-trace-view"')))
    def test_ordered_loops_and_unmapped(self):
        view=self.trace_view(self.trace());self.assertEqual((view['events'],view['unmapped'],view['cursor']),(7,1,0))
        self.assertEqual([b['visits'] for b in view['blocks']],[2,1,1,2])
        view=self.trace_view(self.trace()+['key ]']*6);self.assertEqual(view['cursor'],6)
        self.assertEqual(self.trace_view(self.trace()+['key ]','key ['])['cursor'],0)
    def test_trace_save_reopen_and_single_undo(self):
        original=self.scene(['cmd radare_demo']);loaded=self.scene(['cmd radare_demo']+self.trace())
        self.assertEqual(loaded['elements'],original['elements']);self.assertEqual(json.loads(loaded['analysis'])['trace'],[4096,4112,4120,4096,4104,4120,99999])
        undone=self.scene(['cmd radare_demo']+self.trace()+['cmd undo']);self.assertEqual(undone['analysis'],original['analysis'])
        redo=self.scene(['cmd radare_demo']+self.trace()+['cmd undo','cmd redo']);self.assertEqual(redo['analysis'],loaded['analysis'])
        path=self.work/'trace.rhun-canvas';self.run_editor(['cmd radare_demo']+self.trace()+self.save(path))
        self.assertEqual(self.scene([],path=path),json.loads(path.read_text()))
    def test_timeline_and_fold_never_change_evidence(self):
        before=self.scene(['cmd radare_demo']+self.trace())
        after=self.scene(['cmd radare_demo']+self.trace()+['key ]','key n','key f','key f','key ['])
        self.assertEqual(before,after)
    def test_explicit_proposal_accept_keeps_source_and_trace(self):
        base=self.scene(['cmd radare_demo']+self.trace())
        replacement=copy.deepcopy(base['elements'][2]);replacement['text']='Review: branch condition\n'+replacement['text']
        p=self.work/'proposal.json';p.write_text(json.dumps(dict(type='rhun-proposal',version=1,revision=base['revision'],explanation='Source review',operations=[dict(op='replace',element=replacement)])))
        actions=['cmd radare_demo']+self.trace()+['cmd canvas_proposal_import','key ctrl+a','type '+str(p),'key Return']
        self.assertEqual(self.scene(actions),base)
        accepted=self.scene(actions+['cmd canvas_proposal_accept_all'])
        self.assertEqual(accepted['analysis'],base['analysis'])
        self.assertEqual(accepted['elements'][1]['raw'],base['elements'][1]['raw'])
        self.assertEqual(accepted['elements'][2]['text'],replacement['text'])
        self.assertEqual(self.scene(actions+['cmd canvas_proposal_accept_all','cmd undo'])['elements'],base['elements'])
        view=self.trace_view(self.trace()+actions[len(['cmd radare_demo']+self.trace()):]+['cmd canvas_proposal_accept_all'])
        self.assertEqual([b['visits'] for b in view['blocks']],[2,1,1,2])
    def test_bad_trace_is_atomic(self):
        valid=json.loads(TRACE.read_text());variants=[]
        for field,value in [('binary','other-binary'),('version',2),('type','execution'),('addresses',[1.5]),('addresses',[-1]),('addresses',[None])]:
            data=copy.deepcopy(valid);data[field]=value;variants.append(data)
        data=copy.deepcopy(valid);data['unknown']=1;variants.append(data)
        before=self.scene(['cmd radare_demo']+self.trace())
        for i,data in enumerate(variants):
            p=self.work/f'badtrace{i}.json';p.write_text(json.dumps(data))
            self.assertEqual(self.scene(['cmd radare_demo']+self.trace()+self.trace(p)),before)
    def test_review_note_has_source_and_one_undo(self):
        note=['click 100 250','cmd radare_note','type Проверить <script> и ветку','key Return']
        before=self.scene(['cmd radare_demo']);after=self.scene(['cmd radare_demo']+note)
        self.assertEqual(len(after['elements']),15);n=after['elements'][-1]
        self.assertEqual((n['gxid'],n['from'],n['xid']),('r2:note',2,'4096'))
        self.assertIn('Проверить <script>',n['text']);self.assertEqual(after['elements'][:13],before['elements'])
        # Function navigation must wrap over source frames, skipping the review frame.
        out=self.run_editor(['cmd radare_demo']+note+['cmd radare_next_function','cmd radare_next_function','cmd canvas_request_export','key ctrl+a','type '+str(self.work/'next.json'),'key Return'])
        self.assertEqual(json.loads((self.work/'next.json').read_text())['selected'],[1])
        self.assertEqual(self.scene(['cmd radare_demo']+note+['cmd undo'])['elements'],before['elements'])
        self.assertEqual(self.scene(['cmd radare_demo']+note+['cmd undo','cmd redo'])['elements'],after['elements'])
    def test_export_review_and_selected_request(self):
        review=self.work/'review.md';request=self.work/'request.json'
        note=['click 100 250','cmd radare_note','type ``` <script> Проверка','key Return']
        self.run_editor(['cmd radare_demo']+self.trace()+note+['cmd radare_review_export','key ctrl+a','type '+str(review),'key Return','cmd radare_next_function','click 100 200','cmd canvas_request_export','key ctrl+a','type '+str(request),'key Return'])
        text=review.read_text();self.assertIn('not a recorded execution',text);self.assertIn('unmapped or ambiguous: 1',text);self.assertIn('    ``` <script> Проверка',text)
        data=json.loads(request.read_text());self.assertIn('Review the selected Radare2',data['task']);self.assertEqual(data['evidence']['events'],7)
        self.assertNotIn('addresses',data['evidence'])
for name in dir(m.RadareFrames):
    if name.startswith('test_') and name not in vars(RadareTraceReview):setattr(RadareTraceReview,name,None)
if __name__=='__main__':unittest.main()
