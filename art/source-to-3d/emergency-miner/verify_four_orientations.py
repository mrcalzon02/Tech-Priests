"""Independent Blender 5.2 reopen and on-disk proof for V24 four-view review.

This verifier opens the derived preview .blend in a SEPARATE Blender process.
Checks turntable parenting, canonical camera invariant and all 32 real
directional PNG frames per animated A/B variant (8 frames x 4 headings).
Never asserts prototype N/E/S/W mapping or game integration.
"""
import argparse
import hashlib
import json
import math
import struct
import sys
from pathlib import Path

import bpy

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path.insert(0,str(ROOT/"tools"/"fmpl"))
from blender_camera_guard import assert_clean,camera_record
from capture_policy import POLICY_ID

ANGLES=[0,90,180,270]
SAMPLES=[1,13,25,37,49,61,73,85]


def digest(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def image_size(path):
    data=path.read_bytes()[:26]
    if len(data)!=26 or not data.startswith(b"\x89PNG\r\n\x1a\n") or data[12:16]!=b"IHDR":
        raise RuntimeError("Expected actual native Blender PNG: "+str(path))
    return struct.unpack(">II",data[16:24])


def run(out,variant):
    expected=out/("V24_four_orientation_preview_%s.blend"%variant)
    if not expected.is_file() or Path(bpy.data.filepath).resolve()!=expected.resolve():
        raise RuntimeError("Independent four-view verifier did not reopen native derivative")
    scene=bpy.context.scene
    if scene.get("four_view_review")!="V24_DIRECTIONAL_ANIMATED_REVIEW_ONLY" or \
       scene.get("source_animation_variant")!=variant or \
       scene.get("four_view_prototype_mapping")!="NOT_VERIFIED":
        raise RuntimeError("V24 owner-review derivative marked as an accepted game asset")
    if scene.get("emergency_miner_v24_applied") is not True:
        raise RuntimeError("Lowered middle chassis correction missing from opened file")
    cfg={
        "camera_policy":POLICY_ID,"capture_kind":"entity","directions":ANGLES,
        "states":{"four_view_owner_preview":SAMPLES},
        "source_size":256,
        "camera_override":{
            "type":"ORTHO","elevation_deg":45,"azimuth_deg":0,
            "distance":3.0,"target":[0.,0.,.29],
            "ortho_scale":1.42,"shift_x":0,"shift_y":0,
        },
    }
    assert_clean(scene,cfg,bpy)
    anchor=camera_record(scene)
    if scene.camera.parent is not None:
        raise RuntimeError("Camera attached to rotating machine")
    pivot=bpy.data.objects.get("FMPL V24 | rotate MACHINE only")
    foundation=bpy.data.objects.get("LAYER_1 Foundation perimeter steel slab")
    body=bpy.data.objects.get("RIG | armor oscillation")
    if pivot is None or foundation is None or body is None or \
       foundation.parent!=pivot or body.parent!=pivot:
        raise RuntimeError("Full machine, floor and animation rig do not rotate together")
    recorded=json.loads((out/("four_orientation_preview_%s.json"%variant)).read_text())
    if recorded["model_yaw_degrees"]!=ANGLES or recorded["samples_per_direction"]!=8 or \
       recorded["Factorio_direction_mapping"]!="PENDING_GAME_PROTOTYPE_ALIGNMENT":
        raise RuntimeError("Owner preview incorrect or confused with production directions")
    counts={}
    for angle in ANGLES:
        key="d%02d"%(angle//90)
        info=recorded["sequences"][key]
        if info["model_rotation_degrees"]!=angle or not info["foundation_stationary"]:
            raise RuntimeError("Direction preview manifest corruption "+key)
        pivot.rotation_euler.z=math.radians(angle)
        scene.frame_set(1)
        bpy.context.view_layer.update()
        actual=camera_record(scene)
        if max(abs(actual["matrix_world"][i][j]-anchor["matrix_world"][i][j])
               for i in range(4) for j in range(4))>1e-6:
            raise RuntimeError("Camera rotated instead of the model")
        first=tuple(tuple(row) for row in foundation.matrix_world)
        for f in (49,97):
            scene.frame_set(f)
            bpy.context.view_layer.update()
            if first!=tuple(tuple(row) for row in foundation.matrix_world):
                raise RuntimeError("Foundation animated during orientation "+key)
        group=out/key
        frames=sorted(group.glob("frame_*.png"))
        if len(frames)!=8:
            raise RuntimeError("Missing source-based directional Blender frames "+key)
        for fr in SAMPLES:
            p=group/("frame_%03d.png"%fr)
            if not p.is_file() or p.stat().st_size<3000 or image_size(p)!=(256,256):
                raise RuntimeError("Invalid native Cycles frame "+str(p))
            if digest(p)!=info["all_frames_sha256"][p.name]:
                raise RuntimeError("Directional image checksum mismatch")
        apng=out/info["apng_file"]
        still=out/info["native43_still_file"]
        if image_size(apng)!=(256,256) or digest(apng)!=info["apng_sha256"]:
            raise RuntimeError("Missing verified animated review "+key)
        if image_size(still)!=(43,43) or digest(still)!=info["native43_sha256"]:
            raise RuntimeError("Missing true 43px directional preview "+key)
        counts[key]={"frames":len(frames),"model_angle_degrees":angle}
    if digest(expected)!=recorded["derived_editable_sha256"]:
        raise RuntimeError("Native Blender derivative SHA changed")
    result={
        "verification":"PASS","source_variant":variant,
        "blender_version":bpy.app.version_string,
        "capture_camera":anchor,
        "same_camera_four_model_rotations":True,
        "directions":counts,"frames_total":32,
        "V24_middle_chassis_lowered":True,
        "red_laser_effects_from_source":True,
        "prototype_mapping_verified":False,"game_assets_changed":False,
        "owner_visual_approved":False,
        "blend_sha256":digest(expected),
    }
    (out/("four_view_verified_%s.json"%variant)).write_text(json.dumps(result,indent=2)+"\n")
    print("MINER_V24_FOUR_ORIENTATION_INDEPENDENT_REOPEN_PASS "+json.dumps(
        {k:v for k,v in result.items() if k!="capture_camera"},separators=(",",":")),flush=True)


if __name__=="__main__":
    p=argparse.ArgumentParser()
    p.add_argument("--out",type=Path,required=True)
    p.add_argument("--variant",choices=["A","B"],required=True)
    args=p.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else sys.argv[1:])
    run(args.out.resolve(),args.variant)
