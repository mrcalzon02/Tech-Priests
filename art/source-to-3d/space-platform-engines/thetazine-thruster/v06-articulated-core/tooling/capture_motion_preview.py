"""Render the frozen V06 axial/torsional mechanism cycle, no game client."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys

import bpy
from mathutils import Vector

p=argparse.ArgumentParser()
p.add_argument("--source",type=Path,required=True)
p.add_argument("--out",type=Path,required=True)
p.add_argument("--views",default="whole,mechanism")
a=p.parse_args(sys.argv[sys.argv.index("--")+1:])
a.source=a.source.resolve()
a.out=a.out.resolve()
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
a.out.mkdir(parents=True,exist_ok=True)
receipt=a.out/"motion-capture.json"
binding={"source_sha256":sha(a.source),"capture_script_sha256":sha(Path(__file__))}
state={"status":"RENDERING_FROZEN_MECHANICAL_CYCLE","binding":binding,"pid":os.getpid(),
       "fps":30,"cold_frame":0,"working_frames":[1,64],"wrap_frame":65,"frames":[],
       "scope":"Actual source poses with original mechanisms and host-following new hardware. Source-only combustion is present only in whole view; no native timing/state or new runtime atlas claim."}
if receipt.exists():
    old=json.loads(receipt.read_text(encoding="utf-8"))
    assert old["binding"]==binding,"Fresh output required after source/script change"
    state["frames"]=old["frames"]
bpy.ops.wm.open_mainfile(filepath=str(a.source.resolve()))
s=bpy.context.scene
s.render.engine="BLENDER_EEVEE"
s.render.image_settings.file_format="PNG"
s.render.image_settings.color_mode="RGBA"
s.render.resolution_percentage=100
s.render.film_transparent=True
s.render.dither_intensity=0
if hasattr(s.eevee,"taa_render_samples"):s.eevee.taa_render_samples=64
original_camera={"location":s.camera.location.copy(),"rotation":s.camera.rotation_euler.copy(),"scale":s.camera.data.ortho_scale}
volumes=[o for o in s.objects if o.get("render_only_volume")]
original_visibility={o.name:o.hide_render for o in volumes}
for view in a.views.split(","):
    assert view in ("whole","mechanism"),view
    if view=="whole":
        s.render.resolution_x=512;s.render.resolution_y=1280
        s.camera.location=original_camera["location"];s.camera.rotation_euler=original_camera["rotation"];s.camera.data.ortho_scale=original_camera["scale"]
        for o in volumes:o.hide_render=original_visibility[o.name]
    else:
        s.render.resolution_x=640;s.render.resolution_y=768
        s.camera.location=(3,-7,3.5);target=Vector((0,-3.3,-1.3))
        s.camera.rotation_euler=(target-s.camera.location).to_track_quat("-Z","Y").to_euler();s.camera.data.ortho_scale=6.0
        for o in volumes:o.hide_render=True
    for frame in range(66):
        target=a.out/view/(f"{frame:02}.png");target.parent.mkdir(exist_ok=True)
        prior=next((x for x in state["frames"]if x["view"]==view and x["frame"]==frame),None)
        if prior:
            assert target.exists()and sha(target)==prior["sha256"]
            continue
        s.frame_set(frame);bpy.context.view_layer.update()
        s.render.filepath=str(target);bpy.ops.render.render(write_still=True)
        state["frames"].append({"view":view,"frame":frame,"file":str(target.relative_to(a.out)),"sha256":sha(target),
                                "size":[s.render.resolution_x,s.render.resolution_y]})
        receipt.write_text(json.dumps(state,indent=2)+"\n",encoding="utf-8")
        print("MOTION_PREVIEW",view,frame,flush=True)
state["status"]="CAPTURED64_MECHANICAL_CYCLE_PLUS_COLD_AND_WRAP_REQUIRES_VIEW"
receipt.write_text(json.dumps(state,indent=2)+"\n",encoding="utf-8")
assert sha(a.source)==binding["source_sha256"]
print(state["status"],flush=True)
