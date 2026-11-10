#!/usr/bin/env python3
"""FMPL: create genuine Blender Cycles samples of EVERY canonical material record.

23 pinned industrial PBR + 28 effects + 25 procedural surfaces. Original
source Blender scenes and image maps remain unchanged; no game sprite claims.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import re
import sys

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def load_python(path,name):
    spec=importlib.util.spec_from_file_location(name,str(path))
    if spec is None or spec.loader is None:raise ImportError("Cannot load source script "+str(path))
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

def build_materials(bpy,repo):
    industrial=repo/"art/source-to-3d/shared-parts/industrial-asset-library"
    effects=repo/"tools/fmpl/effects"
    surfaces=repo/"tools/fmpl/surfaces"
    for path in (industrial/"catalog.json",industrial/"import_materials.py",
                 effects/"presets.json",effects/"build_library.py",
                 surfaces/"catalog.json",surfaces/"build_library.py"):
        if not path.is_file():raise FileNotFoundError("Authoritative FMPL material source missing: "+str(path))
    pbr_data=json.loads((industrial/"catalog.json").read_text(encoding="utf-8"))
    fx_data=json.loads((effects/"presets.json").read_text(encoding="utf-8"))
    surf_data=json.loads((surfaces/"catalog.json").read_text(encoding="utf-8"))
    if (len(pbr_data["materials"]),len(fx_data["presets"]),len(surf_data["presets"]))!=(23,28,25):
        raise ValueError("Expected all 76 canonical materials; do not silently reduce the scope")
    pbr=load_python(industrial/"import_materials.py","fmpl_original_23_pbr")
    fx=load_python(effects/"build_library.py","fmpl_original_28_fx")
    surf=load_python(surfaces/"build_library.py","fmpl_original_25_surfaces")
    pbr_mat=pbr.import_materials(repo,pack=True)
    fx_mat=fx.create_materials(bpy,fx_data)
    result=[]
    for item in pbr_data["materials"]:
        ident=item["material_id"]
        mat=pbr_mat[ident]
        result.append({"id":ident,"family":"industrial-pbr","kind":"texture-backed",
            "source":"art/source-to-3d/shared-parts/industrial-asset-library/catalog.json",
            "source_commit":pbr_data.get("source_commit"),"material_name":mat.name,
            "source_map_count":len(item["maps"]),"material":mat,
            "source_version":"23-pbr-maps"})
    for item in fx_data["presets"]:
        ident=item["id"]
        result.append({"id":ident,"family":item["family"],"kind":"procedural-effect",
            "source":"tools/fmpl/effects/presets.json","source_version":fx_data["version"],
            "material_name":fx_mat[ident].name,"material":fx_mat[ident],
            "render_tier":item["performance"],"chemical_transmission":item["transmission"]
            if item["family"]=="chemical-liquid" else None})
    for item in surf_data["presets"]:
        ident=item["id"]
        mat=surf.shader_material(bpy,item,surf_data["version"])
        result.append({"id":ident,"family":item["family"],"kind":"procedural-surface",
            "source":"tools/fmpl/surfaces/catalog.json","source_version":surf_data["version"],
            "material_name":mat.name,"material":mat,"node_style":item["node_style"]})
    for item in result:
        mat=item["material"]
        mat.use_fake_user=True
        if getattr(mat,"asset_data",None) is None:mat.asset_mark()
    return result,{"pbr":pbr_data["source_commit"],"fx":fx_data["version"],
                   "surfaces":surf_data["version"],
                   "catalog_sha256":{
                     "industrial":sha(industrial/"catalog.json"),
                     "effects":sha(effects/"presets.json"),
                     "surfaces":sha(surfaces/"catalog.json")}}

def add_sphere(bpy,collection,name,position,material,radius=.33):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=28,ring_count=16,radius=radius,location=position)
    obj=bpy.context.object
    for source in tuple(obj.users_collection):source.objects.unlink(obj)
    collection.objects.link(obj)
    obj.name=name
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:polygon.use_smooth=True
    return obj

def make_label(bpy,collection,title,position):
    data=bpy.data.curves.new("FMPL | sample label","FONT")
    data.body=title.replace("_"," ").replace("-"," ")[:23]
    data.size=.092
    obj=bpy.data.objects.new("LABEL | "+title,data)
    collection.objects.link(obj)
    obj.location=position

def setup_lighting(bpy,scene):
    from mathutils import Vector
    camera=bpy.data.cameras.new("FMPL | true fixed 45 lens")
    camera.type="ORTHO"
    camera.ortho_scale=12.4
    cam=bpy.data.objects.new("FMPL | one true 45 degree production camera",camera)
    scene.collection.objects.link(cam)
    target=Vector((0,0,.25))
    cam.location=target+Vector((0,-10.0,10.0))
    cam.rotation_euler=(target-cam.location).to_track_quat("-Z","Y").to_euler()
    scene.camera=cam
    for name,point,power,size,color in (
        ("warm work light",(-6,-5,8),1250,7,(1.0,.91,.75)),
        ("cool fill",(4,5,9),1000,9,(.65,.78,1.0))):
        lamp=bpy.data.lights.new("FMPL | "+name,"AREA")
        lamp.energy=power;lamp.shape="DISK";lamp.size=size;lamp.color=color
        obj=bpy.data.objects.new("FMPL | "+name,lamp)
        scene.collection.objects.link(obj)
        obj.location=point
        obj.rotation_euler=(target-obj.location).to_track_quat("-Z","Y").to_euler()
    scene.world=bpy.data.worlds.new("FMPL | neutral swatch world")
    scene.world.use_nodes=True
    bg=scene.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value=(.14,.15,.17,1)
        bg.inputs["Strength"].default_value=.52
    scene.render.engine="CYCLES"
    scene.cycles.samples=12
    scene.cycles.device="CPU"
    scene.render.film_transparent=False
    scene.render.threads_mode="FIXED"
    scene.render.threads=4
    scene.render.image_settings.file_format="PNG"
    scene.render.image_settings.color_mode="RGBA"
    scene.render.resolution_percentage=100
    scene.render.fps=8
    direction=(cam.location-target).normalized()
    if abs(math.degrees(math.asin(direction.z))-45)>.001 or abs(direction.x)>.001:
        raise RuntimeError("FMPL production camera pitch or yaw incorrect")
    return cam

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--fmpl",required=True)
    ap.add_argument("--out",required=True)
    ap.add_argument("--render-individual",action="store_true")
    ap.add_argument("--samples",type=int,default=12)
    a=ap.parse_args(sys.argv[sys.argv.index("--")+1:])
    if not 2<=a.samples<=32:raise ValueError("Bounded Cycles samples 2..32 only")
    out=Path(a.out).resolve()
    if out.exists() and any(out.iterdir()):raise FileExistsError("Material gallery refuses overwrite: "+str(out))
    out.mkdir(parents=True,exist_ok=True)
    repo=Path(a.fmpl).resolve()
    import bpy
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene
    scene.name="FMPL | ALL MATERIALS | 76 authoritative samples"
    materials,origins=build_materials(bpy,repo)
    if len(materials)!=76:raise RuntimeError("Expected 76 actual material datablocks")
    keys={(v["kind"],v["id"]) for v in materials}
    if len(keys)!=76:raise RuntimeError("Material catalog ID collision")
    grid=bpy.data.collections.new("FMPL GALLERY | visible material swatches")
    scene.collection.children.link(grid)
    singles=bpy.data.collections.new("FMPL GALLERY | one material preview")
    scene.collection.children.link(singles)
    for idx,item in enumerate(materials):
        col=idx%8
        row=idx//8
        x=(col-3.5)*1.12
        y=(4.5-row)*1.06
        obj=add_sphere(bpy,grid,"FMPL SWATCH | "+item["kind"]+" | "+item["id"],(x,y,.35),item["material"])
        obj["fmpl_gallery_material_id"]=item["id"]
        obj["fmpl_gallery_family"]=item["family"]
        make_label(bpy,grid,item["id"],(x-.40,y-.49,.05))
    sample=add_sphere(bpy,singles,"FMPL | one independently viewable material",(0,0,.39),materials[0]["material"],radius=.38)
    singles.hide_render=True
    camera=setup_lighting(bpy,scene)
    scene.cycles.samples=a.samples
    scene["fmpl_gallery_source_versions"]=json.dumps(origins,sort_keys=True)
    scene["fmpl_gallery_total"]=len(materials)
    scene["fmpl_gallery_capture_pitch"]=45.0
    scene.frame_set(1)
    master=out/"FMPL_gallery_76_materials.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(master),check_existing=False)
    scene.render.resolution_x=2400
    scene.render.resolution_y=2400
    whole=out/"FMPL_gallery_all_76.png"
    scene.render.filepath=str(whole)
    print("FMPL_GALLERY_76_MATERIAL_CONTACT_START",flush=True)
    bpy.ops.render.render(write_still=True)
    if not whole.is_file() or whole.stat().st_size<10000:
        raise RuntimeError("No genuine Blender 76-material proof")
    gallery_sha=sha(whole)
    renders=[]
    if a.render_individual:
        grid.hide_render=True
        singles.hide_render=False
        camera.data.ortho_scale=1.7
        scene.render.resolution_x=448
        scene.render.resolution_y=448
        samples=out/"samples"
        samples.mkdir()
        for idx,item in enumerate(materials):
            sample.data.materials.clear()
            sample.data.materials.append(item["material"])
            safe=re.sub("[^a-z0-9_-]+","-",item["id"].lower())
            filename="%02d_%s_%s.png"%(idx,item["kind"],safe)
            target=samples/filename
            scene.render.filepath=str(target)
            scene.frame_set(1)
            print("FMPL_GALLERY_RENDER_MATERIAL",idx+1,"of",len(materials),item["kind"],item["id"],flush=True)
            bpy.ops.render.render(write_still=True)
            if not target.is_file() or target.stat().st_size<1024:
                raise RuntimeError("Material sample render missing: "+filename)
            renders.append({"kind":item["kind"],"id":item["id"],"family":item["family"],
                            "source":item["source"],"source_version":item.get("source_version"),
                            "material_datablock":item["material_name"],
                            "native_render":str(target.relative_to(out)).replace("\\","/"),
                            "render_sha256":sha(target),"status":"rendered",
                            "candidate_not_user_approved":True})
        grid.hide_render=False
        singles.hide_render=True
        camera.data.ortho_scale=12.4
    report={"schema":"fmpl.gallery-materials.v1","passed":True,"blender":bpy.app.version_string,
            "material_count":len(materials),"pbr_count":23,"effects_count":28,"surfaces_count":25,
            "source_versions":origins,"contact_file":whole.name,"contact_sha256":gallery_sha,
            "individual_render_count":len(renders),"individuals":renders,
            "master_file":master.name,"master_sha256":sha(master),
            "camera_pitch_deg":45,"camera_azimuth_deg":0,
            "no_source_overwrites":True,"game_installed":False,"user_approved":False}
    (out/"materials_report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print("FMPL_GALLERY_ALL_MATERIALS_RENDER_PASS",len(materials),len(renders),flush=True)

if __name__=="__main__":
    main()
