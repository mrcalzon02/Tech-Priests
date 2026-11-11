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
    if scene.get("emergency_miner_v24_applied") is not True:
        raise RuntimeError("Owner V24 lower-middle-chassis gap was not applied")
    record=json.loads(scene.get("owner_v24_middle_drop_report","{}"))
    if abs(float(record.get("gap_increase",-100))-.012)>1e-5:
        raise RuntimeError("Real console gap did not widen by exactly 0.012 units")
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

    # V25: actual source vents + one and only ONE moving photocopier
    # scanner. We intentionally refuse the old three independently
    # flashing console-gap bulbs and never allow light on console steel.
    vent_lights=[o for o in rig.objects if o.name.startswith(
        "FX ONLY | vent aperture laser glow")]
    vent_hot=[o for o in rig.objects if o.name.startswith(
        "FX ONLY | moving vent scan hotspot")]
    if len(vent_lights)!=3 or len(vent_hot)!=3 or (
       {o.get("vent_source_index") for o in vent_lights}!={0,1,2}) or (
       {o.get("vent_source_index") for o in vent_hot}!={0,1,2}):
        raise RuntimeError("Three actual vent openings must share one moving laser scan")
    if any("movable light leak" in o.name or "front chassis light leak" in o.name
           or "console-middle-chassis joint leakage" in o.name
           for o in rig.objects):
        raise RuntimeError("Old three gap strobes or wandering console-panel lights remain")
    beam=bpy.data.objects.get("FX ONLY | one continuous red photocopier scanner")
    spill=bpy.data.objects.get("FX ONLY | one traveling red middle chassis spill")
    if beam is None or spill is None:
        raise RuntimeError("Missing the SINGLE moving gap scanner and SINGLE red spill")
    if beam.get("scan_type")!="SINGLE_CONTINUOUS_TRAVERSE" or (
       beam.get("has_independent_strobe_segments") is not False) or (
       beam.get("not_on_console_surface") is not True) or (
       spill.get("v25_light_role")!="ONE_TRAVELING_DOWNWARD_RED_SPILL") or (
       spill.get("no_visible_surface_mesh") is not True) or spill.type!="LIGHT":
        raise RuntimeError("Photocopier scanner replaced with fake lamp clusters or surface decal")
    if len([o for o in rig.objects if o.name.startswith("FX ONLY | one continuous red")])!=1:
        raise RuntimeError("More than one moving photocopier strip exists")
    if len([o for o in rig.objects if "middle chassis red spill" in o.name])!=0:
        raise RuntimeError("Old three stationary red spill lamps reappeared")
    lower=float(beam.get("chassis_upper_z",-1))
    scan_z=float(beam.get("gap_world_z",-1))
    higher=float(beam.get("console_lower_z",-1))
    if not lower<scan_z<higher:
        raise RuntimeError("Moving photocopier line not in the actual open chassis gap")
    point_lights=[bpy.data.objects.get("FX ONLY | vent inside point light %d"%i)
                  for i in range(3)]
    if any(o is None or o.type!="LIGHT" for o in point_lights):
        raise RuntimeError("Missing original source vent light")
    if any(o.get("scan_group")!="ONE_SHARED_PHOTOCOPIER_X_PHASE"
           or abs(float(o.get("v25_energy_cap",-1))-3.4)>1e-6 for o in point_lights):
        raise RuntimeError("Source vent light does not share the ONE scan or brightness cap")
    expected=(1.0,.028,.008)
    def check_red(rgb,label):
        if any(abs(float(rgb[i])-expected[i])>1e-5 for i in range(3)):
            raise RuntimeError("Non-red laser effect: "+label)
    for obj in point_lights+[spill]:
        check_red(obj.data.color,obj.name)
    if abs(float(spill.get("max_energy",-1))-2.2)>1e-6:
        raise RuntimeError("Single red chassis spill energy cap invalid")
    if any(o.get("scan_group")!="ONE_SHARED_PHOTOCOPIER_X_PHASE"
           or o.get("below_original_roof") is not True for o in vent_hot):
        raise RuntimeError("Bright vent hotspots escaped the original vent holes")
    def mix_alpha(obj):
        nodes=obj.data.materials[0].node_tree.nodes
        mix=next((n for n in nodes if n.type=="MIX_SHADER"),None)
        emission=next((n for n in nodes if n.type=="EMISSION"),None)
        if mix is None or emission is None:
            raise RuntimeError("Laser effect lost its keyed red emissive shader")
        if abs(float(emission.inputs["Strength"].default_value)-5.6)>1e-4:
            raise RuntimeError("Weak/mismatched photocopier emission strength")
        check_red(emission.inputs["Color"].default_value,obj.name)
        return float(mix.inputs[0].default_value)

    # Verify actual timeline movement at every authored pose, including
    # exact loop closure. The bright scanner must move strictly in one
    # direction whenever it is emitting and all vent hotspots follow
    # precisely the SAME normalized x-translation.
    keys=list(range(1,97,6))+[97]
    scene.frame_set(1)
    bpy.context.view_layer.update()
    start_gap=beam.location.x
    start_vents=[o.location.x for o in sorted(vent_hot,key=lambda o:o.name)]
    gap_span=float(beam.get("v25_scan_span",0))
    if not .16<=gap_span<=.6:
        raise RuntimeError("Invalid single scanner horizontal travel span")
    vent_span=[float(o.get("scan_span",0)) for o in
               sorted(vent_hot,key=lambda o:o.name)]
    if any(v<=.015 for v in vent_span):
        raise RuntimeError("Vent hotspot cannot traverse the actual source opening")
    peak_positions=[]
    bright_samples=0
    strobe_evidence=[]
    for frame in keys:
        scene.frame_set(frame)
        bpy.context.view_layer.update()
        xnorm=(beam.location.x-start_gap)/gap_span
        b=mix_alpha(beam)
        sp=float(spill.data.energy)
        if not (-.012<=xnorm<=1.012) or not (0<=b<=.961 and 0<=sp<=2.201):
            raise RuntimeError("Scanner position or intensity outside true chassis gap")
        if abs(b/.96-sp/2.2)>.014:
            raise RuntimeError("Red chassis spill did not follow the one moving laser")
        if b>.12:
            peak_positions.append(beam.location.x)
            bright_samples+=1
        for idx,o in enumerate(sorted(vent_hot,key=lambda ob:ob.name)):
            vnorm=(o.location.x-start_vents[idx])/vent_span[idx]
            if abs(vnorm-xnorm)>.014:
                raise RuntimeError("Independent vent flash! Not aligned with continuous scan")
            va=mix_alpha(vent_lights[idx])
            hotspot=mix_alpha(o)
            light=float(point_lights[idx].data.energy)
            if not (.179<=va<=.901 and 0<=hotspot<=.981
                    and .339<=light<=3.401):
                raise RuntimeError("Bright source vent intensity outside calibrated limits")
            if abs(hotspot/.98-b/.96)>.015 or (
               abs((va-.18)/.70-b/.96)>.015) or (
               abs((light-.34)/3.0-b/.96)>.015):
                raise RuntimeError("Vent and single seam scanner are independently blinking")
            strobe_evidence.append([frame,idx,round(va,4),
                                    round(hotspot,4),round(light,4),
                                    round(vnorm,4)])
    if bright_samples<8 or any(b<=a for a,b in zip(peak_positions,peak_positions[1:])):
        raise RuntimeError("The laser failed continuous left-to-right photocopier travel")
    scene.frame_set(97)
    end_gap=beam.location.x
    scene.frame_set(1)
    if abs(start_gap-end_gap)>1e-6:
        raise RuntimeError("One moving photocopier scanner did not close its loop")
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
        "vent_moving_hotspots":len(vent_hot),
        "console_chassis_gap_emitters":1,
        "gap_strobe_sources":"ONE_CONTINUOUS_TRAVELING_SCAN_PHASE",
        "v25_brightness_limits":{"vent_alpha":.90,"joint_alpha":.96,
                                 "point_energy":3.40,"emission_strength":5.60,
                                 "middle_chassis_area_energy":2.20},
        "v24_gap_increase":record["gap_increase"],
        "red_spill_emitters":1,
        "laser_color_rgb":list(expected),
        "brightness_key_samples_checked":len(strobe_evidence),
        "brightness_key_samples":strobe_evidence,
        "scan_bright_key_count":bright_samples,
        "scanner_one_direction_monotone":True,
        "scanner_loop_closed":True,
        "no_independent_gap_bulbs":True,
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
