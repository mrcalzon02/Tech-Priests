"""Export the real evaluated muzzle socket positions for native projectile tests."""
import bpy,json,sys,hashlib
from pathlib import Path
native,out=map(Path,sys.argv[sys.argv.index('--')+1:]);bpy.ops.wm.open_mainfile(filepath=str(native))
bpy.context.scene.frame_set(1)
sockets=[]
for bank,cell in ((0,0),(1,0),(0,1),(1,1),(0,2),(1,2)):
    ob=bpy.data.objects['MUZZLE_%d_%d'%(bank,cell)]
    sockets.append({'bank':bank,'cell':cell,'position':list(ob.matrix_world.translation)})
out.parent.mkdir(parents=True,exist_ok=True)
out.write_text('-- Generated from checked candidate-v02 muzzle empties; do not hand-adjust.\nreturn {\n'+
    ',\n'.join('  {%.12f,%.12f,%.12f}'%tuple(o['position']) for o in sockets)+'\n}\n')
(out.with_suffix('.json')).write_text(json.dumps({'native_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'sockets':sockets},indent=2)+'\n')
print('ROCKET_SOCKETS_EXTRACTED',len(sockets))
