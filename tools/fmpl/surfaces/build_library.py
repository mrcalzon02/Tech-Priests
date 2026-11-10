#!/usr/bin/env python3
"""Build 25 original FMPL procedural surface materials in real Blender 5.x.

Source: original FMPL parametric design; cracked-mud-rocks informed by Sam
Bowman's public tutorial, not copied third-party Blender data.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import math
import sys

def digest(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def color(rgb,f=1):
    return tuple(max(.025,min(.88,v*f)) for v in rgb)+(1,)

def shader_material(bpy,rec,version):
    m=bpy.data.materials.new("FMPL SURFACE | "+rec["id"])
    m.diffuse_color=tuple(rec["base_color"])+(1,)
    m.use_nodes=True
    nodes=m.node_tree.nodes
    nodes.clear()
    ln=m.node_tree.links
    output=nodes.new("ShaderNodeOutputMaterial")
    bsdf=nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.name="FMPL SURFACE | PBR"
    ln.new(bsdf.outputs["BSDF"],output.inputs["Surface"])
    bsdf.inputs["Metallic"].default_value=rec["metallic"]
    bsdf.inputs["Roughness"].default_value=rec["roughness"]
    texture=nodes.new("ShaderNodeTexCoord")
    texture.name="FMPL | Object Coordinates"
    mapping=nodes.new("ShaderNodeMapping")
    mapping.name="FMPL | Object Mapping"
    ln.new(texture.outputs["Object"],mapping.inputs["Vector"])
    if rec["node_style"]=="wood":
        mapping.inputs["Scale"].default_value=(1.2,12.0,1.2)
    scale=nodes.new("ShaderNodeValue")
    scale.name="FMPL | Grain Frequency"
    scale.outputs[0].default_value=rec["noise_scale"]
    noise=nodes.new("ShaderNodeTexNoise")
    noise.name="FMPL | Color Variation"
    noise.inputs["Detail"].default_value=3.5
    noise.inputs["Roughness"].default_value=.63
    ln.new(mapping.outputs["Vector"],noise.inputs["Vector"])
    ln.new(scale.outputs[0],noise.inputs["Scale"])
    ramp=nodes.new("ShaderNodeValToRGB")
    ramp.name="FMPL | Base & Secondary"
    ramp.color_ramp.interpolation="EASE"
    ramp.color_ramp.elements[0].color=color(rec["secondary_color"])
    ramp.color_ramp.elements[1].color=color(rec["base_color"])
    ln.new(noise.outputs["Fac"],ramp.inputs["Fac"])
    color_output=ramp.outputs["Color"]
    bump_height=noise.outputs["Fac"]
    style=rec["node_style"]
    if style=="paving":
        brick=nodes.new("ShaderNodeTexBrick")
        brick.name="FMPL | Individually Bedded Paving"
        brick.inputs["Color1"].default_value=color(rec["base_color"],1.04)
        brick.inputs["Color2"].default_value=color(rec["base_color"],.86)
        brick.inputs["Mortar"].default_value=color(rec["secondary_color"],.42)
        brick.inputs["Mortar Size"].default_value=.023
        brick.inputs["Scale"].default_value=2.1
        ln.new(mapping.outputs["Vector"],brick.inputs["Vector"])
        color_output=brick.outputs["Color"]
        bump_height=brick.outputs["Fac"]
    elif style in {"cracked-mud","cracked-mud-rocks","cracked-rock"}:
        # Distinct masked stages correspond to the tutorial's cracked mud,
        # mud coloration, rock distribution, dark cracks and bump relief.
        vor=nodes.new("ShaderNodeTexVoronoi")
        vor.name="FMPL CRACKS | Distances To Edge"
        vor.feature="DISTANCE_TO_EDGE"
        vor.voronoi_dimensions="2D"
        vor.inputs["Scale"].default_value=rec["noise_scale"]*.55
        ln.new(mapping.outputs["Vector"],vor.inputs["Vector"])
        edges=nodes.new("ShaderNodeValToRGB")
        edges.name="FMPL CRACKS | Width & Dark Interior"
        edges.color_ramp.interpolation="EASE"
        edges.color_ramp.elements[0].position=.012
        edges.color_ramp.elements[1].position=.085 if style!="cracked-rock" else .065
        edges.color_ramp.elements[0].color=color(rec["secondary_color"],.42)
        edges.color_ramp.elements[1].color=color(rec["base_color"])
        ln.new(vor.outputs["Distance"],edges.inputs["Fac"])
        color_output=edges.outputs["Color"]
        bump_height=vor.outputs["Distance"]
        if style=="cracked-mud-rocks":
            rock=nodes.new("ShaderNodeTexVoronoi")
            rock.name="FMPL ROCKS | Seeded 2D Stone Distribution"
            rock.voronoi_dimensions="2D"
            rock.feature="F1"
            rock.inputs["Scale"].default_value=rec["noise_scale"]*.9
            ln.new(mapping.outputs["Vector"],rock.inputs["Vector"])
            mask=nodes.new("ShaderNodeValToRGB")
            mask.name="FMPL ROCKS | Stone Coverage Mask"
            mask.color_ramp.interpolation="EASE"
            mask.color_ramp.elements[0].position=.12
            mask.color_ramp.elements[0].color=(1,1,1,1)
            mask.color_ramp.elements[1].position=.33
            mask.color_ramp.elements[1].color=(0,0,0,1)
            ln.new(rock.outputs["Distance"],mask.inputs["Fac"])
            mixer=nodes.new("ShaderNodeMixRGB")
            mixer.name="FMPL ROCKS | Mud/Embedded Rock Pigment"
            mixer.blend_type="MIX"
            ln.new(mask.outputs["Color"],mixer.inputs[0])
            ln.new(color_output,mixer.inputs[1])
            mixer.inputs[2].default_value=(.39,.40,.37,1)
            color_output=mixer.outputs["Color"]
            layer=nodes.new("ShaderNodeMixRGB")
            layer.name="FMPL ROCKS | Raised Rock Bump"
            layer.blend_type="ADD"
            layer.inputs[0].default_value=.28
            ln.new(rock.outputs["Distance"],layer.inputs[1])
            ln.new(vor.outputs["Distance"],layer.inputs[2])
            bump_height=layer.outputs["Color"]
    elif style in {"pebbles","granular","metal","wood"}:
        pass
    else:
        raise ValueError("Unknown procedural node style "+style)

    bump=nodes.new("ShaderNodeBump")
    bump.name="FMPL | Restrained Physical Relief"
    bump.inputs["Strength"].default_value=.22
    bump.inputs["Distance"].default_value=rec["bump_distance"]
    ln.new(bump_height,bump.inputs["Height"])
    ln.new(bump.outputs["Normal"],bsdf.inputs["Normal"])
    roughness=nodes.new("ShaderNodeMapRange")
    roughness.name="FMPL | Surface Micro-Roughness"
    roughness.inputs["To Min"].default_value=max(.025,rec["roughness"]-.06)
    roughness.inputs["To Max"].default_value=min(.99,rec["roughness"]+.05)
    ln.new(noise.outputs["Fac"],roughness.inputs["Value"])
    ln.new(roughness.outputs["Result"],bsdf.inputs["Roughness"])
    ln.new(color_output,bsdf.inputs["Base Color"])
    m["fmpl_surface_id"]=rec["id"]
    m["fmpl_surface_version"]=version
    m["fmpl_surface_family"]=rec["family"]
    m["fmpl_surface_shader_style"]=style
    m["fmpl_surface_origin"]="FMPL original procedurally generated"
    m.asset_mark()
    return m

def make_plate(bpy,collection,name,material,xyz):
    bpy.ops.mesh.primitive_cube_add(size=1,location=xyz)
    obj=bpy.context.object
    for cl in tuple(obj.users_collection):cl.objects.unlink(obj)
    collection.objects.link(obj)
    obj.name="FMPL PLATE | "+name
    obj.scale=(1.05,1.05,.105)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bevel=obj.modifiers.new("FMPL | safe tile bevel","BEVEL")
    bevel.width=.025
    bevel.segments=2
    obj.modifiers.new("FMPL | weighted normals","WEIGHTED_NORMAL")
    obj.data.materials.append(material)
    obj["fmpl_surface_plate_id"]=name
    return obj

def make_label(bpy,collection,text,location):
    curve=bpy.data.curves.new("FMPL SURFACE | label","FONT")
    curve.body=text.replace("-"," ")[:22]
    curve.size=.11
    obj=bpy.data.objects.new("LABEL | "+text,curve)
    collection.objects.link(obj)
    obj.location=location
    return obj

def camera_and_light(bpy,scene):
    from mathutils import Vector
    target=Vector((0,0,.05))
    cam=bpy.data.cameras.new("FMPL | canonical 45 degree lens")
    cam.type="ORTHO"
    cam.ortho_scale=10.2
    obj=bpy.data.objects.new("FMPL | stationary 45 degree surface camera",cam)
    scene.collection.objects.link(obj)
    obj.location=target+Vector((0,-11,11))
    obj.rotation_euler=(target-obj.location).to_track_quat("-Z","Y").to_euler()
    scene.camera=obj
    for name,position,energy in [
        ("warm daylight",(-4,-5,9),1200),
        ("cool fill",(5,4,9),850)]:
        data=bpy.data.lights.new("FMPL | "+name,"AREA")
        data.energy=energy
        data.shape="DISK"
        data.size=8
        light=bpy.data.objects.new("FMPL | "+name,data)
        scene.collection.objects.link(light)
        light.location=position
        light.rotation_euler=(target-light.location).to_track_quat("-Z","Y").to_euler()
    scene["fmpl_surface_camera_target"]=list(target)
    direction=(obj.location-target).normalized()
    if abs(math.degrees(math.asin(direction.z))-45)>.001 or abs(direction.x)>.0001:
        raise RuntimeError("Camera is not exactly 45-degree zero-azimuth")
    return obj

def main():
    arg=argparse.ArgumentParser()
    arg.add_argument("--catalog",required=True)
    arg.add_argument("--out",required=True)
    arg.add_argument("--samples",type=int,default=12)
    args=arg.parse_args(sys.argv[sys.argv.index("--")+1:])
    if not (2<=args.samples<=40):raise ValueError("Samples outside bounded native proof")
    catalog_path=Path(args.catalog).resolve()
    reg=json.loads(catalog_path.read_text(encoding="utf-8"))
    if reg.get("schema")!="fmpl.surfaces.v1" or len(reg.get("presets",[]))!=25:
        raise ValueError("Unexpected FMPL 25-surface registry")
    output=Path(args.out).resolve()
    if output.exists() and any(output.iterdir()):
        raise FileExistsError("Never overwrite preexisting FMPL surface native art")
    output.mkdir(parents=True,exist_ok=True)
    import bpy
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    scene.name="FMPL | Procedural Surface Asset Library"
    collection=bpy.data.collections.new("FMPL SURFACES | native material swatches")
    scene.collection.children.link(collection)
    actual=[]
    for i,preset in enumerate(reg["presets"]):
        m=shader_material(bpy,preset,reg["version"])
        x=(i%5-2)*1.50
        y=(2-i//5)*1.50
        make_plate(bpy,collection,preset["id"],m,(x,y,.06))
        make_label(bpy,collection,preset["id"],(x-.5,y-.69,.10))
        actual.append(preset["id"])
    camera_and_light(bpy,scene)
    scene.render.engine="CYCLES"
    scene.cycles.device="CPU"
    scene.cycles.samples=args.samples
    scene.render.resolution_x=reg["render"]["size"][0]
    scene.render.resolution_y=reg["render"]["size"][1]
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"
    scene.render.film_transparent=False
    scene.render.threads_mode="FIXED"
    scene.render.threads=4
    scene.world=bpy.data.worlds.new("FMPL Surfaces | World")
    scene.world.use_nodes=True
    b=scene.world.node_tree.nodes.get("Background")
    if b:
        b.inputs["Color"].default_value=(.17,.18,.19,1)
        b.inputs["Strength"].default_value=.6
    scene.frame_set(1)
    scene["fmpl_surface_catalog_sha256"]=digest(catalog_path)
    scene["fmpl_surface_catalog_version"]=reg["version"]
    master=output/"FMPL_surfaces_v1.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(master),check_existing=False)
    proof=output/"FMPL_surfaces_25_material_proof.png"
    scene.render.filepath=str(proof)
    print("FMPL_SURFACE_RENDER_GALLERY_START",flush=True)
    bpy.ops.render.render(write_still=True)
    if not proof.is_file() or proof.stat().st_size<1024:
        raise RuntimeError("No genuine Blender proof rendered")
    report={"schema":"fmpl.surface-build.v1","passed":True,
           "library_version":reg["version"],"candidate_count":len(actual),
           "surface_ids":actual,"native_file":master.name,"native_sha256":digest(master),
           "catalog_sha256":digest(catalog_path),"proof_file":proof.name,"proof_sha256":digest(proof),
           "blender":bpy.app.version_string,"camera_pitch":45,"camera_azimuth":0,
           "simulation_bake":False,"game_integrated":False,"visual_approved":False}
    (output/"surface_report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print("FMPL_SURFACE_NATIVE_GALLERY_COMPLETE",len(actual),digest(master),flush=True)

if __name__=="__main__":
    main()
