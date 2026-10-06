#!/usr/bin/env python3
"""Native clipboard negotiation and INCR on a private Xvfb display.
Set RHUN_XVFB to an Xvfb executable when it is not on PATH. Never uses the user's display.
"""
import ctypes as C
import struct
import zlib
import importlib.util
import json
import os
from pathlib import Path
import select
import socket
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
ROOT=Path(__file__).resolve().parents[1]

def owner(display,mime,path,incr):
    x=C.CDLL('libX11.so.6');V=C.c_void_p;U=C.c_ulong;I=C.c_int
    declarations={
        'XOpenDisplay':(V,[C.c_char_p]),'XDefaultRootWindow':(U,[V]),
        'XCreateSimpleWindow':(U,[V,U,I,I,U,U,U,U,U]),'XInternAtom':(U,[V,C.c_char_p,I]),
        'XSetSelectionOwner':(I,[V,U,U,U]),'XGetSelectionOwner':(U,[V,U]),
        'XChangeProperty':(I,[V,U,U,U,I,I,V,I]),'XSendEvent':(I,[V,U,I,C.c_long,V]),
        'XSelectInput':(I,[V,U,C.c_long]),'XNextEvent':(I,[V,V]),'XFlush':(I,[V])}
    for name,(result,args) in declarations.items():
        f=getattr(x,name);f.restype=result;f.argtypes=args
    d=x.XOpenDisplay(display.encode());assert d
    w=x.XCreateSimpleWindow(d,x.XDefaultRootWindow(d),0,0,1,1,0,0,0)
    atom=lambda name:x.XInternAtom(d,name.encode(),0)
    clip=atom('CLIPBOARD');targets=atom('TARGETS');utf8=atom('UTF8_STRING')
    native=atom(mime);incra=atom('INCR');data=Path(path).read_bytes()
    class Request(C.Structure):
        _fields_=[('type',I),('serial',U),('send',I),('display',V),('owner',U),('requestor',U),('selection',U),('target',U),('property',U),('time',U)]
    class Notify(C.Structure):
        _fields_=[('type',I),('serial',U),('send',I),('display',V),('requestor',U),('selection',U),('target',U),('property',U),('time',U)]
    class Property(C.Structure):
        _fields_=[('type',I),('serial',U),('send',I),('display',V),('window',U),('atom',U),('time',U),('state',I)]
    def prop(window,p,t,fmt,b,n):x.XChangeProperty(d,window,p,t,fmt,0,C.cast(b,V),n)
    x.XSetSelectionOwner(d,clip,w,0);x.XFlush(d)
    assert x.XGetSelectionOwner(d,clip)==w
    print('ready',flush=True);pending={}
    event=(C.c_long*24)()
    while True:
        x.XNextEvent(d,event);kind=C.cast(event,C.POINTER(I))[0]
        if kind==30:
            r=C.cast(event,C.POINTER(Request)).contents;p=r.property or r.target
            if r.target==targets:
                # Also advertise text: chat must prefer the object MIME.
                values=(U*3)(targets,utf8,native);prop(r.requestor,p,4,32,values,3)
            elif r.target in (native,utf8):
                payload=data if r.target==native else b'fallback text'
                if incr and r.target==native:
                    x.XSelectInput(d,r.requestor,1<<22)
                    values=(U*1)(len(payload));prop(r.requestor,p,incra,32,values,1)
                    pending[(r.requestor,p)]=(payload,0,r.target)
                else:
                    buf=C.create_string_buffer(payload);prop(r.requestor,p,r.target,8,buf,len(payload))
            else:p=0
            n=Notify(31,0,0,d,r.requestor,r.selection,r.target,p,r.time)
            x.XSendEvent(d,r.requestor,0,0,C.byref(n));x.XFlush(d)
        elif kind==28:
            r=C.cast(event,C.POINTER(Property)).contents;k=(r.window,r.atom)
            if r.state==1 and k in pending:
                payload,offset,target=pending[k];chunk=payload[offset:offset+16384]
                buf=C.create_string_buffer(chunk);prop(r.window,r.atom,target,8,buf,len(chunk))
                pending[k]=(payload,offset+len(chunk),target)
                if not chunk:del pending[k]
                x.XFlush(d)

spec=importlib.util.spec_from_file_location('store',ROOT/'tests/chat-store.py')
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
XVFB=os.environ.get('RHUN_XVFB') or shutil.which('Xvfb')
@unittest.skipUnless(XVFB and sys.platform=='linux','requires private Xvfb')
class X11Clipboard(mod.ChatStore):
    def setUp(self):
        super().setUp();read,write=os.pipe()
        self.server=subprocess.Popen([XVFB,'-displayfd',str(write),'-screen','0','1000x700x24','-nolisten','tcp','-ac'],pass_fds=(write,),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        os.close(write)
        self.addCleanup(self.stop,self.server)
        self.assertTrue(select.select([read],[],[],5)[0],'Xvfb failed to start')
        self.display=':'+os.read(read,64).decode().strip();os.close(read)
        self.env.update(DISPLAY=self.display,RHUN_BACKEND='x11',XAUTHORITY=str(self.home/'none'))
        self.env.pop('WAYLAND_DISPLAY',None);self.env.pop('WAYLAND_SOCKET',None)
    @staticmethod
    def stop(p):
        if p.poll() is None:
            p.terminate()
            try:p.wait(timeout=3)
            except subprocess.TimeoutExpired:p.kill();p.wait()
        for stream in (p.stdout,p.stderr):
            if stream:stream.close()
    def paste_native(self,mime,data,incr=False):
        path=self.home/'clipboard';path.write_bytes(data)
        p=subprocess.Popen([sys.executable,__file__,'--owner',self.display,mime,str(path),str(int(incr))],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        self.addCleanup(self.stop,p)
        self.assertTrue(select.select([p.stdout],[],[],5)[0],'owner timeout')
        self.assertEqual(p.stdout.readline(),b'ready\n')
        control=self.home/'editor.sock'
        editor=subprocess.Popen([mod.EXE,self.project,'--control',control],env=self.env,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
        self.addCleanup(self.stop,editor)
        deadline=time.monotonic()+5
        while not control.exists() and time.monotonic()<deadline:time.sleep(.02)
        self.assertTrue(control.exists(),'editor startup failed')
        client=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM);client.settimeout(5);client.connect(str(control))
        reader=client.makefile('r')
        def command(text):
            client.sendall((text+'\n').encode());result=[]
            while True:
                line=reader.readline()
                if line=='ok\n':return ''.join(result)
                self.assertNotIn(line,('', 'error\n'));result.append(line)
        try:
            command('cmd chat_new')
            deadline=time.monotonic()+5
            while 'chat-state=3' not in command('print-chat-status') and time.monotonic()<deadline:time.sleep(.02)
            command('key ctrl+v');time.sleep(.6)
            command('key enter');time.sleep(.4)
            command('quit');editor.wait(timeout=5)
        finally:reader.close();client.close()
        turns=[m for m in self.messages() if m.get('method')=='turn/start']
        if not turns:print('STATE',self.state_path().read_text(),file=sys.stderr)
        self.assertTrue(turns,'no submitted turn')
        return turns[0]['params']['input']
    def test_uri_preferred_over_text(self):
        p=self.project/'context café.txt';p.write_text('Native clipboard file context')
        value=self.paste_native('text/uri-list',(p.as_uri()+'\r\n').encode())
        self.assertIn('Native clipboard file context',value[0]['text'])
        self.assertNotIn('fallback text',value[0]['text'])
    def test_gnome_files_preferred_over_text(self):
        p=self.project/'gnome.txt';p.write_text('GNOME native context')
        value=self.paste_native('x-special/gnome-copied-files',('copy\n'+p.as_uri()).encode())
        self.assertIn('GNOME native context',value[0]['text'])
    def test_png_direct(self):
        raw=(ROOT/'tests/data/images/gray16-adam7.png').read_bytes()
        value=self.paste_native('image/png',raw)
        self.assertEqual(Path(value[1]['path']).read_bytes(),raw)
    def test_png_incremental_larger_than_old_x11_buffer(self):
        def chunk(kind,data):
            return struct.pack('!I',len(data))+kind+data+struct.pack('!I',zlib.crc32(kind+data))
        pixels=b''.join(b'\0'+os.urandom(600) for _ in range(600))
        raw=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('!IIBBBBB',600,600,8,0,0,0,0))+chunk(b'IDAT',zlib.compress(pixels))+chunk(b'IEND',b'')
        value=self.paste_native('image/png',raw,True)
        self.assertEqual(Path(value[1]['path']).read_bytes(),raw)
    def test_jpeg_direct(self):
        raw=(ROOT/'tests/data/images/baseline-420.jpg').read_bytes()
        value=self.paste_native('image/jpeg',raw)
        self.assertEqual(Path(value[1]['path']).read_bytes(),raw)
    def test_utf8_only(self):
        value=self.paste_native('UTF8_STRING','Native text café https://example.org'.encode())
        self.assertEqual(value[0]['text'],'Native text café https://example.org')
for name in vars(mod.ChatStore):
    if name.startswith('test_') and name not in vars(X11Clipboard):setattr(X11Clipboard,name,None)
if __name__=='__main__':
    if len(sys.argv)>1 and sys.argv[1]=='--owner':owner(*sys.argv[2:5],bool(int(sys.argv[5])))
    else:unittest.main()
