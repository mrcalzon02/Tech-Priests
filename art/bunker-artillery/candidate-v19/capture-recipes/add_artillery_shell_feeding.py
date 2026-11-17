"""Add shell insertion to the exact inspected artillery master, preserving body."""
import bpy,sys,math,json,hashlib,shutil
from pathlib import Path
from mathutils import Vector
source,out=map(Path,sys.argv[sys.argv.index('--')+1:]);out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(1)
rounds=[bpy.data.objects['LOADED_ARTILLERY_SHELL_'+str(i)]for i in range(3)]
rest=[r.location.copy()for r in rounds]
for tick in range(601):
 s.frame_set(tick+1)
 for cell,r in enumerate(rounds):
  start=450+15*cell;u=max(0,min(1,(tick-start)/15));u=u*u*(3-2*u)
  r.location=rest[cell]+Vector((0,2.7*(1-u)if tick>=start else 0,0));r.keyframe_insert('location')
  loaded=tick<=cell*90 or tick>=start;r.scale=(1,1,1)if loaded else (0,0,0);r.keyframe_insert('scale')
s.frame_set(1);target=out/'rolling-artillery.blend';bpy.ops.wm.save_as_mainfile(filepath=str(target),compress=True)
# The interchange is static at frame zero: no geometry or rest transforms changed.
shutil.copy2(source.with_suffix('.glb'),out/'rolling-artillery.glb')
contract=json.loads((source.parent/'contract.json').read_text());contract.update(native_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
 source_basis_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),shell_feed_ticks=[[450,465],[465,480],[480,495]],
 scope='Exact inspected structural master; adds rearward shell emergence and sliding insertion after the drum returns home.')
(out/'contract.json').write_text(json.dumps(contract,indent=2)+'\n')
print('ARTILLERY_SHELL_INSERTION_AUTHORED',flush=True)
