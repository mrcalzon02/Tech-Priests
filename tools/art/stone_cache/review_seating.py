"""Oblique close-up of actual GLB to expose the relief/stone junction."""
import bpy,json,hashlib
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/martian-stone-cache/v01'
bpy.ops.wm.open_mainfile(filepath=str(O/'martian-stone-cache-v01.blend'));s=bpy.context.scene
for ob in list(s.objects):
 if ob.type in ('MESH','EMPTY'):bpy.data.objects.remove(ob,do_unlink=True)
bpy.ops.import_scene.gltf(filepath=str(O/'martian-stone-cache-v01.glb'))
camera=s.camera;target=Vector((0,-.94,.47));camera.location=target+Vector((1.5,-2.5,1.0));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=.83
s.render.resolution_x=768;s.render.resolution_y=768;s.cycles.samples=48;s.render.filepath=str(O/'inspection/relief-seating-oblique.png');bpy.ops.render.render(write_still=True)
receipt=dict(purpose='Oblique actual-export inspection only; production FMPL camera unchanged',export_sha256=hashlib.sha256((O/'martian-stone-cache-v01.glb').read_bytes()).hexdigest(),render='inspection/relief-seating-oblique.png')
(O/'relief-seating-review.json').write_text(json.dumps(receipt,indent=2))
