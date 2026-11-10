#!/usr/bin/env python3
"""Fresh Blender/GLB/animation readback for an FMPL Super Greeble derivative."""
from __future__ import annotations
import argparse
import array
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import sys
import bpy

HERE=Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0,str(HERE))
from camera_profile import audit_scene

def sha(path):
    h=hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""):
            h.update(chunk)
    return h.hexdigest()

def model_hash(objects):
    spec=importlib.util.spec_from_file_location("fmpl_process_mesh_hash",HERE/"refine_process.py")
    helper=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    return helper.hash_original_meshes(objects)

def inspect_alpha(filepath,expected):
    if sha(filepath)!=expected:
        raise RuntimeError("Proof image changed after source was saved")
    image=bpy.data.images.load(str(Path(filepath).resolve()),check_existing=False)
    try:
        if image.size[0]!=512 or image.size[1]!=512 or image.channels!=4:
            raise RuntimeError("Production proof is not 512px RGBA")
        pixels=array.array("f",[0.]*(512*512*4))
        image.pixels.foreach_get(pixels)
        lows=min(pixels[3::4])
        highs=max(pixels[3::4])
        if lows>.02 or highs<.95:
            raise RuntimeError("Production proof lacks real object/transparent alpha")
        return {"alpha_min":round(lows,4),"alpha_max":round(highs,4)}
    finally:
        bpy.data.images.remove(image)

def main():
    p=argparse.ArgumentParser()
    for key in ("source","blend","glb","build-receipt","idle-preview","working-preview","out"):
        p.add_argument("--"+key,required=True)
    a=p.parse_args(sys.argv[sys.argv.index("--")+1:])
    receipt=json.loads(Path(a.build_receipt).read_text(encoding="utf-8-sig"))
    if receipt.get("schema")!="fmpl.super-greeble.v1":
        raise RuntimeError("Unknown Super Greeble source receipt")
    if sha(a.source)!=receipt["source_sha256"] or sha(a.blend)!=receipt["derived_blend_sha256"]:
        raise RuntimeError("Blender baseline or derivative changed")
    if sha(a.glb)!=receipt["derived_glb_sha256"]:
        raise RuntimeError("Exported GLB differs from saved source receipt")
    bpy.ops.wm.open_mainfile(filepath=str(Path(a.blend).resolve()))
    scene=bpy.context.scene
    if receipt.get("camera_policy")!="fmpl.factorio45.v1" or receipt.get("camera_cleanup",{}).get("persistent_camera_count")!=1:
        raise RuntimeError("Super Greeble model lacks FMPL camera sanitation evidence")
    audit_scene(scene,bpy,512)
    original=[x for x in scene.objects if x.type=="MESH" and x.name.startswith("MH7_")]
    process=[x for x in scene.objects if x.type=="MESH" and x.name.startswith("FMPL_PROCESS |")]
    detail=[x for x in scene.objects if x.type=="MESH" and x.name.startswith("FMPL_PROCESS |") and
          (x.users_collection and any("SUPER GREEBLE" in co.name for co in x.users_collection))]
    if len(original)!=50 or len(process)!=136+receipt["super_greeble_meshes_added"]:
        raise RuntimeError("Super Greeble modified underlying source counts")
    # New objects also share the FMPL_PROCESS name scheme. Their collection
    # is the unambiguous identity; split the old process by that ownership.
    col=bpy.data.collections.get("FMPL | SUPER GREEBLE V01")
    if col is None:
        raise RuntimeError("Source lacks a separate, reversible detail collection")
    details=[o for o in col.objects if o.type=="MESH"]
    saved_process=[o for o in process if o not in details]
    if len(details)!=receipt["super_greeble_meshes_added"] or len(saved_process)!=136:
        raise RuntimeError("Detail collection/source process list has changed")
    if model_hash(original)!=receipt["source_original_mesh_digest"]:
        raise RuntimeError("Original immutable 50 machine meshes changed")
    if model_hash(saved_process)!=receipt["source_process_mesh_digest"]:
        raise RuntimeError("Existing 136 verified process meshes changed")
    cameras=[o for o in scene.objects if o.type=="CAMERA"]
    if len(cameras)!=1 or cameras[0]!=scene.camera:
        raise RuntimeError("Unexpected extra camera or missing Factorio export camera")
    target=(0.,-6.,7.65)
    if max(abs(scene.camera.location[i]-target[i]) for i in range(3))>.001 or abs(scene.camera.data.ortho_scale-5.8)>.001:
        raise RuntimeError("45° boiler-fixed grid camera was changed by super greebles")
    for role,side in (("raw-water-in",-1),("purified-water-out",1)):
        slots=[o for o in saved_process if o.name.endswith(role+" / reusable machine collar")]
        throats=[o for o in saved_process if o.name.endswith(role+" / reusable machine throat")]
        bolts=[o for o in saved_process if o.name.startswith("FMPL_PROCESS | "+role+" / actual flange bolt ")]
        if len(slots)!=1 or len(throats)!=1 or len(bolts)!=8:
            raise RuntimeError("Source canonical flange/throat/bolt assembly was modified: "+role)
        if not slots[0].get("nominal_open_bore_diameter_tiles") == .49:
            raise RuntimeError("Wrong canonical 0.49-tile open bore")
    for field in ("driver","pump","filter 1","filter 2","sample station 1","sample station 2",
                  "pressure dial","conduit","radiator","drain","glass lid"):
        target=["working pressure dial" if field=="pressure dial" else field]
        names=[o.name.lower() for o in details]
        if field=="driver":
            ok=any("pump rotor exposed spindle" in name for name in names)
        elif field=="glass lid":
            ok=any("glass lid service bolt" in name for name in names)
        else:
            ok=any(term.lower() in name for term in target for name in names)
        if not ok:
            raise RuntimeError("No physicalized Super Greeble component for "+field)
    rotors=[x for x in col.objects if "powered inlet pump drive rotor" in x.name]
    if len(rotors)!=1 or rotors[0].animation_data is None:
        raise RuntimeError("No actual keyed pump rotor")
    seen=[]
    for frame in (1,25,49):
        scene.frame_set(frame)
        seen.append(round(float(rotors[0].rotation_euler.y),3))
    if abs(seen[1]-seen[0])<1.0 or abs(seen[2]-seen[1])<1.0:
        raise RuntimeError("Pump rotor does not move across the working timeline")
    needles=[o for o in details if "working gauge needle" in o.name]
    if len(needles)!=2 or any(o.animation_data is None for o in needles):
        raise RuntimeError("Both service pressure needles must be keyed")
    bubbles=[o for o in details if "treatment chamber aeration bubble " in o.name]
    if len(bubbles)!=12 or any(o.animation_data is None for o in bubbles):
        raise RuntimeError("Glass chamber aeration feedback is not actually animated")
    scene.frame_set(1)
    before=[b.location.z for b in bubbles]
    scene.frame_set(25)
    after=[b.location.z for b in bubbles]
    if max(abs(x-y) for x,y in zip(before,after))<.07:
        raise RuntimeError("Working fluid animation not visible")
    # Reopen the actual saved Blender derivative and independently cast rays
    # through each exterior pipe bore; an AABB alone cannot certify a passage.
    spec=importlib.util.spec_from_file_location(
        "fmpl_bore_verifier",HERE/"pipe_bore_clearance.py")
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    bore_native=module.verify_bores(scene,original,saved_process,details)
    if not bore_native["passed"] or bore_native["probed_rays"]<45:
        raise RuntimeError("External side port openings have structural obstructions: "+
                           json.dumps(bore_native["hits"][:15]))
    clearance=receipt.get("port_bore_clearance",{})
    if (clearance.get("replaced_originals_hidden")!=8 or
        clearance.get("repaired_foundation_layers")!=2 or
        clearance.get("split_rail_segments")!=4 or
        clearance.get("redirected_supports")!=8):
        raise RuntimeError("Incomplete non-destructive side-port rail/shoe/base refit")
    hidden_names=clearance.get("hidden_original_object_names",[])
    if len(hidden_names)!=8:
        raise RuntimeError("Missing exact source-preservation/visibility receipts")
    for name in hidden_names:
        obj=bpy.data.objects.get(name)
        if obj is None or not obj.hide_render:
            raise RuntimeError("Obstructing original must be preserved but hidden: "+name)
    for role in ("raw-water-in","purified-water-out"):
        for part in ("reusable machine throat","reusable machine collar"):
            original_part=bpy.data.objects.get("FMPL_PROCESS | "+role+" / "+part)
            if original_part is None or original_part.hide_render:
                raise RuntimeError("Do not hide or shrink real canonical joint: "+role+" "+part)
    # Inspect the actual physical dimensions and shader graphs of BOTH front
    # tanks, not merely user-written metadata in a receipt.
    target_width=.426
    target_height=.712
    columns_by_role={}
    for index,role in ((1,"RAW"),(2,"CLEAN")):
        tank=[o for o in details if "sample station %d enlarged transparent vessel"%index in o.name]
        liquid=[o for o in details if "sample station %d enlarged visible liquid column"%index in o.name]
        if len(tank)!=1 or len(liquid)!=1:
            raise RuntimeError("Missing large separate modelled RAW/CLEAN glass tank")
        vessel=tank[0]
        if (vessel.get("fmpl_witness_tank_role")!=role or
            float(vessel.get("fmpl_witness_tank_outer_diameter_tiles",0))<target_width-.003 or
            float(vessel.get("fmpl_witness_tank_body_height_tiles",0))<target_height-.003 or
            vessel.dimensions.x<.422 or vessel.dimensions.z<.705):
            raise RuntimeError("Front witness canister is not physically enlarged "+role)
        if not liquid[0].data.materials:
            raise RuntimeError("No real liquid material on "+role+" witness tank")
        columns_by_role[role]=liquid[0].data.materials[0]
    raw_mat,clean_mat=columns_by_role["RAW"],columns_by_role["CLEAN"]
    if (raw_mat.name!="FMPL | purifier raw-water olive-amber V11" or
        clean_mat.name!="FMPL | purifier clean-water luminous cyan V11"):
        raise RuntimeError("Raw vs clean water PBR colorway is not correctly applied")
    if any(mat.get("fmpl_not_canonical_fx_asset") is not True for mat in (raw_mat,clean_mat)):
        raise RuntimeError("Custom tank colorways must be derivatives, never mutated canonical FX assets")
    def rgb_from_ramp(mat):
        ramp=mat.node_tree.nodes.get("FMPL | Broken Albedo")
        if ramp is None:
            raise RuntimeError("Missing actual FMPL procedural color-ramp for "+mat.name)
        return list(ramp.color_ramp.elements[1].color)[:3]
    raw_rgb,clean_rgb=rgb_from_ramp(raw_mat),rgb_from_ramp(clean_mat)
    if (raw_rgb[0]<raw_rgb[2]*4 or raw_rgb[1]<raw_rgb[2]*2 or
        clean_rgb[2]<clean_rgb[0]*6 or clean_rgb[1]<clean_rgb[0]*4):
        raise RuntimeError("Physically assigned shader colors insufficiently warm/cool")
    # V12: the V11 bubbles and foam were still present but completely buried
    # behind enlarged tinted water. Require actual raised near-window bubbles,
    # readable edge froth, and visibly transmissive physical fluid materials.
    bubbly=[o for o in details if "sample station " in o.name and "liquid bubble" in o.name]
    froth=[o for o in details if "sample station " in o.name and "waterline froth bead" in o.name]
    if len(bubbly)!=24 or len(froth)!=24 or any(o.animation_data is None for o in bubbly+froth):
        raise RuntimeError("Missing 24 keyed near-glass bubbles or 24 keyed surface foam beads")
    if any(o.get("fmpl_witness_visibility_repair") is None for o in bubbly):
        raise RuntimeError("Actual V12 near-observation-surface bubble build not present")
    if receipt.get("fluid_fx",{}).get("waterline_froth_beads")!=24:
        raise RuntimeError("The real Blender foam bead count was not recorded correctly")
    raw_surface=columns_by_role["RAW"].node_tree.nodes.get("FMPL | Surface")
    clean_surface=columns_by_role["CLEAN"].node_tree.nodes.get("FMPL | Surface")
    if (raw_surface is None or clean_surface is None or
        raw_surface.inputs["Transmission Weight"].default_value<.60 or
        clean_surface.inputs["Transmission Weight"].default_value<.75):
        raise RuntimeError("Tinted water is too opaque to reveal visible interior bubbling")
    scene.frame_set(1)
    bubble_start=[o.location.z for o in bubbly]
    froth_start=[o.location.z for o in froth]
    scene.frame_set(25)
    bubble_active=[o.location.z for o in bubbly]
    froth_active=[o.location.z for o in froth]
    if max(abs(a-b) for a,b in zip(bubble_start,bubble_active))<.085:
        raise RuntimeError("Visible witness bubbles still do not actually rise")
    if max(abs(a-b) for a,b in zip(froth_start,froth_active))<.008:
        raise RuntimeError("Waterline froth lacks physical motion")
    scene.frame_set(97)
    for o,z in zip(bubbly,bubble_start):
        if abs(o.location.z-z)>.0001:
            raise RuntimeError("Physical bubble rise did not loop at frame 97")
    for o,z in zip(froth,froth_start):
        if abs(o.location.z-z)>.0001:
            raise RuntimeError("Physical foam bead motion did not loop at frame 97")
    # FMPL physical effects: inspect real native meshes and animation data,
    # not merely render filenames or decorative materials.
    vessels=[o for o in details if "enlarged transparent vessel" in o.name]
    columns=[o for o in details if "enlarged visible liquid column" in o.name]
    surfaces=[o for o in details if "moving liquid meniscus" in o.name]
    foam_crests=[o for o in details if "sample station " in o.name and "animated waterline foam crest" in o.name]
    if len(foam_crests)!=2 or any(o.animation_data is None for o in foam_crests):
        raise RuntimeError("Two real, physically keyed front-waterline foam crest meshes required")
    liquid_bubbles=[o for o in details if "sample station " in o.name and "liquid bubble" in o.name]
    flow_tracers=[o for o in details if "flow tracer" in o.name]
    glass_flow=[o for o in details if "transparent tube" in o.name and "canister" in o.name]
    vapor=[o for o in details if "relief nozzle keyed condensed steam" in o.name]
    soft_veils=[o for o in details if "steam veil layered feather" in o.name]
    legacy_cones=[o for o in saved_process if o.name.startswith("FMPL_PROCESS | service steam plume ")]
    if len(legacy_cones)!=2 or any(not cone.hide_render for cone in legacy_cones):
        raise RuntimeError("Two hard-edged legacy cone steam surfaces remain visible")
    # Historical vent was a *solid* cylinder, not an open nozzle; preserve it,
    # but require an actually hollow, camera-visible metal throat on the derivative.
    solid_caps=[o for o in saved_process
                if o.name=="FMPL_PROCESS | vent nozzle anchored through pressure pipe"]
    if len(solid_caps)!=1 or not solid_caps[0].hide_render:
        raise RuntimeError("Original solid vent cap was not hidden/replaced")
    nozzle_throats=[o for o in details
                    if "relief vent emitter / open steel throat" in o.name]
    nozzle_lips=[o for o in details
                 if "relief vent emitter / visible open mouth retaining lip" in o.name]
    if len(nozzle_throats)!=1 or len(nozzle_lips)!=1:
        raise RuntimeError("Missing actually modeled hollow vent nozzle and metal lip")
    throat=nozzle_throats[0]
    if (len(throat.data.vertices)<128 or
        abs(float(throat.get("fmpl_nozzle_bore_diameter_tiles",0))-.15576)>.001 or
        abs(float(throat.get("fmpl_nozzle_lip_plane_z",0))-2.913)>.002):
        raise RuntimeError("New vent throat has no dimension-verified open bore")
    nozzle_spec=receipt.get("vent_nozzle",{})
    if (nozzle_spec.get("visible_open_throat") is not True or
        nozzle_spec.get("solid_source_caps_hidden")!=1 or
        nozzle_spec.get("rendered_mesh_parts")!=3):
        raise RuntimeError("Nozzle visual/physical replacement receipt missing")

    if any(abs(float(v.location.x)-.94)>.15 or abs(float(v.location.y)-.60)>.15 or
           not (2.80<float(v.location.z)<3.30) for v in vapor):
        raise RuntimeError("Steam does not emerge near the actual vent nozzle")
    # Deliberate sideways offsets prevent the vapour from rebuilding a cone.
    scene.frame_set(1)
    lateral_span=max(o.location.x for o in vapor+soft_veils)-min(o.location.x for o in vapor+soft_veils)
    if lateral_span<.100:
        raise RuntimeError("Steam lobe arrangement is too axisymmetric / cone-like")
    if len(soft_veils)!=8 or any(v.animation_data is None for v in soft_veils):
        raise RuntimeError("Layered feather steam requires eight real keyed Blender meshes")
    if any(not ob.data.vertices or not ob.data.polygons for ob in vapor+soft_veils):
        raise RuntimeError("New steam components must contain actual editable mesh geometry")
    softmat=bpy.data.materials.get("FMPL | relief steam irregular feathered wisps v05")
    if softmat is None or not softmat.use_nodes:
        raise RuntimeError("Soft surface steam material was not saved to native Blender")
    for name in ("FMPL STEAM | actual sphere radial distance",
                 "FMPL STEAM | multi-surface dither breakup",
                 "FMPL STEAM | steep smooth radial feather",
                 "FMPL STEAM | radial-dither alpha mix",
                 "FMPL STEAM | transparent exterior",
                 "FMPL STEAM | true variable density volume",
                 "FMPL STEAM | noise-dithered radial density",
                 "FMPL STEAM | bounded core lift linked to density"):
        if softmat.node_tree.nodes.get(name) is None:
            raise RuntimeError("No actual procedural steam feather/alpha node: "+name)
    alpha=softmat.node_tree.nodes.get("FMPL STEAM | steep smooth radial feather")
    density=softmat.node_tree.nodes.get("FMPL STEAM | noise-dithered radial density")
    if (alpha.inputs["To Max"].default_value!=0.0 or
        alpha.inputs["To Min"].default_value>.05 or
        density.inputs["To Max"].default_value!=0.0 or
        density.inputs["From Max"].default_value>.52 or
        not softmat.node_tree.nodes.get("FMPL STEAM | true variable density volume").inputs["Density"].is_linked):
        raise RuntimeError("True volumetric steam density has hard or hollow edges")
    lift=softmat.node_tree.nodes.get("FMPL STEAM | bounded core lift linked to density")
    volume_node=softmat.node_tree.nodes.get("FMPL STEAM | true variable density volume")
    if (not lift or lift.operation!="MULTIPLY" or
        abs(float(lift.inputs[1].default_value)-.112)>.001 or
        volume_node.inputs.get("Emission Strength") is None or
        not volume_node.inputs["Emission Strength"].is_linked):
        raise RuntimeError("Volume steam needs restrained density-linked light, not dark/invisible or edge-emitting shells")
    if (receipt.get("steam_fx",{}).get("emission_coupled_to_density") is not True or
        abs(float(receipt.get("steam_fx",{}).get("density_lift_multiplication",0))-.112)>.001):
        raise RuntimeError("Volume steam emission source not pinned to true density")
    if receipt.get("steam_fx",{}).get("true_volumetric_density") is not True:
        raise RuntimeError("Blender steam must be true radial-volume, not white surface rings")
    if receipt.get("steam_fx",{}).get("soft_surface_lobes")!=12 or receipt.get("steam_fx",{}).get("legacy_cones_hidden")!=2:
        raise RuntimeError("Steam source replacement/feather receipt inconsistent")
    scene.frame_set(1)
    steam_first=[(tuple(o.location),tuple(o.scale)) for o in vapor+soft_veils]
    scene.frame_set(25)
    if max(abs(o.location.z-before[0][2]) for o,before in zip(vapor+soft_veils,steam_first))<.005:
        raise RuntimeError("Soft steam layers are not spatially animated")
    scene.frame_set(97)
    if any(max(abs(x-y) for x,y in zip(o.location, before[0]))>1e-5 or
           max(abs(x-y) for x,y in zip(o.scale, before[1]))>1e-5
           for o,before in zip(vapor+soft_veils,steam_first)):
        raise RuntimeError("Steam surface loop does not close precisely at frame 97")
    if len(vessels)!=2 or len(columns)!=2 or len(surfaces)!=2:
        raise RuntimeError("Forward purifier inlet/outlet fluid canisters missing")
    if any(o.dimensions.x < .33 or o.dimensions.z < .60 for o in vessels):
        raise RuntimeError("Physical front canisters not enlarged to readable scale")
    if len(liquid_bubbles)!=24 or len(flow_tracers)!=8 or len(glass_flow)!=4 or len(vapor)!=4:
        raise RuntimeError("Real water bubble, glass flow or relief vapor meshes missing")
    if any(o.animation_data is None for o in liquid_bubbles+flow_tracers+vapor):
        raise RuntimeError("Fluid bubble, port flow or steam objects are not actually keyed")
    for o in surfaces:
        keys=o.data.shape_keys
        if not keys or not keys.animation_data or not {"Inlet surge","Return wash"}.issubset(keys.key_blocks.keys()):
            raise RuntimeError("Missing Blender-native animated fluid surface shape keys")
    scene.frame_set(1)
    first_crest=[o.location.z for o in foam_crests]
    scene.frame_set(25)
    second_crest=[o.location.z for o in foam_crests]
    if any(abs(a-b)<.045 for a,b in zip(first_crest,second_crest)):
        raise RuntimeError("Waterline foam is keyed but has insufficient physical slosh travel")
    surface=surfaces[0].data.shape_keys.key_blocks["Inlet surge"]
    scene.frame_set(1)
    first_level=surface.value
    original_bubble=liquid_bubbles[0].location.z
    first_vapor=vapor[0].scale.z
    scene.frame_set(25)
    if abs(surface.value-first_level)<.20:
        raise RuntimeError("Liquid meniscus not physically sloshing in the saved Blender")
    if abs(liquid_bubbles[0].location.z-original_bubble)<.012:
        raise RuntimeError("Visible liquid bubbles have no measurable rise")
    if abs(vapor[0].scale.z-first_vapor)<.04:
        raise RuntimeError("Steam plume is motionless despite real keyed geometry")
    scene.frame_set(97)
    end_level=surface.value
    scene.frame_set(1)
    if abs(end_level-surface.value)>1e-5:
        raise RuntimeError("16-sample water animation has non-looping frame 97")
    if receipt.get("fluid_fx",{}).get("vessels")!=2 or receipt.get("steam_fx",{}).get("relief_steam_puffs")!=4:
        raise RuntimeError("Fluid/steam construction receipt does not match native scene")
    if receipt.get("fmpl_effects_native_blend_sha256"):
        for name in ("FMPL FX | water-murky","FMPL FX | water-clear",
                     "FMPL FX | glass-clear","FMPL FX | steam-clean"):
            material=bpy.data.materials.get(name)
            if material is None or not material.get("fmpl_effect_id"):
                raise RuntimeError("Unverified imported FMPL procedural FX material: "+name)
    material_names={m.name for o in details for m in o.data.materials if m}
    if not any(name.startswith("TP Library |") for name in material_names):
        raise RuntimeError("Super Greebles did not use real FMPL weathered PBR")
    packed=sum(bool(im.packed_file) for im in bpy.data.images if im.source=="FILE")
    if packed<25:
        raise RuntimeError("Existing industrial PBR maps lost from derived source")
    alpha_idle=inspect_alpha(a.idle_preview,receipt["idle_png_sha256"])
    alpha_work=inspect_alpha(a.working_preview,receipt["working_png_sha256"])
    if receipt["idle_png_sha256"]==receipt["working_png_sha256"]:
        raise RuntimeError("Idle/working proof images are identical")
    # All Blender object references become invalid after read_factory_settings.
    # Preserve just immutable scalar QA values before unloading the native scene.
    rendered_legacy_cones=sum(not ob.hide_render for ob in legacy_cones)
    rendered_legacy_solid_caps=sum(not ob.hide_render for ob in solid_caps)
    verified_throat_bore_diameter=float(throat.get("fmpl_nozzle_bore_diameter_tiles"))
    # Never dereference Blender material/RNA objects after read_factory_settings:
    # V12 initial verifier failed here despite a correct native Blender build.
    verified_raw_transmission=float(raw_surface.inputs["Transmission Weight"].default_value)
    verified_clean_transmission=float(clean_surface.inputs["Transmission Weight"].default_value)
    total_expected=(len([ob for ob in original if not ob.hide_render])+
                    len([ob for ob in saved_process if not ob.hide_render])+
                    len([ob for ob in details if not ob.hide_render]))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(Path(a.glb).resolve()))
    imported=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    if len(imported)<total_expected:
        raise RuntimeError("Exported GLB is missing mechanical process detail")
    if any("FMPL QA reference" in o.name for o in imported):
        raise RuntimeError("Calibration-only adjacent reference leaked into game model")
    report={
       "schema":"fmpl.super-greeble.verify.v1","passed":True,
       "model_source_sha256":receipt["source_sha256"],
       "editable_blend_sha256":sha(a.blend),"glb_sha256":sha(a.glb),
       "original_meshes_preserved":len(original),
       "previous_process_meshes_preserved":len(saved_process),
       "new_mechanical_detail_meshes":len(details),
       "glb_meshes_reimported":len(imported),
       "source_camera_preserved":True,
       "source_pipe_annuli_preserved":True,
       "side_pipe_bores_verified_clear":bore_native["passed"],
       "side_pipe_probed_rays":bore_native["probed_rays"],
       "side_pipe_bore_structural_hits":len(bore_native["hits"]),
       "side_ports_original_members_hidden":len(hidden_names),
       "front_tanks_enlarged":2,
       "front_tank_outer_diameter_tiles":target_width,
       "front_tank_height_tiles":target_height,
       "front_raw_amber_rgb":raw_rgb,
       "front_clean_cyan_rgb":clean_rgb,
       "front_colorway_contrast_verified":True,
       "visible_rising_bubble_meshes":len(bubbly),
       "visible_waterline_froth_bead_meshes":len(froth),
       "v12_raw_water_transmission":round(verified_raw_transmission,3),
       "v12_clean_water_transmission":round(verified_clean_transmission,3),
       "v12_bubbles_and_foam_motion_looped":True,
       "moving_pump_rotor_samples":seen,
       "gauge_needles_keyed":len(needles),
       "process_bubbles_keyed":len(bubbles),
       "front_fluid_canisters":len(vessels),
       "water_meniscus_shape_keys":len(surfaces),
       "animated_front_foam_crests":len(foam_crests),
       "forward_liquid_bubbles":len(liquid_bubbles),
       "moving_glass_flow_tracers":len(flow_tracers),
       "connected_transparent_flow_lines":len(glass_flow),
       "keyed_relief_steam_puffs":len(vapor),
       "layered_soft_steam_veils":len(soft_veils),
       "legacy_cone_meshes_preserved":len(legacy_cones),
       "legacy_cone_meshes_rendered":rendered_legacy_cones,
       "vent_nozzle_hollow_throat_verified":True,
       "vent_nozzle_source_solid_caps_hidden":len(solid_caps),
       "vent_nozzle_original_solid_caps_rendered":rendered_legacy_solid_caps,
       "vent_open_bore_diameter_tiles":verified_throat_bore_diameter,

       "true_volumetric_steam_density_verified":True,
       "steam_wisp_lateral_spread_tiles":round(lateral_span,4),
       "steam_density_coupled_emission_verified":True,
       "procedural_steam_edge_feather_verified":True,
       "steam_animation_closed_loop_verified":True,
       "native_fmpl_effects_blend_sha256":receipt.get("fmpl_effects_native_blend_sha256"),
       "water_fx_loop_frames":17,
       "packed_pbr_images":packed,
       "proof_alpha_idle":alpha_idle,
       "proof_alpha_working":alpha_work,
       "private_donor_used":receipt["private_greebles_source"]["used_in_production"],
       "native_pipe_cell_verified":False,"game_integrated":False,
       "owner_visual_approval":False
    }
    Path(a.out).write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print("FMPL_SUPER_GREEBLE_REOPEN_PASS "+json.dumps({
       "original":len(original),"process":len(saved_process),
       "added":len(details),"glb":len(imported),"camera":1}),flush=True)
if __name__=="__main__":
    main()
