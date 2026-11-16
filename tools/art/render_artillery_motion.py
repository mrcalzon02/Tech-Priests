"""Render real source recoil, drum indexing and service-gate motion for review."""
import bpy,sys,json,math,hashlib
from pathlib import Path
from mathutils import Vector

arguments=sys.argv[sys.argv.index('--')+1:]
source,out=(Path(p).resolve() for p in arguments[:2]);out.mkdir(parents=True,exist_ok=True)
mount_only='--mount-only' in arguments[2:]
identity={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
 'script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'cell':384,'step':6,'source_fps':60,'mount_only':mount_only}
if (out/'identity.json').exists():assert json.loads((out/'identity.json').read_text())==identity
else:(out/'identity.json').write_text(json.dumps(identity,indent=2)+'\n')
bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene
s.render.resolution_x=s.render.resolution_y=384;s.render.resolution_percentage=100
s.cycles.samples=8;s.cycles.use_denoising=True
root=bpy.data.objects['TURRET_TRAVERSE'];root.rotation_euler.z=math.pi/4
ticks=sorted(set(list(range(0,601,6))+[3,93,183,600]))
if mount_only:ticks=[]
for tick in ticks:
    s.frame_set(tick+1);target=out/f'tick-{tick:03d}.png'
    if not target.exists():s.render.filepath=str(target);bpy.ops.render.render(write_still=True)
    print('ARTILLERY_MOTION_FRAME',tick,flush=True)
s.frame_set(1);root.rotation_euler.z=0
s.camera.location=(5,-6,4.2);s.camera.rotation_euler=(Vector((0,0,2.35))-s.camera.location).to_track_quat('-Z','Y').to_euler()
s.camera.data.ortho_scale=4.3;s.render.resolution_x=s.render.resolution_y=640
s.render.filepath=str(out/'mount-detail.png');bpy.ops.render.render(write_still=True)
(out/'review.json').write_text(json.dumps({'status':'MOUNT_DETAIL_ONLY' if mount_only else 'COMPLETE','identity':identity,'ticks':ticks,
 'scope':'Source-model movement only. No baked firing effects, foundation or native-gameplay claim.'},indent=2)+'\n')
