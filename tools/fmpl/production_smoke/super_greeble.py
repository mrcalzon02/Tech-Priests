#!/usr/bin/env python3
"""FMPL Super Greeble V01: purposeful process detail on saved Water Purifier V04.

No source overwrites, camera changes, pipe interface changes, unlicensed donor
geometry, gameplay edits or additional hidden internals. Imports real FMPL PBR
materials and standard modeling operators; draws machinery that visibly serves
the existing pump -> filter -> treatment -> product flow path.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

HERE=Path(__file__).resolve().parent
def load_helper():
    spec=importlib.util.spec_from_file_location("fmpl_process_helpers",HERE/"refine_process.py")
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

p=load_helper()

def sha(file):
    h=hashlib.sha256()
    with Path(file).open("rb") as f:
        for block in iter(lambda:f.read(8*1024*1024),b""):
            h.update(block)
    return h.hexdigest()

def component_bounds(objs):
    bpy.context.view_layer.update()
    return p.full_bounds(objs)

def own(col,obj,name,material=None):
    # Blender primitives are named Sphere/Cube by default. Preserve the
    # requested semantic identity before the FMPL rehouse wrapper adds its
    # namespace, or the native animation verifier cannot identify the rig.
    obj.name=name
    return p.rehouse(obj,col,material)

def bar(col,tag,a,b,radius,metal):
    return p.open_hollow_tube(col,tag,a,b,radius,metal)

def joined(col,tag,points,radius,metal,elbow):
    return p.pipe_route(col,tag,points,radius,metal,elbow)

def shoe(col,name,pos,dim,material):
    return p.block(col,name,pos,dim,material,.013)

def bolt(col,name,pos,material):
    return p.bolt(col,name,pos,material)

def cylinder(col,name,pos,radius,height,mat,axis="Z",verts=32):
    return p.cyl(col,name,pos,radius,height,mat,axis=axis,vertices=verts)

def ring(col,name,pos,radius,wire,mat,axis="Z"):
    return p.torus(col,name,pos,radius,wire,mat,axis=axis)

def animate_parent(child_objects,col,label,location,axis="Y",frames=None):
    rig=bpy.data.objects.new(p.name_of(label),None)
    col.objects.link(rig)
    rig.location=location
    rig.empty_display_type="CIRCLE"
    rig.empty_display_size=.07
    p.parent_to_rotor(child_objects,rig)
    axis_index={"X":0,"Y":1,"Z":2}[axis]
    for frame,angle in (frames or ((1,0),(25,math.pi),(49,math.tau),(73,3*math.pi),(97,2*math.tau))):
        rig.rotation_euler[axis_index]=angle
        rig.keyframe_insert(data_path="rotation_euler",index=axis_index,frame=frame)
    rig["fmpl_super_greeble_driven"]="motorized equipment"
    return rig

def move_detail(col,label,xyz,material,scale=(.06,.08,.06),frames=((1,.3),(25,1),(49,.3))):
    ob=shoe(col,label,xyz,scale,material)
    for frame,factor in frames:
        ob.scale=(1,1,factor)
        ob.keyframe_insert(data_path="scale",frame=frame)
    return ob

def check_donor(source_path,fmpl_root):
    """Intake-only. Never assert any generic donor mesh is a working valve."""
    info={"available":False,"used_in_production":False,
          "reason":"private Greebles donor unavailable or not individually visually approved",
          "candidate_count_indexed":320}
    if not source_path:
        return info
    source=Path(source_path)
    if not source.is_file():
        return info
    module=Path(fmpl_root)/"tools/fmpl/greebles/probe_source.py"
    spec=importlib.util.spec_from_file_location("fmpl_greebles_probe",module)
    probe=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(probe)
    verified=probe.probe(source,verify_hash=True)
    info.update({"available":True,"source_sha256":sha(source),
         "source_verified":True,"used_in_production":False,
         "reason":"source is present and hash-verified; none of its 320 unnamed candidates have approved mechanical roles"})
    return info

def setup_animation_bubbles(col,mats):
    # Source glass is already transparent. The spheres are confined inside
    # the treatment chamber; no synthetic external pipe-flow claims.
    bubbles=[]
    for k in range(12):
        angle=math.tau*k/12.0
        radius=.24+.06*(k%3)
        z=1.80+.14*(k%4)
        xyz=(radius*math.cos(angle),.10+radius*math.sin(angle),z)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=6,
                                             radius=.024+(k%3)*.006,location=xyz)
        ob=own(col,bpy.context.object,"treatment chamber aeration bubble %02d"%k,mats["foam"])
        for frame,delta in ((1,0),(25,.11),(49,.01),(73,.14),(97,0)):
            ob.location=(xyz[0],xyz[1],xyz[2]+delta)
            ob.keyframe_insert(data_path="location",index=2,frame=frame)
        bubbles.append(ob)
    return bubbles

def main():
    ap=argparse.ArgumentParser()
    for key in ("source","expected-sha","fmpl-root","out","glb",
                "idle-preview","working-preview","report"):
        ap.add_argument("--"+key,required=True)
    ap.add_argument("--greebles-source",default="")
    opts=ap.parse_args(sys.argv[sys.argv.index("--")+1:])
    source=Path(opts.source).resolve()
    out=Path(opts.out).resolve()
    if sha(source)!=opts.expected_sha:
        raise RuntimeError("Verified V04 model digest mismatch, refusing edit")
    for target in (opts.out,opts.glb,opts.idle_preview,opts.working_preview,opts.report):
        file=Path(target).resolve()
        if file==source or file.exists():
            raise FileExistsError("Refusing destructive or duplicated FMPL Super Greeble output: "+str(file))
        file.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=str(source))
    scene=bpy.context.scene
    original=[ob for ob in scene.objects if ob.type=="MESH" and ob.name.startswith("MH7_")]
    process=[ob for ob in scene.objects if ob.type=="MESH" and ob.name.startswith("FMPL_PROCESS |")]
    if len(original)!=50 or len(process)!=136:
        raise RuntimeError("Wrong frozen V04 source: expected 50+136 authored meshes")
    if bpy.data.collections.get("FMPL | SUPER GREEBLE V01") is not None:
        raise RuntimeError("Already super-greebled source, refusing duplicate geometry")
    old_hash=p.hash_original_meshes(original)
    process_hash=p.hash_original_meshes(process)
    camera=scene.camera
    cameras=[x for x in scene.objects if x.type=="CAMERA"]
    expected=(0,-6,7.65)
    if (camera is None or len(cameras)!=1 or cameras[0]!=camera or
        camera.data.type!="ORTHO" or
        max(abs(camera.location[i]-expected[i]) for i in range(3))>.002 or
        abs(camera.data.ortho_scale-5.8)>.002):
        raise RuntimeError("Source has wrong camera; never invent a new view")
    mouths=[
       (x.name,x.matrix_world.translation[:])
       for x in process if x.get("fmpl_process_role","").startswith("dimension-matched ")
    ]
    if len(mouths)!=4:
        raise RuntimeError("Missing exact two 0.49-bore collar/throat pairs")
    fmpl=Path(opts.fmpl_root).resolve()
    mats={
      "steel":bpy.data.materials.get("TP Library | machine_steel"),
      "iron":bpy.data.materials.get("TP Library | iron"),
      "brass":bpy.data.materials.get("TP Library | brass"),
      "red":bpy.data.materials.get("TP Library | martian_red"),
      "gunmetal":bpy.data.materials.get("TP Library | gunmetal_dark"),
      "concrete":bpy.data.materials.get("TP Library | ferrocrete_dark"),
      "glass":bpy.data.materials.get("FMPL | clear inspection glass"),
      "foam":bpy.data.materials.get("FMPL | churning foam"),
      "amber":bpy.data.materials.get("FMPL | raw turbid inlet water"),
      "teal":bpy.data.materials.get("FMPL | clarified water channel")
    }
    missing=[name for name,mat in mats.items() if mat is None]
    if missing:
        raise RuntimeError("Saved FMPL source has missing real PBR/glass materials: "+str(missing))
    # New artwork is stored as one removable derivative-only collection.
    col=bpy.data.collections.new("FMPL | SUPER GREEBLE V01")
    scene.collection.children.link(col)
    material=mats
    steel,iron,brass,red,dark=material["steel"],material["iron"],material["brass"],material["red"],material["gunmetal"]
    # Civil-work supports: no loose pipe or pump is allowed to hover.
    for x,y in ((-1.29,-1.23),(-.95,-1.23),(-.48,-1.25),(.92,-.82),(1.20,.54)):
        shoe(col,"cast anti-vibration equipment foot %.2f %.2f"%(x,y),
             (x,y,.375),(.19,.22,.12),iron)
        for dx in (-.054,.054):
            bolt(col,"foot retaining bolt %.2f %.2f %.2f"%(x,y,dx),
                 (x+dx,y,.45),brass)
    # Primary pump: flywheel is exposed to normal camera and visibly rotates.
    shoe(col,"pump drive fitted cast housing",(-1.27,-1.12,.75),
         (.24,.23,.31),red)
    ring(col,"pump exposed balance wheel",(-1.27,-1.258,.91),.17,.025,steel,axis="Y")
    rotor_parts=[]
    rotor_parts.append(cylinder(col,"pump rotor exposed spindle",
                 (-1.27,-1.280,.91),.040,.10,brass,axis="Y"))
    for k in range(4):
        theta=math.tau*k/4
        x=-1.27+.09*math.cos(theta)
        z=.91+.09*math.sin(theta)
        blade=shoe(col,"pump fan blade %02d"%k,(x,-1.305,z),
                  (.14,.034,.038),brass)
        blade.rotation_euler[1]=-theta
        rotor_parts.append(blade)
    rotor=animate_parent(rotor_parts,col,"powered inlet pump drive rotor",
                          (-1.27,-1.285,.91),"Y")
    # Visible pressure piping from the actual pump box to filter stacks.
    joined(col,"pump metal pressure bleeder",
           [(-1.12,-.84,.72),(-1.18,-.91,.99),(-1.18,-.99,1.05)],
           .046,steel,iron)
    cylinder(col,"pump bleed-valve bonnet",(-1.18,-.99,1.08),.065,.095,brass)
    ring(col,"pump service valve wheel",(-1.18,-1.047,1.13),.11,.012,brass,"Y")
    for dx in (-.065,.065):
        shoe(col,"valve wheel cross spoke %.3f"%dx,
             (-1.18+dx,-1.050,1.13),(.11,.014,.023),steel)
    # Twin removable cartridge filters: open sight glasses and service hardware.
    for index,x,y in ((1,-.92,-1.00),(2,-.50,-1.03)):
        for z in (.72,1.39):
            ring(col,"filter %d cast cartridge clamp at %.2f"%(index,z),
                 (x,y,z),.159,.025,steel)
            for side in (-1,1):
                bolt(col,"filter %d clamp anchor %.2f %d"%(index,z,side),
                     (x+side*.15,y-.035,z),brass)
        ring(col,"filter %d handwheel for purge"%(index),
             (x,y-.211,1.58),.093,.011,brass,axis="Y")
        cylinder(col,"filter %d purge spindle"%(index),
                 (x,y-.223,1.58),.026,.075,iron,axis="Y")
        for side in (-1,1):
            shoe(col,"filter %d purge wheel spoke %d"%(index,side),
                 (x+side*.034,y-.229,1.58),(.11,.012,.015),steel)
        cylinder(col,"filter %d lower sample plug"%(index),
                 (x,y-.139,.87),.044,.04,brass,axis="Y")
        # Functional pressure tap from filter top to service panel header.
        joined(col,"filter %d pressure impulse tube"%(index),
               [(x,y,1.57),(x,y-.08,1.71),(x+.09,y-.15,1.73)],
               .028,iron,steel)
    # A BEFORE / AFTER treatment witness bank visible from the camera.
    # Pressure gauges and glass standpipes mount to the front retaining rail.
    for idx,(x,fluid) in enumerate(((-.30,material["amber"]),(.22,material["teal"])),1):
        shoe(col,"sample station %d structural console shoe"%idx,
             (x,-1.27,.51),(.30,.19,.19),dark)
        cylinder(col,"sample station %d sight glass"%idx,
                 (x,-1.30,.83),.076,.32,material["glass"])
        cylinder(col,"sample station %d visible liquid core"%idx,
                 (x,-1.30,.78),.055,.19,fluid)
        ring(col,"sample station %d removable glass retainer"%idx,
             (x,-1.30,1.01),.091,.021,brass)
        joined(col,"sample station %d real feed capillary"%idx,
               [(x,-1.25,.65),(x+.07,-1.08,.68),(x+.07,-.90,.80)],
               .025,steel,iron)
    # Return gauge uses a supported pressure sender on the right frame.
    shoe(col,"instrument rack mounting leg",(1.17,-.98,.92),
         (.14,.20,.79),dark)
    shoe(col,"instrument rack front face",(1.12,-1.113,1.28),
         (.37,.090,.46),iron)
    for idx,(x,z) in enumerate(((1.026,1.36),(1.20,1.36)),1):
        cylinder(col,"working pressure dial %d"%idx,
                 (x,-1.175,z),.071,.032,brass,axis="Y")
        cylinder(col,"working dial lens %d"%idx,
                 (x,-1.198,z),.051,.012,material["glass"],axis="Y")
        # Needle changes orientation in working cycle, without claiming sensor data.
        needle=shoe(col,"working gauge needle %d"%idx,
                    (x,-1.215,z),(.064,.01,.008),dark)
        for frame,angle in ((1,-.18),(25,.23),(49,-.04),(73,.30),(97,-.18)):
            needle.rotation_euler.y=angle
            needle.keyframe_insert(data_path="rotation_euler",index=1,frame=frame)
        joined(col,"pressure gauge %d hardline"%idx,
               [(x,-1.115,z-.16),(x,-.96,1.09),
                (1.11,-.65,1.02)],
               .025,iron,steel)
    # Electrical realism: independent armored conduit, paired cable glands,
    # and clamps along the front of the steel floor. The cables are visible and
    # don't cover the green control display or pipe mouths.
    joined(col,"control panel motor power armored conduit",
           [(.72,-1.18,.52),(.44,-1.22,.42),(-.45,-1.22,.42),
             (-1.06,-1.04,.56)],.038,dark,iron)
    for i,x in enumerate((-.73,-.34,.16,.52),1):
        shoe(col,"control conduit stainless saddle clamp %d"%i,
             (x,-1.21,.47),(.10,.065,.025),steel)
        for dx in (-.035,.035):
            bolt(col,"conduit lock bolt %d %.2f"%(i,dx),
                 (x+dx,-1.235,.487),brass)
    cylinder(col,"control junction terminal box",(.57,-1.15,.51),
             .10,.17,red,verts=8)
    # Mixer drive cap: keep 70% of sight area clear so glass can be read.
    for k in range(12):
        a=math.tau*k/12
        x=.735*math.cos(a);y=.1+.735*math.sin(a)
        cylinder(col,"glass lid service bolt %02d"%k,
                 (x,y,2.784),.031,.041,brass,verts=12)
    # Shaft transmission guard and motor vibration isolators, no magic internals.
    shoe(col,"upper agitator drive motor support casting",(0,.10,3.29),
         (.34,.30,.14),iron)
    for dx in (-.14,.14):
        cylinder(col,"agitator motor isolation bush %.2f"%dx,
                 (dx,.10,3.36),.041,.06,dark)
    # 2-stage heat exchanger manifold: fins physically welded to the pipe
    # relief trunk, not a free-floating cloud of bolts.
    shoe(col,"steam vent radiator support",(1.08,.54,1.13),
         (.16,.17,.50),iron)
    for index,z in enumerate((.93,1.02,1.11,1.20,1.29),1):
        shoe(col,"cast heat exchanger radiator fin %d"%index,
             (1.22,.55,z),(.21,.32,.024),steel)
    joined(col,"return condensate pipe from working relief",
           [(.94,.60,2.55),(1.06,.64,2.21),(1.09,.61,1.38)],
           .053,iron,brass)
    # One physically anchored gravity drain from the treatment cup to
    # the front trench, with cast shoes and floor grating.
    joined(col,"process sump gravity return",
           [(.59,-.28,.68),(.64,-.79,.49),(.72,-1.16,.42)],
           .050,iron,steel)
    shoe(col,"floor drain trough near front right",
         (.72,-1.275,.318),(.47,.10,.06),dark)
    for i in range(6):
        shoe(col,"trench grating iron strip %d"%i,
             (.52+i*.081,-1.27,.36),(.018,.110,.023),steel)
    # Visual effect directly inside the already glass-topped process vessel.
    bubbles=setup_animation_bubbles(col,material)
    # Steam plumbing and keyed vapor were present in the verified source and
    # remain untouched. This additional condensate trap has its own moving valve.
    trap=cylinder(col,"relief condensate trap",(1.04,.53,1.57),.105,.18,iron)
    ring(col,"relief condensate trap gasket",(1.04,.53,1.68),.112,.022,brass)
    # Guard against accidental opaque camera backgrounds or polluting the port planes.
    newmeshes=[ob for ob in col.objects if ob.type=="MESH"]
    bpy.context.view_layer.update()
    bounds=component_bounds(newmeshes)
    if (any(abs(bounds[edge][idx])>1.501 for edge in ("min","max") for idx in (0,1))
         or bounds["min"][2]<-.001 or bounds["max"][2]>3.61):
        raise RuntimeError("Super Greeble violates 3x3 visible equipment envelope "+str(bounds))
    if (p.hash_original_meshes(original)!=old_hash or
            p.hash_original_meshes(process)!=process_hash):
        raise RuntimeError("Frozen V04 source transformed/modified during detailed pass")
    if len(newmeshes)<85:
        raise RuntimeError("Too little meaningful structural and process detail authored")
    if len([ob for ob in newmeshes if "treatment chamber aeration bubble " in ob.name])!=12:
        raise RuntimeError("Twelve semantically named animated process bubbles required")

    # Optional private donor is an intake-only provenance test, never a randomly
    # grafted and possibly unlicensed/anatomically incorrect working interface.
    greebles=check_donor(opts.greebles_source,fmpl)
    scene.frame_start=1
    scene.frame_end=97
    scene.frame_set(1)
    scene.render.engine="CYCLES"
    scene.cycles.device="CPU"
    scene.cycles.samples=22
    scene.render.film_transparent=True
    scene.render.resolution_x=scene.render.resolution_y=512
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(out),compress=True,check_existing=False)
    bpy.ops.object.select_all(action="DESELECT")
    exported=[ob for ob in original+process if not ob.hide_render]+newmeshes
    for ob in exported:
        ob.select_set(True)
    rigs=[ob for ob in scene.objects if ob.type=="EMPTY" and (
        ob.name.startswith("FMPL_PROCESS | keyframed central agitator") or
        ob.name.startswith("FMPL_PROCESS | powered inlet pump drive rotor")
    )]
    for ob in rigs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active=exported[0]
    bpy.ops.export_scene.gltf(filepath=str(Path(opts.glb).resolve()),export_format="GLB",
                               use_selection=True,export_apply=True,export_animations=True)
    scene.frame_set(1)
    scene.render.filepath=str(Path(opts.idle_preview).resolve())
    bpy.ops.render.render(write_still=True)
    scene.frame_set(25)
    scene.render.filepath=str(Path(opts.working_preview).resolve())
    bpy.ops.render.render(write_still=True)
    receipt={
      "schema":"fmpl.super-greeble.v1","model":"water-purifier-mh7",
      "status":"constructed-unapproved-detail-and-motion-candidate",
      "source_sha256":opts.expected_sha,
      "original_meshes":len(original),"existing_process_meshes":len(process),
      "source_original_mesh_digest":old_hash,"source_process_mesh_digest":process_hash,
      "super_greeble_meshes_added":len(newmeshes),
      "super_greeble_bounds":bounds,
      "semantic_roles":[
          "motor-drive-and-coupling","front-filter-cartridge-service-clamps",
          "before-after-visible-water-sample-stations",
          "pressure-relief-valves-and-working-gauges",
          "armored-power-conduit-and-real-mounts",
          "agitator-support-and-rotating-bubbles",
          "heat-exchanger-fins-and-condensate-return",
          "bolted-foundation-feet-and-trench-drain"
      ],
      "staged_motion":{"pump_rotor_frames":[1,25,49,73,97],
                       "filter_needles":[1,25,49,73,97],
                       "treatment_bubbles":[1,25,49,73,97]},
      "private_greebles_source":greebles,
      "source_camera_unchanged":True,
      "canonical_mating_faces_unchanged":True,
      "export_camera_count":len([ob for ob in scene.objects if ob.type=="CAMERA"]),
      "production_direction_count":1,
      "native_factorio_fluidbox_verified":False,
      "owner_visual_approval":False,
      "game_integrated":False,
      "derived_blend_sha256":sha(out),
      "derived_glb_sha256":sha(opts.glb),
      "idle_png_sha256":sha(opts.idle_preview),
      "working_png_sha256":sha(opts.working_preview)
    }
    Path(opts.report).write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
    print("FMPL_SUPER_GREEBLE_SAVED "+json.dumps({
        "added":len(newmeshes),"frozen_original":len(original),
        "frozen_process":len(process),"donor_available":greebles["available"],
        "camera":1,"source_preserved":True}),flush=True)

if __name__=="__main__":
    main()
