"""Streaming decompression for Blender's concatenated Zstd frames; byte-preserving."""
import ctypes,ctypes.util
from pathlib import Path
import sys

class In(ctypes.Structure):
 _fields_=[('src',ctypes.c_void_p),('size',ctypes.c_size_t),('pos',ctypes.c_size_t)]
class Out(ctypes.Structure):
 _fields_=[('dst',ctypes.c_void_p),('size',ctypes.c_size_t),('pos',ctypes.c_size_t)]

lib=ctypes.CDLL(ctypes.util.find_library('zstd'))
lib.ZSTD_createDStream.restype=ctypes.c_void_p
lib.ZSTD_initDStream.restype=ctypes.c_size_t
lib.ZSTD_initDStream.argtypes=[ctypes.c_void_p]
lib.ZSTD_freeDStream.restype=ctypes.c_size_t
lib.ZSTD_freeDStream.argtypes=[ctypes.c_void_p]
lib.ZSTD_decompressStream.restype=ctypes.c_size_t
lib.ZSTD_decompressStream.argtypes=[ctypes.c_void_p,ctypes.POINTER(Out),ctypes.POINTER(In)]
lib.ZSTD_isError.restype=ctypes.c_uint
lib.ZSTD_isError.argtypes=[ctypes.c_size_t]

src=Path(sys.argv[1]);dst=Path(sys.argv[2])
if dst.exists():raise RuntimeError('Refusing to overwrite existing output')
d=lib.ZSTD_createDStream()
if not d:raise RuntimeError('Failed to create Zstd decoder')
res=lib.ZSTD_initDStream(d)
if lib.ZSTD_isError(res):raise RuntimeError('Zstd init error')
input_size=output_size=0
block_no=0
try:
 with src.open('rb') as f,dst.open('xb') as g:
  while True:
   data=f.read(4*1024*1024)
   if not data:break
   ibuf=ctypes.create_string_buffer(data,len(data))
   inp=In(ctypes.addressof(ibuf),len(data),0)
   while inp.pos<inp.size:
    outbuf=ctypes.create_string_buffer(8*1024*1024)
    out=Out(ctypes.addressof(outbuf),len(outbuf),0)
    res=lib.ZSTD_decompressStream(d,ctypes.byref(out),ctypes.byref(inp))
    if lib.ZSTD_isError(res):raise RuntimeError('Zstd stream failed at '+str(input_size+inp.pos))
    if out.pos:g.write(outbuf.raw[:out.pos]);output_size+=out.pos
   input_size+=len(data);block_no+=1
   if block_no%5==0:print('STREAMED',input_size,output_size,flush=True)
 finally_result=res
 print('DONE',input_size,output_size,'last-needed',res)
finally:
 lib.ZSTD_freeDStream(d)
