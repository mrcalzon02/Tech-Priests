"""V24 Emergency Miner: genuine four-direction OWNER PREVIEW, never a sprite export.

One unmodified FMPL 45-degree orthographic camera. Turn the original machine
and its REAL red laser/steam rigs by 0, 90, 180, 270 degrees, not the camera.
Eight Cycles samples of the existing authored 16-pose loop per direction.
A full 16-pose canonical cycle remains in each original A/B .blend.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path.insert(0,str(HERE))
sys.path.insert(0,str(ROOT/"tools"/"fmpl"))

from animate_preview import FRAMES,pack_apng
from blender_camera_guard import assert_clean,camera_record
from capture_policy import POLICY_ID

ANGLES=[0,90,180,270]
SAMPLED=FRAMES[::2]
PIXELS=256
CYCLES_SAMPLES=12


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def profile():
    return {
        "camera_policy":POLICY_ID,
        "capture_kind":"entity",
        "directions":ANGLES,
        "states":{"four_view_owner_preview":SAMPLED},
        "source_size":PIXELS,
        "camera_override":{
            "type":"ORTHO","elevation_deg":45,"azimuth_deg":0,
            "distance":3.0,"target":[0.0,0.0,0.29],
            "ortho_scale":1.42,"shift_x":0,"shift_y":0,
        },
    }


def make_turntable(scene):
    if scene.get("emergency_miner_v24_applied") is not True:
        raise RuntimeError("Refuse preview of an older/non-V24 miner")
    visible=bpy.data.collections.get("SOURCE_VISIBLE_CONTROL_ENCLOSURE")
    animated=bpy.data.collections.get("ANIMATION_ONLY__NON_GAMEPLAY")
    if visible is None or animated is None:
        raise RuntimeError("Missing original visible machine or animation rig")
    candidates=set(list(visible.objects)+list(animated.objects))
    if any(o.type=="CAMERA" for o in candidates):
        raise RuntimeError("Camera must NOT be part of the model-turn rig")
    collection=bpy.data.collections.new("FMPL_DIRECTIONAL_REVIEW_ONLY")
    scene.collection.children.link(collection)
    pivot=bpy.data.objects.new("FMPL V24 | rotate MACHINE only",None)
    pivot.empty_display_size=.1
    collection.objects.link(pivot)
    pivot.location=(0,0,0)
    bpy.context.view_layer.update()
    count=0
    for ob in sorted(candidates,key=lambda x:x.name):
        if ob.parent is not None:
            continue
        if ob.type not in {"EMPTY","MESH","CURVE","LIGHT"}:
            continue
        world=ob.matrix_world.copy()
        ob.parent=pivot
        ob.matrix_world=world
        count+=1
    bpy.context.view_layer.update()
    if count<20:
        raise RuntimeError("Directional root did not capture full existing machine")
    foundation=bpy.data.objects.get("LAYER_1 Foundation perimeter steel slab")
    body=bpy.data.objects.get("RIG | armor oscillation")
    if foundation is None or body is None or body.parent!=pivot:
        raise RuntimeError("Existing foundation/body not connected to direction root")
    if bpy.context.scene.camera.parent is not None:
        raise RuntimeError("Camera was inadvertently parented to machine")
    return pivot,foundation,count


def run(out,variant):
    out.mkdir(parents=True,exist_ok=True)
    source=Path(bpy.data.filepath).resolve()
    expected="miner_motion_%s.blend"%variant
    if source.name!=expected:
        raise RuntimeError("Start Blender from the original editable A/B BLEND: "+expected)
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    scene.cycles.samples=CYCLES_SAMPLES
    scene.render.film_transparent=True
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"
    scene.render.resolution_x=scene.render.resolution_y=PIXELS
    scene.render.resolution_percentage=100
    scene.render.fps=8
    cfg=profile()
    assert_clean(scene,cfg,bpy)
    before=camera_record(scene)
    if scene.get("original_sprite_replaced") is not False:
        raise RuntimeError("The production sprite may not be replaced")
    if scene.get("game_integration_status")!="NOT_INTEGRATED_REVIEW_ONLY":
        raise RuntimeError("V24 must remain for visual review")
    pivot,foundation,root_count=make_turntable(scene)
    scene["four_view_review"]="V24_DIRECTIONAL_ANIMATED_REVIEW_ONLY"
    scene["four_view_prototype_mapping"]="NOT_VERIFIED"
    scene["source_animation_variant"]=variant
    saved=out/("V24_four_orientation_preview_%s.blend"%variant)
    scene.frame_set(1)
    pivot.rotation_euler.z=0
    bpy.ops.wm.save_as_mainfile(filepath=str(saved))
    if not saved.is_file() or saved.stat().st_size<100000:
        raise RuntimeError("No editable four-view derivative saved")
    print("MINER_V24_4VIEW_SAVED_SOURCE "+str(saved),flush=True)

    result={
        "asset":"Tech Priests Emergency Miner","revision":"V24",
        "artifact_class":"STATIC_CAMERA_FOUR_MODEL_ROTATION_PREVIEW",
        "production_sprite_exported":False,
        "visual_approval":"PENDING",
        "game_art_modified":False,
        "source_blend_sha256":digest(source),
        "derived_editable_blend":saved.name,
        "derived_editable_sha256":digest(saved),
        "source_variant":variant,
        "camera_policy":POLICY_ID,
        "camera_unchanged":True,
        "model_yaw_degrees":ANGLES,
        "Factorio_direction_mapping":"PENDING_GAME_PROTOTYPE_ALIGNMENT",
        "rotation_root_parts":root_count,
        "samples_per_direction":len(SAMPLED),
        "sampled_source_frames":list(SAMPLED),
        "sampled_fps":4,
        "capture_resolution":[PIXELS,PIXELS],
        "sequences":{},
    }
    for angle in ANGLES:
        key="d%02d"%(angle//90)
        group=out/key
        group.mkdir(parents=True,exist_ok=True)
        pivot.rotation_euler.z=math.radians(angle)
        scene.frame_set(1)
        bpy.context.view_layer.update()
        assert_clean(scene,cfg,bpy)
        camera_now=camera_record(scene)
        for i in range(4):
            for j in range(4):
                if abs(before["matrix_world"][i][j]-camera_now["matrix_world"][i][j])>1e-6:
                    raise RuntimeError("FMPL camera moved while the MACHINE should rotate")
        frozen=[]
        for check_frame in (1,49,97):
            scene.frame_set(check_frame)
            bpy.context.view_layer.update()
            frozen.append(tuple(tuple(row) for row in foundation.matrix_world))
        if not all(pos==frozen[0] for pos in frozen):
            raise RuntimeError("Foundation moved within orientation "+key)
        captures=[]
        for frame in SAMPLED:
            scene.frame_set(frame)
            path=group/("frame_%03d.png"%frame)
            scene.render.filepath=str(path)
            print("MINER_V24_4VIEW_FRAME variant=%s direction=%s frame=%03d"%
                  (variant,key,frame),flush=True)
            bpy.ops.render.render(write_still=True)
            if not path.is_file() or path.stat().st_size<3000:
                raise RuntimeError("Missing native four-view frame: "+str(path))
            captures.append(path)
        apng=out/("miner_v24_%s_%s_animated.png"%(variant,key))
        width,height,count=pack_apng(captures,apng,playback_fps=4)
        if count!=len(SAMPLED) or width!=PIXELS or height!=PIXELS:
            raise RuntimeError("Wrong APNG dimensions or count")
        scene.render.resolution_x=scene.render.resolution_y=43
        scene.frame_set(37)
        still=out/("miner_v24_%s_%s_native43.png"%(variant,key))
        scene.render.filepath=str(still)
        bpy.ops.render.render(write_still=True)
        scene.render.resolution_x=scene.render.resolution_y=PIXELS
        result["sequences"][key]={
            "model_rotation_degrees":angle,
            "all_frames_sha256":{p.name:digest(p) for p in captures},
            "apng_file":apng.name,
            "apng_sha256":digest(apng),
            "native43_still_file":still.name,
            "native43_sha256":digest(still),
            "stationary_camera":True,"foundation_stationary":True,
            "frame_count":count,
        }
    receipt=out/("four_orientation_preview_%s.json"%variant)
    receipt.write_text(json.dumps(result,indent=2)+"\n",encoding="utf8")
    print("MINER_V24_FOUR_DIRECTION_PREVIEW_PASS "+json.dumps(
        {k:v for k,v in result.items() if k!="sequences"},separators=(",",":")),flush=True)


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--out",type=Path,required=True)
    parser.add_argument("--variant",choices=["A","B"],required=True)
    argv=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else sys.argv[1:]
    args=parser.parse_args(argv)
    run(args.out.resolve(),args.variant)
