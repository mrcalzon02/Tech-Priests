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
    if scene.get("emergency_miner_v22_applied") is not True:
        raise RuntimeError("Owner V22 console/capacitor geometry was not applied")
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
    vent_lights=[o for o in rig.objects if o.name.startswith("FX ONLY | vent aperture laser glow")]
    if len(vent_lights)!=3 or {x.get("vent_source_index") for x in vent_lights}!={0,1,2}:
        raise RuntimeError("Laser emission must originate in each of the exactly 3 source vent openings")
    if any("movable light leak" in ob.name or "front chassis light leak" in ob.name
           or "upper service seam" in ob.name for ob in rig.objects):
        raise RuntimeError("Surface panning laser has reappeared")
    gap=[o for o in rig.objects
         if o.name.startswith("FX ONLY | console-middle-chassis joint leakage")]
    if len(gap)!=3 or any(o.get("emission_origin")!="PHYSICAL_GAP_BETWEEN_CONSOLE_AND_MIDDLE_CHASSIS"
                          or o.get("no_surface_panning") is not True for o in gap):
        raise RuntimeError("Exactly three physically anchored console/chassis gap segments required")
    for idx,emitter in enumerate(sorted(gap,key=lambda o:o.name)):
        if emitter.get("shared_strobe_source")!="VENT_LASER_PHASE_%d"%idx:
            raise RuntimeError("Gap emitter must reuse matching vent phase")
        lo=float(emitter.get("chassis_upper_z",-1))
        z=float(emitter.get("gap_world_z",-1))
        hi=float(emitter.get("console_lower_z",-1))
        if not lo < z < hi:
            raise RuntimeError("Light is not physically between chassis and console")
        if emitter.animation_data is not None and emitter.animation_data.action:
            raise RuntimeError("Stationary seam leak may not translate or pan")
    # V23 independent native readback of actual animated shader controls.
    # Vent and console-chassis joint must be the *same* scan pattern at
    # deliberately capped output. No moving/duplicate surface emitter.
    point_lights=[bpy.data.objects.get("FX ONLY | vent inside point light %d"%i)
                  for i in range(3)]
    if any(ob is None or ob.type!="LIGHT" for ob in point_lights):
        raise RuntimeError("Expected three recessed existing-vent point lights")
    if any(ob.get("v23_energy_cap")!=.70 for ob in point_lights):
        raise RuntimeError("Vent point light budget changed after save")
    if any(o.get("max_alpha")!=.60 or
           o.get("v23_effect_profile")!="BOUND_TO_EXISTING_VENT_DARK_WELL"
           for o in vent_lights):
        raise RuntimeError("V23 restrained vent glow profile not restored")
    if any(o.get("max_alpha")!=.22 or
           o.get("v23_effect_profile")!="NARROW_RECESSED_JOINT_STROBE"
           for o in gap):
        raise RuntimeError("V23 restrained console-chassis light profile not restored")
    def mix_alpha(obj):
        shader=obj.data.materials[0].node_tree.nodes
        mix=next((node for node in shader if node.type=="MIX_SHADER"),None)
        emit=next((node for node in shader if node.type=="EMISSION"),None)
        if mix is None or emit is None:
            raise RuntimeError("Recessed laser effect lost its keyed emissive shader")
        strength=float(emit.inputs["Strength"].default_value)
        if not (1.95 <= strength <= 2.11):
            raise RuntimeError("V23 emission shader intensity escaped bounds: "+str(strength))
        return float(mix.inputs[0].default_value)
    strobe_evidence=[]
    for f in list(range(1,97,6))+[97]:
        scene.frame_set(f)
        bpy.context.view_layer.update()
        for i in range(3):
            vi=mix_alpha(bpy.data.objects["FX ONLY | vent aperture laser glow %d"%i])
            gi=mix_alpha(bpy.data.objects["FX ONLY | console-middle-chassis joint leakage %d"%i])
            power=float(point_lights[i].data.energy)
            if not (0<=vi<=.601 and 0<=gi<=.221 and 0<=power<=.701):
                raise RuntimeError("V23 vent/joint brightness budget exceeded")
            if abs(vi/.60-gi/.22)>.011:
                raise RuntimeError("Console-joint and vent strobe patterns drifted apart")
            if abs(vi/.60-power/.70)>.011:
                raise RuntimeError("Light power does not share vent strobe envelope")
            strobe_evidence.append([f,i,round(vi,4),round(gi,4),round(power,4)])
    from mathutils import Vector
    eye=Vector((0,-0.70710678,0.70710678))
    scene.frame_set(1)
    cap_alignment=[]
    for idx in range(3):
        ob=bpy.data.objects.get("Capacitor %d horizontal supported shell"%idx)
        if ob is None:
            raise RuntimeError("Missing original source capacitor %d"%idx)
        axis=(ob.matrix_world.to_3x3() @ Vector((0,0,1))).normalized()
        dot=axis.dot(eye)
        if dot<.94:
            raise RuntimeError("Capacitor %d not pointed toward camera, dot=%s"%(idx,dot))
        cap_alignment.append(round(dot,4))
    steam=[o for o in rig.objects if o.name.startswith("FX ONLY | steam")]
    if len(steam)!=9:
        raise RuntimeError("Expected exactly nine source-anchored steam wisps")
    result={
        "variant":variant,"verification":"PASS","reopen_blender":bpy.app.version_string,
        "camera":camera_record(scene),
        "rendered_frames":len(frames),
        "foundation_stationary":True,"rig_loop_closed":True,
        "live_original_art_changed":False,"owner_approved":False,
        "steam_wisps":len(steam),"vent_aperture_emitters":len(vent_lights),
        "console_chassis_gap_emitters":len(gap),
        "gap_strobe_sources":"THREE_VENT_PHASES",
        "v23_brightness_limits":{"vent_alpha":.60,"joint_alpha":.22,
                                 "point_energy":.70,"emission_strength":2.10},
        "brightness_key_samples_checked":len(strobe_evidence),
        "brightness_key_samples":strobe_evidence,
        "surface_panning_lights":0,"capacitor_camera_alignments":cap_alignment,
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
