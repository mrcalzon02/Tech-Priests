#!/usr/bin/env python3
"""FMPL water-purifier process-visible structural refinement.

Never writes the seed/source .blend. This derivative carries the verified source
meshes unchanged, hides obsolete closed-tank/exposed-filter surfaces, and adds
civil-work, an observable glass-topped churning process, mounted filtration,
supported pipe routes, and keyed service/steam activity. Not gameplay approval.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import struct
import sys

import bpy
from mathutils import Vector


def sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def hash_original_meshes(objects):
    h = hashlib.sha256()
    for obj in sorted(objects, key=lambda o: o.name):
        h.update(obj.name.encode("utf-8"))
        for row in obj.matrix_world:
            for value in row:
                h.update(struct.pack("<d", float(value)))
        for vertex in obj.data.vertices:
            h.update(struct.pack("<ddd", *[float(v) for v in vertex.co]))
        for polygon in obj.data.polygons:
            h.update(struct.pack("<I", len(polygon.vertices)))
            for index in polygon.vertices:
                h.update(struct.pack("<I", index))
    return h.hexdigest()


def name_of(label):
    return "FMPL_PROCESS | " + label


def add_collection(scene):
    collection = bpy.data.collections.new("FMPL | WATER PURIFIER FUNCTIONAL PROCESS V02")
    scene.collection.children.link(collection)
    return collection


def rehouse(obj, collection, material):
    for old in list(obj.users_collection):
        old.objects.unlink(obj)
    collection.objects.link(obj)
    obj.name = name_of(obj.name)
    if material is not None:
        obj.data.materials.clear()
        obj.data.materials.append(material)
    obj["fmpl_process_role"] = obj.name.partition("| ")[2]
    obj["fmpl_candidate_not_game_approved"] = True
    return obj


def block(collection, label, loc, size, material, bevel=.014):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = label
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    rehouse(obj, collection, material)
    if bevel:
        mod = obj.modifiers.new("Manufactured edge radius", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
    return obj


def cyl(collection, label, loc, radius, depth, material, axis="Z", vertices=48):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius,
                                         depth=depth, location=loc)
    obj = bpy.context.object
    if axis == "X":
        obj.rotation_euler[1] = math.pi/2
    elif axis == "Y":
        obj.rotation_euler[0] = math.pi/2
    obj.name = label
    return rehouse(obj, collection, material)


def torus(collection, label, loc, r, thickness, material, axis="Z"):
    bpy.ops.mesh.primitive_torus_add(major_segments=64, minor_segments=12,
                                    location=loc, major_radius=r,
                                    minor_radius=thickness)
    obj = bpy.context.object
    if axis == "X":
        obj.rotation_euler[1] = math.pi/2
    elif axis == "Y":
        obj.rotation_euler[0] = math.pi/2
    obj.name = label
    return rehouse(obj, collection, material)


def open_hollow_tube(collection, label, a, b, radius, material, bore_ratio=.72):
    start, end = Vector(a), Vector(b)
    axis = end-start
    if axis.length < .04:
        raise RuntimeError("Unsupported zero-length process pipe")
    direction = axis.normalized()
    side = direction.cross(Vector((0,0,1)))
    if side.length < .02:
        side = direction.cross(Vector((0,1,0)))
    side.normalize()
    other = direction.cross(side).normalized()
    n = 32
    rings = ((start,radius),(end,radius),
             (start,radius*bore_ratio),(end,radius*bore_ratio))
    verts = []
    for center,rad in rings:
        for index in range(n):
            angle = math.tau * index/n
            vert = center + rad*(side*math.cos(angle)+other*math.sin(angle))
            verts.append(tuple(vert))
    faces=[]
    for i in range(n):
        j=(i+1)%n
        faces.extend(((i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),
                      (i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)))
    mesh=bpy.data.meshes.new(name_of(label)+" mesh")
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name_of(label),mesh)
    collection.objects.link(obj)
    if material:
        mesh.materials.append(material)
    obj["fmpl_process_role"]=label
    return obj


def pipe_route(collection,label,points,radius,material,elbow_material):
    for i in range(len(points)-1):
        open_hollow_tube(collection,label+" / section "+str(i+1),
                         points[i],points[i+1],radius,material)
    # Genuine joined corners rather than unsupported tubes terminating in air.
    for i,point in enumerate(points[1:-1],1):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,
                                             radius=radius*1.09, location=point)
        ball=bpy.context.object
        ball.name=label+" / cast elbow "+str(i)
        rehouse(ball,collection,elbow_material)


def transparent_material(name, rgb, transmission, roughness, alpha=1.0):
    mat=bpy.data.materials.new(name)
    mat.diffuse_color=(*rgb,alpha)
    mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value=(*rgb,1)
    bsdf.inputs["Metallic"].default_value=0.0
    bsdf.inputs["Roughness"].default_value=roughness
    trans=bsdf.inputs.get("Transmission Weight")
    if trans:
        trans.default_value=transmission
    bsdf.inputs["Alpha"].default_value=alpha
    ior=bsdf.inputs.get("IOR")
    if ior:
        ior.default_value=1.33 if transmission<.55 else 1.46
    mat["fmpl_visual_process_only"]=True
    return mat


def nested_material_import(root, materials):
    source=Path(root)/"art/source-to-3d/shared-parts/industrial-asset-library/import_materials.py"
    spec=importlib.util.spec_from_file_location("fmpl_process_materials",source)
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.import_materials(Path(root),materials)


def make_vessel_shell(collection,metal,steel):
    # Source cylinder is kept for provenance but hidden; process geometry is
    # open, load-bearing and double-walled with a real horizontal annular rim.
    cx,cy=0.0,.10
    outer,inner=.758,.682
    bottom,top=.57,2.68
    n=64
    vertices=[]
    for z,r in ((bottom,outer),(top,outer),(bottom,inner),(top,inner)):
        for k in range(n):
            angle=k*math.tau/n
            vertices.append((cx+r*math.cos(angle),cy+r*math.sin(angle),z))
    faces=[]
    for k in range(n):
        j=(k+1)%n
        faces.extend(((k,j,n+j,n+k),
                      (2*n+k,3*n+k,3*n+j,2*n+j),
                      (n+k,n+j,3*n+j,3*n+k),
                      (k,2*n+k,2*n+j,j)))
    mesh=bpy.data.meshes.new("FMPL | open vessel wall")
    mesh.from_pydata(vertices,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name_of("open double-wall steel treatment vessel"),mesh)
    collection.objects.link(obj)
    mesh.materials.append(metal)
    obj["fmpl_process_role"]="open and mechanically supported main treatment volume"
    obj["source_closed_shell_hidden_not_deleted"]=True
    torus(collection,"machined upper inspection gasket",(cx,cy,top),.716,.045,steel)
    torus(collection,"lower body compression band",(cx,cy,.66),.773,.032,steel)
    return obj


def bolt(collection,label,point,mat):
    cyl(collection,label+" | anchor shaft",point,.040,.07,mat,vertices=12)
    cyl(collection,label+" | locked hex crown",(point[0],point[1],point[2]+.041),
        .055,.032,mat,vertices=6)


def parent_to_rotor(objects,rotor):
    bpy.context.view_layer.update()
    for obj in objects:
        world=obj.matrix_world.copy()
        obj.parent=rotor
        obj.matrix_world=world


def full_bounds(objects):
    lows=[float("inf")]*3
    highs=[-float("inf")]*3
    for obj in objects:
        corners=[obj.matrix_world@Vector(point) for point in obj.bound_box]
        for k in range(3):
            lows[k]=min(lows[k],*(point[k] for point in corners))
            highs[k]=max(highs[k],*(point[k] for point in corners))
    return {"min":lows,"max":highs}


def main():
    parser=argparse.ArgumentParser()
    for param in ("input","fmpl-root","out","glb","report","idle-preview","active-preview"):
        parser.add_argument("--"+param,required=True)
    args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
    files=(args.out,args.glb,args.report,args.idle_preview,args.active_preview)
    for target in files:
        path=Path(target).resolve()
        path.parent.mkdir(parents=True,exist_ok=True)
        if path.exists():
            raise FileExistsError("Never overwrite FMPL process output: "+str(path))
    bpy.ops.wm.open_mainfile(filepath=str(Path(args.input).resolve()))
    scene=bpy.context.scene
    originals=[o for o in scene.objects if o.type=="MESH" and o.name.startswith("MH7_")]
    if len(originals)!=50:
        raise RuntimeError("Expected preserved 50-mesh Water Purifier, found "+str(len(originals)))
    base_hash=hash_original_meshes(originals)
    library=nested_material_import(args.fmpl_root,
           ["ferrocrete","ferrocrete_light","ferrocrete_dark","machine_steel",
            "iron","brass","martian_red","gunmetal_dark","glass"])
    concrete=library["ferrocrete"]
    pavers=library["ferrocrete_light"]
    foundation=library["ferrocrete_dark"]
    steel=library["machine_steel"]
    iron=library["iron"]
    brass=library["brass"]
    red=library["martian_red"]
    dark=library["gunmetal_dark"]
    glass=transparent_material("FMPL | clear inspection glass",(0.70,.88,.92),.93,.08,.35)
    amber=transparent_material("FMPL | raw turbid inlet water",(.31,.19,.07),.27,.28,.88)
    teal=transparent_material("FMPL | clarified water channel",(.05,.42,.46),.31,.17,.83)
    water=transparent_material("FMPL | agitated process surface",(.06,.36,.40),.12,.22,.80)
    foam=transparent_material("FMPL | churning foam",(.74,.89,.82),.10,.63,.84)
    steam=transparent_material("FMPL | vented condensed steam",(.74,.82,.80),.15,.80,.34)
    col=add_collection(scene)
    # Civil works first: actual historical bed mesh is resurfaced, never discarded.
    base=next((o for o in originals if o.name=="MH7_base bed"),None)
    if base is None:
        raise RuntimeError("Original construction bed missing")
    base.data.materials.clear()
    base.data.materials.append(foundation)
    block(col,"cast industrial concrete raised plinth",(0,0,.238),(2.82,2.82,.035),concrete,.022)
    # Existing cast iron foundation feet still occupy their physical positions.
    # Service apron uses 3D paver bricks carrying existing FMPL ferrocrete PBR.
    for x in (-1.06,-.70,-.34,.02,.38,.74,1.10):
        for row,y in enumerate((-1.265,-1.005)):
            px=x+(.12 if row%2 else 0)
            if abs(px)>1.35:
                continue
            block(col,"paving brick %.2f %.2f"%(px,y),(px,y,.277),
                  (.315,.225,.050),pavers,.008)
    for sx in (-1.23,1.23):
        for sy in (-1.23,1.23):
            block(col,"load column cast concrete shoe %.2f %.2f"%(sx,sy),
                 (sx,sy,.285),(.31,.31,.06),foundation,.016)
            for offset in (-.095,.095):
                bolt(col,"column anchor %.2f %.2f %.2f"%(sx,sy,offset),
                     (sx+offset,sy,.344),brass)
    # Keep original meshes/historical geometry but hide obsolete opaque shell and
    # overlapped filter cartridges from the derived scene and production GLB.
    old_hidden=[]
    old_replaced=("MH7_central sealed purifier vessel",
                  "MH7_domed vessel neck","MH7_vessel crown",
                  "MH7_replaceable filter cartridge",
                  "MH7_filter retaining bracket","MH7_filter cartridge collar")
    for o in originals:
        if any(o.name.startswith(prefix) for prefix in old_replaced):
            o.hide_render=True
            old_hidden.append(o.name)
    make_vessel_shell(col,steel,iron)
    # Glass roof genuinely exposes shaft and mechanical blades in Factorio camera.
    cyl(col,"transparent observation lid",(0,.1,2.735),.695,.065,glass,vertices=64)
    torus(col,"screwed glass retaining bezel",(0,.1,2.74),.718,.038,brass)
    for k in range(8):
        a=k*math.tau/8
        bolt(col,"inspection bezel screw %02d"%k,
             (.72*math.cos(a),.1+.72*math.sin(a),2.78),brass)
    cyl(col,"chamber fluid body",(0,.1,1.45),.678,1.51,water,vertices=64)
    cyl(col,"visible liquid free surface",(0,.1,2.212),.67,.023,teal,vertices=64)
    torus(col,"liquid swirl at sight glass",(0,.1,2.236),.50,.025,foam)
    # Positive mechanical chain: bed mount -> drive brackets -> gearbox ->
    # bearing gland -> central shaft -> four swept mixing paddles.
    block(col,"gearbox load-bearing overhead bridge",(0,.1,3.108),
          (1.83,.22,.13),steel,.023)
    for sx in (-.84,.84):
        block(col,"gearbox crossbeam pedestal %.2f"%sx,(sx,.1,2.92),
              (.135,.14,.37),red,.015)
    cyl(col,"agitator shaft sealed bearing gland",(0,.1,2.83),.21,.17,iron)
    cyl(col,"agitator motor gearbox housing",(0,.1,3.24),.28,.25,red)
    torus(col,"agitator gearbox bearing ring",(0,.1,3.14),.235,.04,brass)
    rotor=bpy.data.objects.new(name_of("keyframed central agitator rotor"),None)
    col.objects.link(rotor)
    rotor.empty_display_type="SINGLE_ARROW"
    rotor.empty_display_size=.22
    rotor.location=(0,.1,2.25)
    driven=[]
    driven.append(cyl(col,"visible vertical mixing shaft",(0,.1,2.22),.047,1.23,steel))
    for z,size in ((2.28,.43),(1.93,.37)):
        for i in range(4):
            angle=i*math.tau/4
            dx,dy=math.cos(angle),math.sin(angle)
            middle=(dx*size*.48,.1+dy*size*.48,z)
            paddle=block(col,"impeller paddle z%.2f %02d"%(z,i),
                   middle,(size,.105,.105),brass,.018)
            paddle.rotation_euler[2]=angle
            driven.append(paddle)
    driven.append(torus(col,"visible stirring eddy ring",(0,.1,2.246),.26,.028,foam))
    parent_to_rotor(driven,rotor)
    for frame,rotation in ((1,0),(25,math.pi*.50),(49,math.pi),
                           (73,math.pi*1.5),(97,math.tau)):
        rotor.rotation_euler.z=rotation
        rotor.keyframe_insert(data_path="rotation_euler",index=2,frame=frame)
    # Blender 5+ uses layered Actions; keyframes are meaningful without
    # depending on the legacy Action.fcurves collection.
    # Keep source pump mesh; add visible intake-side motor and inspection hardware.
    block(col,"low pump motor mounting shoe",(-1.12,-.79,.36),(.44,.53,.14),foundation,.02)
    cyl(col,"low mounted intake centrifugal pump",(-1.12,-.79,.61),.24,.37,iron,axis="X")
    torus(col,"pump inspection seal ring",(-.92,-.79,.61),.205,.031,brass,axis="X")
    cyl(col,"pump drive casing",(-1.11,-.50,.61),.13,.35,dark,axis="Y")
    # Two actual cartridge houses, each braced to the foundation and removable.
    for i,(x,y,fluid) in enumerate(((-1.11,-.45,amber),(-.84,-.59,teal)),1):
        block(col,"filter %d replaceable lower shoe"%i,(x,y,.51),
              (.34,.34,.11),iron,.014)
        cyl(col,"filter %d cartridge body"%i,(x,y,1.04),.145,.91,iron)
        cyl(col,"filter %d cylindrical glass sight"%i,(x,y,1.15),.150,.37,glass)
        cyl(col,"filter %d visible process medium"%i,(x,y,1.15),.125,.32,fluid)
        torus(col,"filter %d removable locking ring"%i,(x,y,1.52),.154,.037,brass)
        block(col,"filter %d upright service bracket"%i,(x,y+.16,1.04),
              (.09,.08,1.03),steel,.009)
        cyl(col,"filter %d vertical cartridge pressure crown"%i,
            (x,y,1.55),.18,.12,red)
    # Model-space input/output planes follow the PREEXISTING 3x3 prototype
    # geometry. They remain independent of native Lua pipe-connection cells.
    raw=[(-1.48,-.78,.36),(-1.24,-.78,.36),(-1.12,-.78,.61)]
    pipe_route(col,"raw water inlet to pump",raw,.113,iron,steel)
    open_hollow_tube(col,"dirty inlet visible sight glass",
               (-1.42,-.78,.36),(-1.27,-.78,.36),.115,glass)
    open_hollow_tube(col,"dirty inlet fluid seen through glass",
               (-1.42,-.78,.36),(-1.27,-.78,.36),.076,amber)
    pipe_route(col,"pump to first vertical filter",
       [(-1.12,-.63,.61),(-1.11,-.45,.67)],.091,iron,brass)
    pipe_route(col,"first filter to second filter",
       [(-1.11,-.45,1.55),(-.84,-.59,.71)],.075,steel,brass)
    pipe_route(col,"second filter to central treatment inlet",
       [(-.84,-.59,1.55),(-.68,-.33,1.90)],.079,steel,brass)
    pipe_route(col,"treated chamber to clean water outlet",
       [(.69,-.18,.79),(.99,-.62,.48),(1.45,-.62,.36)],
       .109,iron,steel)
    open_hollow_tube(col,"clean discharge visible sight glass",
       (1.12,-.62,.43),(1.36,-.62,.383),.115,glass)
    open_hollow_tube(col,"clarified water seen at discharge",
       (1.12,-.62,.43),(1.36,-.62,.383),.076,teal)
    for i,(position,axis) in enumerate((
        ((-1.30,-.78,.36),"X"),((1.29,-.62,.386),"X")),1):
        cyl(col,"sight glass bolted pressure adapter %d"%i,
            position,.152,.053,brass,axis)
    # Thermal outlet, check valve and pressure relief: physically seated on the
    # upper rear side of treatment vessel; steam originates at actual nozzle.
    pipe_route(col,"pressure relief to exhaust elbow",
        [(.61,.48,2.35),(.94,.60,2.55),(.94,.60,2.77)],
        .089,steel,brass)
    cyl(col,"vent nozzle anchored through pressure pipe",
        (.94,.60,2.80),.117,.08,iron)
    for k in range(2):
        bpy.ops.mesh.primitive_cone_add(vertices=20,radius1=.055,
           radius2=.14,depth=.30,location=(.91+k*.14,.61,2.98+k*.17))
        cloud=bpy.context.object
        cloud.name="service steam plume %d"%(k+1)
        rehouse(cloud,col,steam)
        cloud.scale=(.1,.1,.1)
        cloud.keyframe_insert(data_path="scale",frame=1)
        cloud.scale=(1,1,1)
        cloud.keyframe_insert(data_path="scale",frame=25)
        cloud.scale=(.16,.16,.16)
        cloud.keyframe_insert(data_path="scale",frame=49)
    if hash_original_meshes(originals)!=base_hash:
        raise RuntimeError("Original Water Purifier mesh transforms or source geometry changed")
    parts=[o for o in col.objects if o.type=="MESH"]
    bounds=full_bounds(parts)
    if any(abs(bounds[edge][axis])>1.59 for edge in ("min","max") for axis in (0,1)):
        raise RuntimeError("Process geometry exceeds 3x3 modelling envelope: "+str(bounds))
    if bounds["min"][2]<-.015 or bounds["max"][2]>3.60:
        raise RuntimeError("Process detail height exceeds constrained envelope: "+str(bounds))
    scene.frame_start=1
    scene.frame_end=97
    scene.frame_set(1)
    scene.render.engine="CYCLES"
    scene.cycles.device="CPU"
    scene.cycles.samples=16
    scene.render.film_transparent=True
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"
    scene.render.resolution_x=512
    scene.render.resolution_y=512
    scene.render.resolution_percentage=100
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(Path(args.out).resolve()),
                                compress=True,check_existing=False)
    # Production GLB excludes obsolete visual replacement shapes and all
    # reference test pipes; only actual authored process machinery is exported.
    bpy.ops.object.select_all(action="DESELECT")
    export=[o for o in originals if not o.hide_render]+parts
    for obj in export:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=export[0]
    bpy.ops.export_scene.gltf(filepath=str(Path(args.glb).resolve()),
       export_format="GLB",use_selection=True,export_apply=True)
    scene.frame_set(1)
    scene.render.filepath=str(Path(args.idle_preview).resolve())
    bpy.ops.render.render(write_still=True)
    scene.frame_set(25)
    scene.render.filepath=str(Path(args.active_preview).resolve())
    bpy.ops.render.render(write_still=True)
    scene.frame_set(1)
    stage={
      "schema":"fmpl.process-machinery-candidate.v1",
      "status":"candidate-structural-PBR-process-detail",
      "machine_id":"water-purifier-mh7",
      "originals_unchanged":True,
      "input_scene_sha256":sha(args.input),
      "source_geometry_sha256":base_hash,
      "source_mesh_count":len(originals),
      "source_meshes_derived_hidden":old_hidden,
      "process_meshes_added":len(parts),
      "process_bounds":bounds,
      "source_parts_rendered":len(export)-len(parts),
      "materials_from_fmpl":["ferrocrete","ferrocrete_light","ferrocrete_dark",
          "machine_steel","iron","brass","martian_red","gunmetal_dark","glass"],
      "foundation_language":"poured structural concrete plinth, paver service apron, visible steel anchors",
      "process_path":["raw inlet","intake pump","two staged filter cartridges",
           "open agitator vessel","treated water discharge"],
      "animated_elements":{"agitator_rotor":"1/25/49/73/97","steam_plumes":"1/25/49",
          "fluid_surface":"visible mix and ripple rings; not a fluid simulator"},
      "glass_lid_visible":True,"glass_windows_visible":True,
      "native_factorio_ports_verified":False,
      "human_visual_approval":False,"game_integrated":False,
      "derived_blend_sha256":sha(args.out),
      "glb_sha256":sha(args.glb),
      "idle_render_sha256":sha(args.idle_preview),
      "active_render_sha256":sha(args.active_preview)
    }
    Path(args.report).write_text(json.dumps(stage,indent=2)+"\n",encoding="utf-8")
    print("FMPL_PROCESS_REFINEMENT_SAVED "+json.dumps({
      "added_meshes":len(parts),"source_preserved":True,
      "filtered_process":5,"glass_lid":True}),flush=True)


if __name__=="__main__":
    main()
