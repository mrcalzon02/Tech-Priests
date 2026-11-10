"""Verify one independently opened Emergency Miner .blend and its native renders.

Launch a fresh Blender process for each variant, NOT bpy.ops.wm.open_mainfile
inside animate_preview.py (Blender 5.2.3 Windows crash C0000409).
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

import bpy
from mathutils import Matrix

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / "tools" / "fmpl"))
from blender_camera_guard import assert_clean, camera_record
from capture_policy import POLICY_ID


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main(folder, variant):
    master=folder/("miner_motion_"+variant+".blend")
    if not master.is_file() or bpy.data.filepath.lower() != str(master).lower():
        raise RuntimeError("Verifier must open the matching saved BLEND from CLI")
    scene=bpy.context.scene
    profile={
        "camera_policy": POLICY_ID,
        "capture_kind": "entity",
        "directions": [0,90,180,270],
        "states":{"motion_candidate":[1+6*i for i in range(16)]},
        "source_size":384,
        "camera_override":{
            "type":"ORTHO","elevation_deg":45,"azimuth_deg":0,
            "distance":3.0,"target":[0.0,0.0,0.29],
            "ortho_scale":1.42,"shift_x":0,"shift_y":0,
        },
    }
    assert_clean(scene,profile,bpy)
    if scene.get("study_variant") != variant:
        raise RuntimeError("Saved variant identity mismatch")
    if scene.get("visual_approval") != "PENDING":
        raise RuntimeError("Review status was mutated")
    if scene.get("original_sprite_replaced") is not False:
        raise RuntimeError("Source sprite replacement flagged")
    if scene.get("game_integration_status") != "NOT_INTEGRATED_REVIEW_ONLY":
        raise RuntimeError("Unexpected gameplay release status")
    collection=bpy.data.collections.get("SOURCE_VISIBLE_CONTROL_ENCLOSURE")
    rig=bpy.data.collections.get("ANIMATION_ONLY__NON_GAMEPLAY")
    if collection is None or rig is None:
        raise RuntimeError("Expected real source and separate animation rig collections")
    if len([x for x in bpy.data.objects if x.type=="CAMERA"])!=1:
        raise RuntimeError("Unexpected second camera")
    foundation=bpy.data.objects.get("LAYER_1 Foundation perimeter steel slab")
    body=bpy.data.objects.get("RIG | armor oscillation")
    upper=bpy.data.objects.get("RIG | upper photocopier cassette")
    if any(x is None for x in (foundation,body,upper)):
        raise RuntimeError("Motion rig is incomplete")
    positions=[]
    for f in (1,25,49,73,97):
        scene.frame_set(f)
        bpy.context.view_layer.update()
        positions.append(tuple(tuple(row) for row in foundation.matrix_world))
    if any(x!=positions[0] for x in positions):
        raise RuntimeError("Foundation moves or rotates during cycle")
    scene.frame_set(1)
    body_first=tuple(body.location)
    upper_first=tuple(upper.location)
    scene.frame_set(97)
    if max(abs(a-b) for a,b in zip(body_first,body.location))>1e-7:
        raise RuntimeError("Body root did not close loop")
    if max(abs(a-b) for a,b in zip(upper_first,upper.location))>1e-7:
        raise RuntimeError("Upper root did not close loop")
    frames=list((folder/variant).glob("frame_*.png"))
    if len(frames)!=16 or any(f.stat().st_size<3000 for f in frames):
        raise RuntimeError("Missing actual output PNG captures")
    for name in ("miner_motion_"+variant+".png",
                 "miner_motion_"+variant+"_native43.png"):
        if (folder/name).stat().st_size < 1000:
            raise RuntimeError("Missing APNG/native43 render "+name)
    seam=[o for o in rig.objects if o.name.startswith("FX ONLY |") and "light leak" in o.name]
    if len(seam)!=2:
        raise RuntimeError("Expected exactly two light leaks")
    steam=[o for o in rig.objects if o.name.startswith("FX ONLY | steam")]
    if len(steam)!=9:
        raise RuntimeError("Expected exactly nine source-anchored steam wisps")
    result={
        "variant":variant,"verification":"PASS","reopen_blender":bpy.app.version_string,
        "camera":camera_record(scene),
        "rendered_frames":len(frames),
        "foundation_stationary":True,"rig_loop_closed":True,
        "live_original_art_changed":False,"owner_approved":False,
        "steam_wisps":len(steam),"seam_emitters":len(seam),
        "saved_blend_sha256":sha(master),
    }
    (folder/("verify_motion_"+variant+".json")).write_text(json.dumps(result,indent=2)+"\n")
    print("NATIVE_EMERGENCY_MINER_ANIMATION_REOPEN_PASS "+json.dumps(result,separators=(",",":")),flush=True)


if __name__=="__main__":
    ap=argparse.ArgumentParser()
    ap.add_argument("--out",type=Path,required=True)
    ap.add_argument("--variant",choices=["A","B"],required=True)
    args=ap.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else sys.argv[1:])
    main(args.out.resolve(),args.variant)
