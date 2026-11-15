"""Reimport an existing GLB; measure it and render under native camera/lights."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Matrix,Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from refine_purifier_v14 import bounds
from pipe_bore_clearance import verify_bores
from camera_profile import audit_scene

def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--native',required=True)
    ap.add_argument('--glb',required=True); ap.add_argument('--out',required=True)
    ap.add_argument('--generic-native-camera',action='store_true')
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:])
    native=Path(args.native).resolve(); glb=Path(args.glb).resolve(); out=Path(args.out).resolve()
    if out.exists(): raise FileExistsError('Keep previous inspection evidence')
    out.mkdir(parents=True)
    bpy.ops.wm.open_mainfile(filepath=str(native)); s=bpy.context.scene; s.frame_set(25)
    if args.generic_native_camera:
        cam=s.camera
        if cam is None or cam.data.type!='ORTHO' or len([o for o in s.objects if o.type=='CAMERA'])!=1:
            raise RuntimeError('Expected one actual orthographic source camera')
        direction=cam.matrix_world.to_3x3() @ Vector((0,0,1))
        if (direction-Vector((0,-math.sqrt(.5),math.sqrt(.5)))).length>.0001:
            raise RuntimeError('Source camera is not the canonical 45-degree grid view')
        camera=dict(name=cam.name,matrix_world=[list(r) for r in cam.matrix_world],ortho_scale=cam.data.ortho_scale)
    else: camera=audit_scene(s,bpy)
    native_bounds=bounds([o for o in s.objects if o.type=='MESH' and not o.hide_render])
    lights=[dict(name=o.name,type=o.data.type,energy=o.data.energy,color=list(o.data.color),
          size=getattr(o.data,'size',1.),matrix=[list(r) for r in o.matrix_world]) for o in s.objects if o.type=='LIGHT']
    bg=s.world.node_tree.nodes.get('Background') if s.world and s.world.use_nodes else None
    background=(list(bg.inputs['Color'].default_value),float(bg.inputs['Strength'].default_value)) if bg else ([.1,.1,.1,1.],1.)
    view={k:getattr(s.view_settings,k) for k in ('view_transform','look','exposure','gamma')}
    bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.gltf(filepath=str(glb)); s=bpy.context.scene; s.frame_set(25)
    meshes=[o for o in s.objects if o.type=='MESH']; imported_bounds=bounds(meshes)
    triangles=0; degenerates=0; nonfinite=0; missing=[]
    for ob in meshes:
        ob.data.calc_loop_triangles(); triangles+=len(ob.data.loop_triangles)
        degenerates+=sum(t.area<1e-12 for t in ob.data.loop_triangles)
        nonfinite+=sum(not all(math.isfinite(c) for c in v.co) for v in ob.data.vertices)
        if not ob.data.uv_layers: missing.append(ob.name)
    if args.generic_native_camera:
        from audit_electrolyzer_v01 import port_probe
        manifest_path=native.parent/'port_manifest.json'
        if not manifest_path.is_file():raise RuntimeError('Generic inspection requires the actual asset port manifest')
        bores=port_probe(s,json.loads(manifest_path.read_text())['ports'])
    else:bores=verify_bores(s)
    raw=glb.read_bytes(); doc=json.loads(raw[20:20+int.from_bytes(raw[12:16],'little')])
    materials=[dict(name=m.get('name'),base_color_texture='baseColorTexture' in m.get('pbrMetallicRoughness',{}),
                   metallic_roughness_texture='metallicRoughnessTexture' in m.get('pbrMetallicRoughness',{}),
                   normal_texture='normalTexture' in m,extensions=list(m.get('extensions',{}))) for m in doc.get('materials',[])]
    camdata=bpy.data.cameras.new('Native source camera'); camdata.type='ORTHO'; camdata.ortho_scale=camera['ortho_scale']
    cam=bpy.data.objects.new('Native source camera',camdata); s.collection.objects.link(cam); s.camera=cam
    cam.matrix_world=Matrix(camera['matrix_world'])
    for item in lights:
        data=bpy.data.lights.new(item['name'],item['type']); data.energy=item['energy']; data.color=item['color']
        if hasattr(data,'size'): data.size=item['size']
        ob=bpy.data.objects.new(item['name'],data); ob.matrix_world=Matrix(item['matrix']); s.collection.objects.link(ob)
    s.world=bpy.data.worlds.new('Actual source world'); s.world.use_nodes=True
    b=s.world.node_tree.nodes.get('Background'); b.inputs['Color'].default_value=background[0]; b.inputs['Strength'].default_value=background[1]
    for key,value in view.items(): setattr(s.view_settings,key,value)
    s.render.engine='CYCLES'; s.cycles.device='CPU'; s.cycles.samples=24; s.cycles.seed=4359
    s.render.resolution_x=512; s.render.resolution_y=512; s.render.resolution_percentage=100
    s.render.image_settings.file_format='PNG'; s.render.image_settings.color_mode='RGBA'; s.render.film_transparent=True
    s.render.filepath=str(out/'front.png'); bpy.ops.render.render(write_still=True)
    front_position=Vector((camera['matrix_world'][i][3] for i in range(3)))
    target_z=front_position.z-abs(front_position.y)
    cam.location=(0,abs(front_position.y),front_position.z)
    cam.rotation_euler=(Vector((0,0,target_z))-cam.location).to_track_quat('-Z','Y').to_euler()
    s.render.filepath=str(out/'rear-inspection.png'); bpy.ops.render.render(write_still=True)
    cam.matrix_world=Matrix(camera['matrix_world'])
    clay=bpy.data.materials.new('Neutral inspection clay'); clay.use_nodes=True
    clay.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.3,.3,.3,1)
    clay.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.7
    s.view_layers[0].material_override=clay
    s.render.filepath=str(out/'clay.png'); bpy.ops.render.render(write_still=True)
    error=max(abs(native_bounds[i][j]-imported_bounds[i][j]) for i in range(2) for j in range(3))
    report=dict(native_sha256=sha(native),glb_sha256=sha(glb),meshes=len(meshes),triangles=triangles,
        degenerate_triangles=degenerates,nonfinite_vertices=nonfinite,missing_UV=missing,
        bounds_error=error,bores=bores,material_channels=materials,
        geometry_passed=not degenerates and not nonfinite and not missing and error<.002 and bores['passed'],
        render_sha256={p.name:sha(p) for p in out.glob('*.png')},visual_approval=False,
        note='Rear is a diagnostic inspection view. Accepted capture directions belong to the asset capture manifest; volume parity requires separate assessment where present.')
    (out/'export-inspection.json').write_text(json.dumps(report,indent=2)+'\n')
    print('EXISTING_EXPORT_INSPECTED',report['geometry_passed'],flush=True)

if __name__=='__main__': main()
