"""V15 finishing from actual V14 source: native steam and baked interchange.

Never rewrites previous revisions. The native Blender source retains true
volume steam. The GLB's unsupported volume remains an explicit open gate.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import bpy

sys.path.insert(0,str(Path(__file__).resolve().parent))
from bake_procedural_pbr import bake_object
from camera_profile import audit_scene
from pipe_bore_clearance import verify_bores
from refine_process import hash_original_meshes

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--source',required=True)
    ap.add_argument('--out',required=True); ap.add_argument('--expected-sha',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:])
    src=Path(args.source).resolve(); out=Path(args.out).resolve()
    if sha(src)!=args.expected_sha: raise ValueError('Wrong V14 source bytes')
    if out.exists(): raise FileExistsError('Keep older studies immutable')
    out.mkdir(parents=True)
    bpy.ops.wm.open_mainfile(filepath=str(src)); s=bpy.context.scene; s.frame_set(25)
    originals=[o for o in s.objects if o.type=='MESH' and o.name.startswith(('MH7_','FMPL_PROCESS |'))]
    frozen=hash_original_meshes(originals)
    col=bpy.data.collections.new('TP | V15 native source-safe steam finish'); s.collection.children.link(col)
    steam=[o for o in s.objects if not o.hide_render and o.type=='MESH' and
           o.data.materials and o.data.materials[0] and 'relief steam irregular feathered wisps' in o.data.materials[0].name]
    if len(steam)!=12: raise ValueError('Unexpected steam source census')
    mat=steam[0].data.materials[0].copy(); mat.name='TP Purifier V15 | density-bounded native relief steam'
    nd=mat.node_tree.nodes
    nd['FMPL STEAM | noise-dithered radial density'].inputs['To Min'].default_value=3.65
    nd['FMPL STEAM | bounded core lift linked to density'].inputs[1].default_value=.125
    for original in steam:
        ob=original.copy(); ob.data=original.data.copy(); col.objects.link(ob)
        ob.name='TP_MH7_V15 | '+original.name; ob.hide_render=False
        ob.data.materials[0]=mat; original.hide_render=True
        ob['derives_from']=original.name; ob['source_sha256']=sha(src)
    if hash_original_meshes(originals)!=frozen: raise RuntimeError('Source geometry changed')
    camera=audit_scene(s,bpy); bore=verify_bores(s)
    if not bore['passed']: raise RuntimeError('Native pipe obstruction')
    s.render.engine='CYCLES'; s.cycles.device='CPU'; s.cycles.samples=24; s.cycles.seed=4359
    s.render.resolution_x=512; s.render.resolution_y=512; s.render.resolution_percentage=100
    s.render.film_transparent=True; s.render.use_compositing=False
    s.render.image_settings.file_format='PNG'; s.render.image_settings.color_mode='RGBA'
    native=out/'water-purifier-v15.blend'; bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(native),check_existing=False)
    for state,frame in (('idle',1),('working',25)):
        s.frame_set(frame); s.render.filepath=str(out/(state+'.png')); bpy.ops.render.render(write_still=True)
    # The actual native source above is immutable on disk. Bake only in this
    # separate interchange derivative, retaining animation and bounds.
    s.frame_set(25); baked=[]
    names=('purifier raw-water olive-amber','purifier clean-water luminous cyan','FMPL FX | glass-clear')
    candidates=[o for o in s.objects if o.type=='MESH' and not o.hide_render and len(o.data.materials)==1 and
                o.data.materials[0] and any(t in o.data.materials[0].name for t in names)]
    for ob in candidates:
        baked.append(bake_object(ob,out/'baked-textures',256))
        print('BAKED_SURFACE',ob.name,flush=True)
    bpy.ops.file.pack_all()
    interchange=out/'water-purifier-v15-interchange.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(interchange),check_existing=False)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in s.objects:
        if (ob.type=='MESH' and not ob.hide_render) or ob.type=='EMPTY': ob.select_set(True)
    glb=out/'water-purifier-v15.glb'
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,
        export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,
        export_materials='EXPORT',export_image_format='AUTO',export_texcoords=True,export_normals=True)
    receipt=dict(status='native finish and baked-surface candidate; volume GLB open',
        input_sha256=sha(src),native_sha256=sha(native),interchange_sha256=sha(interchange),glb_sha256=sha(glb),
        source_geometry_digest=frozen,source_geometry_preserved=True,camera=camera,bores=bore,
        native_steam=dict(source_core_density=3.10,derived_core_density=3.65,source_lift=.112,derived_lift=.125,
                          source_objects_preserved=12),baked_surfaces=baked,
        pending=['independent native reopen','idle/working steam gate','baked GLB reimport/material inspection',
                 'unsupported volume export','remaining service-line fitting work','prototype/pipe jig'])
    (out/'finish-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print('V15_FINISH_SAVED',native,flush=True)

if __name__=='__main__': main()
