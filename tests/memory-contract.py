#!/usr/bin/env python3
"""Closed memory IR, exact addresses, lifetimes and rhun allocation classes."""
import copy,json,subprocess,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DEMO=ROOT/'examples/memory/rhun-lifecycle.rhun-memory'
class MemoryContract(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory(prefix='rhun-memory-contract-');self.path=Path(self.tmp.name)/'input.json'
        self.data=json.loads(DEMO.read_text())
    def tearDown(self):self.tmp.cleanup()
    def valid(self,data):
        self.path.write_text(json.dumps(data,ensure_ascii=False))
        r=subprocess.run([ROOT/'build/memory_contract_test',self.path],capture_output=True,timeout=10)
        self.assertIn(r.returncode,(0,1),r.stderr);return r.returncode==0
    def test_demo_and_full_width_addresses(self):
        self.assertTrue(self.valid(self.data));self.data['entrypoints'][0]['address']='0xffffffffffffffff';self.assertTrue(self.valid(self.data))
    def test_address_types_overflow_and_trailing_junk(self):
        for value in [4096,'0x10000000000000000','0x','0x123g','0x1;!cmd','12',None]:
            d=copy.deepcopy(self.data);d['entrypoints'][0]['address']=value;self.assertFalse(self.valid(d),value)
        d=copy.deepcopy(self.data);d['snapshots'][0]['nodes'][0].update(address='0xffffffffffffffff',size=1);self.assertFalse(self.valid(d))
    def test_closed_schema_and_provenance(self):
        for mutate in [lambda d:d.update(extra=1),lambda d:d.update(version=2),lambda d:d.update(provenance=3),lambda d:d['snapshots'][0].update(extra=1),lambda d:d['snapshots'][0]['nodes'][0].update(extra=1)]:
            d=copy.deepcopy(self.data);mutate(d);self.assertFalse(self.valid(d))
    def test_duplicate_and_cyclic_identity(self):
        for mutate in [lambda d:d['entrypoints'].append(copy.deepcopy(d['entrypoints'][0])),lambda d:d['snapshots'].append(copy.deepcopy(d['snapshots'][0])),lambda d:d['snapshots'][0]['nodes'].append(copy.deepcopy(d['snapshots'][0]['nodes'][0])),lambda d:d['snapshots'][0]['nodes'][0].update(parent='code'),lambda d:d['snapshots'][0]['nodes'][0].update(parent='absent')]:
            d=copy.deepcopy(self.data);mutate(d);self.assertFalse(self.valid(d))
    def test_pointer_lifetime_and_missing_target(self):
        d=copy.deepcopy(self.data);d['snapshots'][6]['links'][-1]['kind']=1;self.assertFalse(self.valid(d))
        d=copy.deepcopy(self.data);d['snapshots'][4]['links'][-1]['to']='missing';self.assertFalse(self.valid(d))
        d=copy.deepcopy(self.data);d['snapshots'][4]['links'][-1]['kind']=2;self.assertTrue(self.valid(d))
    def test_thread_instances_and_allocator_capacity(self):
        d=copy.deepcopy(self.data);d['snapshots'][0]['nodes'][1]['thread']='T2';self.assertFalse(self.valid(d))
        d=copy.deepcopy(self.data);next(n for n in d['snapshots'][4]['nodes'] if n['id']=='H1')['capacity']=64;self.assertFalse(self.valid(d))
        d['allocator']='generic';self.assertTrue(self.valid(d))
    def test_limits(self):
        for mutate in [lambda d:d.update(snapshots=[]),lambda d:d['snapshots'][0].update(nodes=[]),lambda d:d['snapshots'][0]['nodes'][0].update(size=1073741825),lambda d:d['snapshots'][0]['nodes'][0].update(id='x'*129)]:
            d=copy.deepcopy(self.data);mutate(d);self.assertFalse(self.valid(d))
if __name__=='__main__':unittest.main()
