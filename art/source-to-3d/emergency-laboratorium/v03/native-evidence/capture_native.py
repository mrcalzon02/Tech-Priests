"""Run the existing Factorio renderer on a task-owned non-input desktop.
No desktop switching, keyboard/mouse input, or default-desktop fallback exists.
Screenshots are produced by Factorio's native game.take_screenshot API.
"""
from pathlib import Path
import subprocess,json,ctypes,time,shutil,struct,zlib,hashlib
from ctypes import wintypes as W
R=Path(__file__).resolve().parent;M=R.parent/'tp-sterling-contract-main01/mods';OUT=R/'native-capture';OUT.mkdir(exist_ok=True);runtime=R/'coupled-client-runtime';runtime.mkdir(exist_ok=True);(R/'steam_appid.txt').write_text('427520\n');config=R/'coupled-client-config.ini';config.write_text('[path]\nread-data=C:/Program Files (x86)/Steam/steamapps/common/Factorio/data\nwrite-data='+str(runtime)+'\n[graphics]\nfull-screen=false\n')
(M/'laboratorium-v1-proof_0.0.1/control.lua').write_bytes((R/'laboratorium-proof-control.lua').read_bytes());d=M/'laboratorium-v1-capture_0.0.1';d.mkdir(exist_ok=True);(d/'info.json').write_text(json.dumps({'name':'laboratorium-v1-capture','version':'0.0.1','title':'Actual native laboratorium idle and working capture','author':'local','factorio_version':'2.1','dependencies':['base','space-age','tech-priests','laboratorium-v1-proof']}));(d/'control.lua').write_text((R/'laboratorium-capture-control.lua').read_text().replace('2.5or 4','2.5 or 4'));p=M/'mod-list.json';mods=json.loads(p.read_text());mods['mods']=[x for x in mods['mods']if x['name']!='laboratorium-v1-capture'];mods['mods'].append({'name':'laboratorium-v1-capture','enabled':True});p.write_text(json.dumps(mods));exe='C:/Program Files (x86)/Steam/steamapps/common/Factorio/bin/x64/factorio.exe';args=[exe,'--config',str(config),'--mod-directory',str(M)];save=R/'runtime/saves/laboratorium-operated.zip';assert save.exists()
U=ctypes.WinDLL('user32',use_last_error=True);K=ctypes.WinDLL('kernel32',use_last_error=True)
U.CreateDesktopW.argtypes=[W.LPCWSTR,W.LPCWSTR,ctypes.c_void_p,W.DWORD,W.DWORD,ctypes.c_void_p];U.CreateDesktopW.restype=W.HANDLE;U.CloseDesktop.argtypes=[W.HANDLE];U.CloseDesktop.restype=W.BOOL
class SI(ctypes.Structure):
 _fields_=[('cb',W.DWORD),('lpReserved',W.LPWSTR),('lpDesktop',W.LPWSTR),('lpTitle',W.LPWSTR),('dwX',W.DWORD),('dwY',W.DWORD),('dwXSize',W.DWORD),('dwYSize',W.DWORD),('dwXCountChars',W.DWORD),('dwYCountChars',W.DWORD),('dwFillAttribute',W.DWORD),('dwFlags',W.DWORD),('wShowWindow',W.WORD),('cbReserved2',W.WORD),('lpReserved2',ctypes.c_void_p),('hStdInput',W.HANDLE),('hStdOutput',W.HANDLE),('hStdError',W.HANDLE)]
class PI(ctypes.Structure):_fields_=[('hProcess',W.HANDLE),('hThread',W.HANDLE),('dwProcessId',W.DWORD),('dwThreadId',W.DWORD)]
K.CreateProcessW.argtypes=[W.LPCWSTR,W.LPWSTR,ctypes.c_void_p,ctypes.c_void_p,W.BOOL,W.DWORD,ctypes.c_void_p,W.LPCWSTR,ctypes.POINTER(SI),ctypes.POINTER(PI)];K.CreateProcessW.restype=W.BOOL;K.GetExitCodeProcess.argtypes=[W.HANDLE,ctypes.POINTER(W.DWORD)];K.GetExitCodeProcess.restype=W.BOOL;K.TerminateProcess.argtypes=[W.HANDLE,W.UINT];K.WaitForSingleObject.argtypes=[W.HANDLE,W.DWORD];K.CloseHandle.argtypes=[W.HANDLE]
name='CodexLaboratoriumCapture-'+str(int(time.time()));desk=U.CreateDesktopW(name,None,None,0,0xC7,None);assert desk,('Cannot create task desktop',ctypes.get_last_error());si=SI();si.cb=ctypes.sizeof(si);si.lpDesktop='winsta0\\'+name;si.dwFlags=1;si.wShowWindow=0;pi=PI();started=time.time();cmd=ctypes.create_unicode_buffer(subprocess.list2cmdline(args+['--load-game',str(save),'--disable-audio','--disable-migration-window','--graphics-quality','medium','--video-memory-usage','low']))
created=K.CreateProcessW(exe,cmd,None,None,False,0,None,str(R),ctypes.byref(si),ctypes.byref(pi))
if not created:U.CloseDesktop(desk);raise OSError(ctypes.get_last_error(),'Private desktop capture process not created; no default desktop fallback')
print('PRIVATE_NATIVE_CAPTURE_STARTED',pi.dwProcessId,flush=True);(OUT/'owned-process.json').write_text(json.dumps({'pid':pi.dwProcessId,'desktop':name,'desktop_switched':False,'default_desktop_fallback':False,'native_game_renderer':True},indent=2))
def alive():
 code=W.DWORD();assert K.GetExitCodeProcess(pi.hProcess,ctypes.byref(code));return code.value==259
def valid(p):
 if not p.exists()or p.stat().st_mtime<started:return False
 b=p.read_bytes();i=8
 if b[:8]!=b'\x89PNG\r\n\x1a\n':return False
 while i+12<=len(b):
  n=struct.unpack_from('>I',b,i)[0];end=i+12+n
  if end>len(b)or zlib.crc32(b[i+4:i+8+n])!=struct.unpack_from('>I',b,i+8+n)[0]:return False
  if b[i+4:i+8]==b'IEND':return end==len(b)
  i=end
 return False
capture=runtime/'script-output/laboratorium-native/capture.json';receipt=None
try:
 deadline=time.monotonic()+90
 while time.monotonic()<deadline and alive():
  if capture.exists()and capture.stat().st_mtime>=started:
   receipt=json.loads(capture.read_text());expected=[runtime/'script-output/laboratorium-native'/x['file']for x in receipt['frames']]+[runtime/'script-output/laboratorium-native'/x for x in receipt['wide']]
   if receipt['passed']and all(valid(x)for x in expected):break
  time.sleep(.5)
 passed=receipt is not None and receipt['passed']and all(valid(x)for x in expected)
finally:
 if alive():K.TerminateProcess(pi.hProcess,0);K.WaitForSingleObject(pi.hProcess,15000)
 K.CloseHandle(pi.hThread);K.CloseHandle(pi.hProcess);U.CloseDesktop(desk)
log=runtime/'factorio-current.log'
if log.exists():shutil.copy2(log,OUT/'client.log')
if passed:
 for p in expected:shutil.copy2(p,OUT/p.name)
 shutil.copy2(capture,OUT/'capture.json');receipt['screenshots']=[{'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}for p in expected]
result={'genuine_native_capture':passed,'separate_task_desktop':True,'default_desktop_untouched':True,'capture':receipt,'engine_graphics_quality':'medium','owner_visual_approved':False};(OUT/'capture-receipt.json').write_text(json.dumps(result,indent=2));print('LABORATORIUM_PRIVATE_NATIVE_CAPTURE',passed,len(receipt['frames'])if receipt else 0,flush=True);assert passed
