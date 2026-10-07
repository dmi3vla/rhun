#!/usr/bin/env python3
import importlib.util,json,copy,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('edit',Path(__file__).with_name('canvas-edit.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class CanvasProposals(m.CanvasEdit):
    def actions(self):return ['cmd canvas_new','key e']+self.drag(100,200,220,280)
    def proposal(self,ops,revision=1):
        p=self.work/'proposal.json';p.write_text(json.dumps(dict(type='rhun-proposal',version=1,revision=revision,explanation='Локальная детализация',operations=ops)))
        return ['cmd canvas_proposal_import','key ctrl+a','type '+str(p),'key Return']
    def operations(self):
        proto=self.scene(self.actions())['elements'][0]
        node=copy.deepcopy(proto);node.update(id=2,x=400,y=150,w=120,h=80,role=1)
        edge=copy.deepcopy(proto);edge.update(id=3,kind=3,x=160,y=124,w=300,h=66,**{'from':1,'to':2})
        text=copy.deepcopy(proto);text.update(id=4,kind=4,x=400,y=300,w=240,h=50,text='Отдельное предложение')
        return [dict(op='add',element=edge),dict(op='add',element=node),dict(op='add',element=text)]
    def test_preview_reject_do_not_change_scene(self):
        actions=self.actions();base=self.scene(actions)
        a,b=self.work/'draft.ppm',self.work/'proposal.ppm'
        self.run_editor(actions+['shot '+str(a)]+self.proposal(self.operations())+['shot '+str(b)])
        self.assertNotEqual(a.read_bytes(),b.read_bytes())
        def pixel(p,x,y): return tuple(p.read_bytes().split(b'\n',3)[3][(y*1000+x)*3:(y*1000+x)*3+3])
        old=pixel(a,460,300);new=pixel(b,460,300)
        self.assertEqual(new,tuple((v//2+c//2) for v,c in zip(old,(112,129,163))))
        self.assertEqual(self.scene(actions+self.proposal(self.operations())),base)
        self.assertEqual(self.scene(actions+self.proposal(self.operations())+['cmd canvas_proposal_reject']),base)
    def test_partial_accept_closes_dependencies_and_one_undo_redo(self):
        actions=self.actions()+self.proposal(self.operations())+['cmd canvas_proposal_next','cmd canvas_proposal_accept_selected']
        result=self.scene(actions)['elements'];self.assertEqual([e['id'] for e in result],[1,3,2])
        self.assertEqual(len(self.scene(actions+['cmd undo'])['elements']),1)
        self.assertEqual(self.scene(actions+['cmd undo','cmd redo'])['elements'],result)
    def test_accept_all_and_revision_guard(self):
        actions=self.actions()+self.proposal(self.operations())
        self.assertEqual(len(self.scene(actions+['cmd canvas_proposal_accept_all'])['elements']),4)
        stale=actions+['cmd canvas_rotate','cmd canvas_proposal_accept_all']
        result=self.scene(stale);self.assertEqual(len(result['elements']),1);self.assertEqual(result['elements'][0]['angle'],15)
    def test_unknown_duplicate_missing_and_stale_rejected(self):
        base=self.scene(self.actions())
        cases=[([{'op':'execute','code':'arbitrary'}],1),(self.operations(),0)]
        ops=self.operations();ops.append(copy.deepcopy(ops[0]));cases.append((ops,1))
        ops=self.operations();ops[0]['element']['to']=999;cases.append((ops,1))
        ops=self.operations();ops[1]['element']['x']=9999999;cases.append((ops,1))
        for ops,rev in cases:
            with self.subTest(ops=ops):self.assertEqual(self.scene(self.actions()+self.proposal(ops,rev)+['cmd canvas_proposal_accept_all']),base)
    def test_detail_fold_keeps_ids_and_progress(self):
        a=['cmd canvas_new','key f']+self.drag(80,170,680,580)+['key e']+self.drag(130,230,250,310)
        a+=['key s','click 85 175','cmd canvas_frame_members']
        proto=self.scene(a)['elements'][1];proto.update(role=1,progress=2)
        a+=self.proposal([dict(op='replace',element=proto)],3)+['cmd canvas_proposal_accept_all','click 85 175']
        before=self.scene(a)
        folded=self.scene(a+['cmd canvas_detail_toggle']*3)
        self.assertEqual(before,folded)
        self.assertEqual(before['elements'][1]['progress'],2)
    def test_request_contains_only_selection_and_revision(self):
        request=self.work/'request.json'
        self.run_editor(self.actions()+['cmd canvas_request_export','key ctrl+a','type '+str(request),'key Return'])
        data=json.loads(request.read_text());self.assertEqual(data['revision'],1)
        self.assertEqual(data['selected'],[1]);self.assertEqual(len(data['elements']),1)
        self.assertEqual(data['allowed'],['add','replace','delete','ui'])
    def test_replace_delete_and_ui_assignment_are_transactional(self):
        base=self.scene(self.actions())['elements'][0]
        replacement=copy.deepcopy(base);replacement['text']='Переименован'
        a=self.actions()+self.proposal([dict(op='replace',element=replacement)])+['cmd canvas_proposal_accept_all']
        self.assertEqual(self.scene(a)['elements'][0]['text'],'Переименован')
        a=self.actions()+self.proposal([dict(op='delete',id=1)])+['cmd canvas_proposal_accept_all']
        self.assertEqual(self.scene(a)['elements'],[])
        ui=dict(type='rhun-ui',version=1,revision=2,root=1,components=[dict(id=1,source=1,parent=0,type='button',width=0,height=0,padding=12,gap=8,text='Нажать',action='save')])
        a=self.actions()+self.proposal([dict(op='ui',value=ui)])+['cmd canvas_proposal_accept_all']
        self.assertEqual(json.loads(self.scene(a)['ui'])['components'][0]['type'],'button')
for name in vars(m.CanvasEdit):
    if name.startswith('test_') and name not in vars(CanvasProposals):setattr(CanvasProposals,name,None)
if __name__=='__main__':unittest.main()
