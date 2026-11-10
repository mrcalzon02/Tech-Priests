#!/usr/bin/env python3
"""FMPL Effects v1.0.3: deterministic native Blender materials and animated FX rigs.

No external material files, generators, downloads, game edits or simulations.
Requires bpy in Blender 4.3+ / Blender 5.2. Never overwrites an output folder.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

WORK_FRAMES=tuple(range(1,92,6))
LOOP_END=97
MASTER_NAME="FMPL_effects_materials_v1.blend"

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def mat_color(rgb, factor=1.0):
    return tuple(max(.025, min(.90, c*factor)) for c in rgb)+(1.0,)

def socket(node, name):
    result=node.inputs.get(name)
    if result is None:
        raise RuntimeError("Blender shader incompatible: "+node.bl_idname+" missing "+name)
    return result

def new_surface(bpy, record):
    mat=bpy.data.materials.new("FMPL FX | "+record["id"])
    mat.use_nodes=True
    mat.diffuse_color=tuple(record["base_color"])+(1.0,)
    nodes=mat.node_tree.nodes
    nodes.clear()
    links=mat.node_tree.links
    end=nodes.new("ShaderNodeOutputMaterial")
    end.name="FMPL | Output"
    surf=nodes.new("ShaderNodeBsdfPrincipled")
    surf.name="FMPL | Surface"
    links.new(surf.outputs["BSDF"],end.inputs["Surface"])
    rgb=record["base_color"]
    socket(surf,"Base Color").default_value=tuple(rgb)+(1.0,)
    socket(surf,"Metallic").default_value=record["metallic"]
    socket(surf,"Roughness").default_value=record["roughness"]
    socket(surf,"IOR").default_value=record["ior"]
    socket(surf,"Transmission Weight").default_value=record["transmission"]

    coords=nodes.new("ShaderNodeTexCoord")
    coords.name="FMPL | Texture Coordinates"
    mapping=nodes.new("ShaderNodeMapping")
    mapping.name="FMPL | Mapping"
    links.new(coords.outputs["Object"],mapping.inputs["Vector"])
    frequency=nodes.new("ShaderNodeValue")
    frequency.name="FMPL | Master Scale"
    frequency.outputs[0].default_value=float(record["noise_scale"])
    noise=nodes.new("ShaderNodeTexNoise")
    noise.name="FMPL | Noise"
    noise.inputs["Detail"].default_value=3.0
    noise.inputs["Roughness"].default_value=.63
    links.new(mapping.outputs["Vector"],noise.inputs["Vector"])
    links.new(frequency.outputs[0],noise.inputs["Scale"])

    rough=nodes.new("ShaderNodeMapRange")
    rough.name="FMPL | Micro-Roughness"
    rough.inputs["From Min"].default_value=0.0
    rough.inputs["From Max"].default_value=1.0
    rough.inputs["To Min"].default_value=max(.025,record["roughness"]-.07)
    rough.inputs["To Max"].default_value=min(.98,record["roughness"]+.07)
    links.new(noise.outputs["Fac"],rough.inputs["Value"])
    links.new(rough.outputs["Result"],surf.inputs["Roughness"])

    colors=nodes.new("ShaderNodeValToRGB")
    colors.name="FMPL | Broken Albedo"
    colors.color_ramp.interpolation="EASE"
    colors.color_ramp.elements[0].color=mat_color(rgb,.78)
    colors.color_ramp.elements[1].color=mat_color(rgb,1.13)
    links.new(noise.outputs["Fac"],colors.inputs["Fac"])
    links.new(colors.outputs["Color"],surf.inputs["Base Color"])

    detail=nodes.new("ShaderNodeBump")
    detail.name="FMPL | Restrained Bump"
    detail.inputs["Strength"].default_value=.18
    detail.inputs["Distance"].default_value=record["bump_distance"]
    links.new(noise.outputs["Fac"],detail.inputs["Height"])
    links.new(detail.outputs["Normal"],surf.inputs["Normal"])

    if record["effect"] in ("cracks","molten"):
        cells=nodes.new("ShaderNodeTexVoronoi")
        cells.name="FMPL | Local Stress / Crust Cells"
        cells.feature="DISTANCE_TO_EDGE"
        cells.inputs["Scale"].default_value=float(record["noise_scale"])*.5
        links.new(mapping.outputs["Vector"],cells.inputs["Vector"])
        crack=nodes.new("ShaderNodeValToRGB")
        crack.name="FMPL | Crack / Magma Mask"
        crack.color_ramp.interpolation="EASE"
        first=crack.color_ramp.elements[0]
        last=crack.color_ramp.elements[1]
        first.position=.008
        last.position=.10
        if record["effect"]=="cracks":
            first.color=mat_color(rgb,.16)
            last.color=mat_color(rgb,1.07)
        else:
            first.color=mat_color(record["emission_color"],1.3)
            last.color=mat_color(rgb,.48)
        links.new(cells.outputs["Distance"],crack.inputs["Fac"])
        links.new(crack.outputs["Color"],surf.inputs["Base Color"])
        links.new(cells.outputs["Distance"],detail.inputs["Height"])
        detail.inputs["Strength"].default_value=.23
        if record["effect"]=="molten":
            hot=nodes.new("ShaderNodeMath")
            hot.name="FMPL | Active Molten Channel"
            hot.operation="LESS_THAN"
            hot.inputs[1].default_value=.07
            links.new(cells.outputs["Distance"],hot.inputs[0])
            magnitude=nodes.new("ShaderNodeMath")
            magnitude.operation="MULTIPLY"
            magnitude.inputs[1].default_value=record["emission_strength"]
            links.new(hot.outputs[0],magnitude.inputs[0])
            links.new(magnitude.outputs[0],socket(surf,"Emission Strength"))
            socket(surf,"Emission Color").default_value=tuple(record["emission_color"])+(1.0,)

    if record["effect"]=="heat":
        # Blackbody is a thermal-color approximation, not an expansion/temperature solver.
        kelvin=nodes.new("ShaderNodeBlackbody")
        kelvin.name="FMPL | Blackbody Heated Steel"
        kelvin.inputs["Temperature"].default_value=1080 if "red" in record["id"] else 1510
        links.new(kelvin.outputs["Color"],socket(surf,"Emission Color"))
        magnitude=nodes.new("ShaderNodeMath")
        magnitude.name="FMPL | Controlled Heat Emission"
        magnitude.operation="MULTIPLY"
        magnitude.inputs[1].default_value=record["emission_strength"]
        links.new(noise.outputs["Fac"],magnitude.inputs[0])
        links.new(magnitude.outputs[0],socket(surf,"Emission Strength"))
    elif record["effect"]=="normal" and record["emission_strength"]>0:
        socket(surf,"Emission Color").default_value=tuple(record["emission_color"])+(1.0,)
        socket(surf,"Emission Strength").default_value=record["emission_strength"]

    return mat

def new_volume(bpy, record):
    mat=bpy.data.materials.new("FMPL FX | "+record["id"])
    mat.use_nodes=True
    mat.diffuse_color=tuple(record["base_color"])+(1.0,)
    nodes=mat.node_tree.nodes
    nodes.clear()
    links=mat.node_tree.links
    end=nodes.new("ShaderNodeOutputMaterial")
    end.name="FMPL | Output"
    volume=nodes.new("ShaderNodeVolumePrincipled")
    volume.name="FMPL | Density Volume"
    socket(volume,"Color").default_value=tuple(record["base_color"])+(1.0,)
    socket(volume,"Density").default_value=record["density"]
    links.new(volume.outputs["Volume"],end.inputs["Volume"])
    coords=nodes.new("ShaderNodeTexCoord")
    coords.name="FMPL | Texture Coordinates"
    mapping=nodes.new("ShaderNodeMapping")
    mapping.name="FMPL | Mapping"
    links.new(coords.outputs["Object"],mapping.inputs["Vector"])
    frequency=nodes.new("ShaderNodeValue")
    frequency.name="FMPL | Master Scale"
    frequency.outputs[0].default_value=record["noise_scale"]
    noise=nodes.new("ShaderNodeTexNoise")
    noise.name="FMPL | Noise"
    links.new(mapping.outputs["Vector"],noise.inputs["Vector"])
    links.new(frequency.outputs[0],noise.inputs["Scale"])
    rough=nodes.new("ShaderNodeMapRange")
    rough.name="FMPL | Bounded Density"
    rough.inputs["To Min"].default_value=record["density"]*.30
    rough.inputs["To Max"].default_value=record["density"]*1.60
    links.new(noise.outputs["Fac"],rough.inputs["Value"])
    links.new(rough.outputs["Result"],socket(volume,"Density"))
    return mat

def create_materials(bpy,catalog):
    result={}
    for record in catalog["presets"]:
        mat=new_volume(bpy,record) if record["mode"]=="volume" else new_surface(bpy,record)
        mat["fmpl_effect_id"]=record["id"]
        mat["fmpl_effect_version"]=catalog["version"]
        mat["fmpl_effect_family"]=record["family"]
        mat["fmpl_effect_mode"]=record["mode"]
        mat["fmpl_effect_tier"]=record["performance"]
        mat["fmpl_effect_notes"]=record["notes"]
        mat.asset_mark()
        if getattr(mat,"asset_data",None) is not None:
            mat.asset_data.description=record["notes"]
        result[record["id"]]=mat
    return result

def link_to(obj,collection):
    for other in tuple(obj.users_collection):
        other.objects.unlink(obj)
    collection.objects.link(obj)
    return obj

def sphere(bpy,collection,name,location,scale,material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=1,location=location)
    ob=link_to(bpy.context.object,collection)
    ob.name=name
    ob.scale=scale
    ob.data.materials.append(material)
    for face in ob.data.polygons:face.use_smooth=True
    return ob

def cube(bpy,collection,name,location,scale,material):
    bpy.ops.mesh.primitive_cube_add(size=1,location=location)
    ob=link_to(bpy.context.object,collection)
    ob.name=name
    ob.scale=scale
    ob.data.materials.append(material)
    return ob

def cone(bpy,collection,name,location,material):
    bpy.ops.mesh.primitive_cone_add(vertices=12,radius1=.14,radius2=.008,depth=.65,location=location)
    ob=link_to(bpy.context.object,collection)
    ob.name=name
    ob.data.materials.append(material)
    return ob

def torus_mesh(bpy,collection,name,location,material,major=.24,minor=.035):
    n=36
    verts=[];faces=[]
    for radius,z in ((major-minor,-.003),(major+minor,-.003)):
        verts.extend([(radius*math.cos(2*math.pi*i/n),
                       radius*math.sin(2*math.pi*i/n),z)
                     for i in range(n)])
    for i in range(n):
        nxt=(i+1)%n
        faces.append((i,nxt,n+nxt,n+i))
    mesh=bpy.data.meshes.new(name+" mesh")
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    collection.objects.link(obj)
    obj.location=location  # mesh vertices stay local, rig root alone sets gallery position
    mesh.materials.append(material)
    return obj

def label(bpy,collection,name,position,material):
    data=bpy.data.curves.new("FMPL | swatch label","FONT")
    data.body=name
    data.size=.145
    ob=bpy.data.objects.new("LABEL | "+name,data)
    collection.objects.link(ob)
    ob.location=position
    ob.rotation_euler.x=math.radians(45)  # face the fixed 45-degree preview camera
    data.materials.append(material)
    return ob

def attach_to(obj,parent):
    matrix=obj.matrix_world.copy()
    obj.parent=parent
    obj.matrix_world=matrix
    return obj

def build_animated_rigs(bpy,scene,materials,defs):
    rigroots=[];counts={}
    for n,rig in enumerate(defs):
        col=bpy.data.collections.new("FMPL FX RIG | "+rig["id"])
        scene.collection.children.link(col)
        if hasattr(col,"asset_mark"):
            col.asset_mark()
        root=bpy.data.objects.new("FMPL FX ROOT | "+rig["id"],None)
        col.objects.link(root)
        root.location=(n*1.45-0.1,-6.15,.0)
        bpy.context.view_layer.update()
        items=[]
        for j in range(rig["count"]):
            x=root.location.x+(.13*j-.16)
            y=root.location.y+(.07*j-.12)
            if rig["kind"]=="flame":
                ob=cone(bpy,col,"FX | flame-lobe-%d"%j,(x,y,.44),materials[rig["material"]])
            elif rig["kind"]=="cloud":
                ob=sphere(bpy,col,"FX | vapor-lobe-%d"%j,(x,y,.48),(.22,.19,.30),materials[rig["material"]])
            elif rig["kind"] in ("heat","ripple"):
                mat=materials["glass-clear"] if rig["kind"]=="heat" else materials[rig["material"]]
                ob=torus_mesh(bpy,col,"FX | bounded-ring-%d"%j,(x,y,.19),mat,major=.16+j*.065)
            else:
                raise RuntimeError("Unknown rig type: "+rig["kind"])
            # Blender creates primitives with world-space transforms. The old
            # matrix_world re-parent caused deferred-depsgraph scale readback:
            # small (.22,.19,.30) vapor spheres became unit-sized after linking.
            # Parent in *local coordinates*, preserving original scale explicitly.
            local_scale=tuple(ob.scale)
            ob.parent=root
            ob.matrix_parent_inverse.identity()
            ob.location=(.13*j-.16,.07*j-.12,.44 if rig["kind"] in ("flame","cloud") else .19)
            ob.rotation_euler=(0,0,0)
            ob.scale=local_scale
            bpy.context.view_layer.update()
            if rig["kind"]=="cloud" and max(ob.scale.x,ob.scale.y)>.4:
                raise RuntimeError("Emitter changed scale during parenting: "+ob.name)
            items.append(ob)
        # Preserve true native dimensions: a vapor lobe must stay a small lobe, not inflate to a full unit sphere.
        base_scales=[tuple(ob.scale) for ob in items]
        # Exact 16-sample cycle + one seam sample. Values are bounded in space and scale.
        first=None
        for idx,frame in enumerate(tuple(WORK_FRAMES)+(LOOP_END,)):
            phase=2*math.pi*(idx%16)/16
            for j,ob in enumerate(items):
                ob.location.z=(.44 if rig["kind"] in ("flame","cloud") else .19)+.047*math.sin(phase+j*.8)
                ob.rotation_euler.z=.18*math.sin(phase+j*.7)
                ob.scale.x=base_scales[j][0]*(1.0+.09*math.sin(phase+j*.9))
                ob.scale.y=base_scales[j][1]*(1.0+.05*math.cos(phase+j*.6))
                ob.scale.z=base_scales[j][2]*(1.0+.04*math.sin(phase+j*.7))
                ob.keyframe_insert(data_path="location",frame=frame)
                ob.keyframe_insert(data_path="rotation_euler",frame=frame)
                ob.keyframe_insert(data_path="scale",frame=frame)
            if idx==0:
                first=[(tuple(ob.location),tuple(ob.rotation_euler),tuple(ob.scale)) for ob in items]
        for j,ob in enumerate(items):
            now=(tuple(ob.location),tuple(ob.rotation_euler),tuple(ob.scale))
            before=first[j]
            assert all(abs(a-b)<1e-9 for q,v in zip(now,before) for a,b in zip(q,v)),rig["id"]
        root["fmpl_effect_rig_id"]=rig["id"]
        root["fmpl_effect_loop_frames"]=16
        root["fmpl_effect_usage"]="Move root to a real emitter; source gallery placement is for preview only."
        rigroots.append(root)
        counts[rig["id"]]=len(items)
    return rigroots,counts

def make_gallery(bpy,scene,materials,records):
    col=bpy.data.collections.new("FMPL EFFECTS | 28 material swatches")
    scene.collection.children.link(col)
    back=bpy.data.materials.new("GALLERY ONLY | graphite stage")
    back.diffuse_color=(.09,.11,.13,1)
    back.use_nodes=True
    back.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value=(.09,.11,.13,1)
    text=bpy.data.materials.new("GALLERY ONLY | labels")
    text.diffuse_color=(.85,.83,.75,1)
    text.use_nodes=True
    text_shader=text.node_tree.nodes.get("Principled BSDF")
    text_shader.inputs["Base Color"].default_value=(.85,.83,.75,1)
    text_shader.inputs["Emission Color"].default_value=(.85,.83,.75,1)
    text_shader.inputs["Emission Strength"].default_value=.45
    cube(bpy,col,"GALLERY | support floor",(3.5,-3.13,-.11),(9.5,8.0,.12),back)
    for idx,item in enumerate(records):
        c=idx%7;r=idx//7
        x=c*1.12;y=-r*1.32
        if item["mode"]=="volume":
            sample=sphere(bpy,col,"SWATCH | "+item["id"],(x,y,.40),(.34,.34,.34),materials[item["id"]])
        else:
            sample=sphere(bpy,col,"SWATCH | "+item["id"],(x,y,.40),(.34,.34,.34),materials[item["id"]])
        sample["fmpl_swatch_id"]=item["id"]
        out_label=item["id"].replace("-"," ")[:19]
        label(bpy,col,out_label,(x-.42,y-.59,.09),text)

def set_camera(bpy,scene,size,samples):
    from mathutils import Vector
    cam=bpy.data.cameras.new("FMPL | canonical 45 gallery lens")
    cam.type="ORTHO"
    cam.ortho_scale=10.7
    obj=bpy.data.objects.new("FMPL | fixed 45 degree gallery camera",cam)
    scene.collection.objects.link(obj)
    target=Vector((3.27,-2.75,.42))
    obj.location=target+Vector((0,-12,12))
    obj.rotation_euler=(target-obj.location).to_track_quat("-Z","Y").to_euler()
    scene.camera=obj
    scene["fmpl_camera_target"]=list(target)
    for name,location,power,color,area_size in [
        ("warm key",(-4,-5,9),1150,(1.0,.84,.68),8),
        ("blue fill",(10,2,10),900,(.58,.75,1.0),9),
    ]:
        light_data=bpy.data.lights.new("FMPL | "+name,"AREA")
        light_data.energy=power
        light_data.shape="DISK"
        light_data.size=area_size
        ob=bpy.data.objects.new("FMPL | "+name,light_data)
        scene.collection.objects.link(ob)
        ob.location=location
        ob.rotation_euler=(target-ob.location).to_track_quat("-Z","Y").to_euler()
    scene.render.engine="CYCLES"
    scene.cycles.device="CPU"
    scene.cycles.samples=samples
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"
    scene.render.resolution_x,scene.render.resolution_y=size
    scene.render.resolution_percentage=100
    scene.render.film_transparent=False
    scene.render.fps=8
    scene.render.threads_mode="FIXED"
    scene.render.threads=4
    if scene.world is None: scene.world=bpy.data.worlds.new("FMPL | preview world")
    scene.world.use_nodes=True
    bg=scene.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value=(.12,.15,.19,1.0)
        bg.inputs["Strength"].default_value=.38
    bpy.context.view_layer.update()
    elevation=math.degrees(math.asin((obj.location-target).normalized().z))
    if abs(elevation-45)>.001 or abs(obj.location.x-target.x)>.001:
        raise RuntimeError("FMPL camera not grid-aligned fixed 45 degrees")
    return obj

def validate_loops(bpy,roots):
    scene=bpy.context.scene
    scene.frame_set(1)
    first={o.name:(tuple(o.location),tuple(o.rotation_euler),tuple(o.scale))
           for root in roots for o in root.children}
    scene.frame_set(97)
    for root in roots:
        for o in root.children:
            a=first[o.name]
            b=(tuple(o.location),tuple(o.rotation_euler),tuple(o.scale))
            if any(abs(left-right)>1e-5 for x,y in zip(a,b) for left,right in zip(x,y)):
                raise RuntimeError("Effect rig doesn't close: "+o.name)
    scene.frame_set(49)
    for root in roots:
        for ob in root.children:
            if "vapor-lobe" in ob.name and max(ob.scale.x,ob.scale.y)>.40:
                raise RuntimeError("Gas volume emitter inflated beyond reusable native dimensions: "+ob.name)
    changes=0
    for root in roots:
        for o in root.children:
            if abs(o.location.z-first[o.name][0][2])>1e-4 or abs(o.rotation_euler.z-first[o.name][1][2])>1e-4:
                changes+=1
    if changes<10: raise RuntimeError("Effect rigs not animating distinctly")
    scene.frame_set(1)
    return changes

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--catalog",required=True)
    ap.add_argument("--out",required=True)
    ap.add_argument("--render",choices=("none","proof","all"),default="all")
    ap.add_argument("--samples",type=int,default=12)
    args=ap.parse_args(sys.argv[sys.argv.index("--")+1:])
    if not 2<=args.samples<=48:
        raise ValueError("FMPL limits automated preview to 2..48 samples")
    source=Path(args.catalog).resolve()
    catalog=json.loads(source.read_text(encoding="utf-8"))
    if catalog["schema"]!="fmpl.effects.v1" or len(catalog["presets"])!=28 or len(catalog["rigs"])!=5:
        raise ValueError("Unrecognized or incomplete FMPL FX contract")
    if catalog["limits"]["default_no_simulation_bake"] is not True:
        raise RuntimeError("Cannot enable automatic simulation bake")
    out=Path(args.out).resolve()
    if out.exists() and any(out.iterdir()):
        raise FileExistsError("Refusing to overwrite existing effects output: "+str(out))
    out.mkdir(parents=True,exist_ok=True)
    import bpy
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    scene.name="FMPL EFFECT LIBRARY | native reusable sample"
    materials=create_materials(bpy,catalog)
    make_gallery(bpy,scene,materials,catalog["presets"])
    roots,rig_counts=build_animated_rigs(bpy,scene,materials,catalog["rigs"])
    set_camera(bpy,scene,catalog["capture"]["source_size"],args.samples)
    scene.frame_start=1
    scene.frame_end=96
    animated=validate_loops(bpy,roots)
    scene["fmpl_fx_registry_sha256"]=sha(source)
    scene["fmpl_fx_version"]=catalog["version"]
    scene["fmpl_fx_source_pdf_sha256"]=catalog["source_guide"]["sha256"]
    if sum(o.type=="CAMERA" for o in scene.objects)!=1:
        raise RuntimeError("One-camera policy violated")
    native=out/MASTER_NAME
    bpy.ops.wm.save_as_mainfile(filepath=str(native),check_existing=False)
    proofs=[]
    indexes=range(16) if args.render=="all" else ((0,4,8,12) if args.render=="proof" else ())
    for idx in indexes:
        frame=WORK_FRAMES[idx]
        scene.frame_set(frame)
        target=out/("proof_%02d.png"%idx)
        scene.render.filepath=str(target)
        print("FMPL_EFFECTS_RENDER",idx+1,"of",len(indexes),flush=True)
        bpy.ops.render.render(write_still=True)
        if not target.is_file() or target.stat().st_size<1024:
            raise RuntimeError("Blender did not render real preview "+str(target))
        proofs.append({"sample":idx,"timeline_frame":frame,"file":target.name,"sha256":sha(target)})
    report={"schema":"fmpl.effects.build.v1","passed":True,"library_version":catalog["version"],
            "registry_sha256":sha(source),"source_pdf_sha256":catalog["source_guide"]["sha256"],
            "blender_version":bpy.app.version_string,"material_count":len(materials),
            "material_ids":list(materials),"rig_count":len(roots),"rig_object_counts":rig_counts,
            "loop_end_frame":97,"fps":8,"animated_distinct_objects":animated,
            "one_fixed_camera":True,"camera_elevation_degrees":45.0,
            "camera_azimuth_degrees":0.0,"render_mode":args.render,
            "preview_count":len(proofs),"previews":proofs,"native_file":native.name,
            "native_sha256":sha(native),"native_reopened":False,"simulation_bake":False,
            "factorio_sprite_installed":False,"user_visual_approved":False}
    (out/"library_report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print("FMPL_EFFECTS_NATIVE_LIBRARY_BUILT",len(materials),len(roots),len(proofs),sha(native),flush=True)

if __name__=="__main__":
    main()
