"""Replace sparse/mis-seated fan with six pitched blades and a real rotor hub."""
import argparse
import json
import math
from pathlib import Path
import shutil
import sys
import bpy
from mathutils import Matrix,Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from mh7_machine_scene import sha
from mechanical_routes import mesh_object,hollow_sleeve
from verify_purifier_v14 import gap
from blender_build import uv_for_visible_surface
import refine_process as p


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source-dir',required=True);ap.add_argument('--out',required=True);args=ap.parse_args(sys.argv[sys.argv.index('--')+1:])
    src=Path(args.source_dir).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve fan repair studies')
    out.mkdir(parents=True);source=src/'crucible-v02.blend';bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(1);bpy.context.view_layer.update()
    prefix='TP Metallization Crucible V01 | ';new='TP Crucible V03 | ';col=bpy.data.collections['PROCESS']
    rotor=s.objects[prefix+'supported cooling fan rotor'];oldhub=s.objects[prefix+'cooling fan bearing hub']
    oldblades=[o for o in s.objects if 'cooling fan swept blade' in o.name]
    before=[dict(name=o.name,gap_to_old_bearing=gap(o,oldhub),radial_min=min(math.hypot((o.matrix_world@v.co).x,(o.matrix_world@v.co).z-1.08) for v in o.data.vertices)) for o in oldblades]
    for o in oldblades+[oldhub]:bpy.data.objects.remove(o,do_unlink=True)
    def material(name):return bpy.data.materials[prefix+name]
    bearing=p.cyl(col,prefix+'cooling fan bearing hub',(0,2.145,1.08),.070,.045,material('brass'),'Y')
    bearing.name=prefix+'cooling fan bearing hub'
    shaft=p.cyl(col,new+'fixed fan spindle',(0,2.20,1.08),.025,.16,material('machine_steel'),'Y')
    hub=hollow_sleeve(col,new+'six blade rotating hub',(0,0,0),(0,1,0),.070,.105,.026,material('gunmetal_dark'),64)
    hub.parent=rotor;hub.matrix_parent_inverse=Matrix.Identity(4);hub.matrix_basis=Matrix.Identity(4)
    blades=[]
    for k in range(6):
        a=math.tau*k/6;verts=[]
        for r,chord,pitch,sweep in ((.065,.050,14,0),(.17,.105,24,.08),(.29,.110,30,.16)):
            angle=a+sweep;radial=Vector((math.cos(angle),0,math.sin(angle)));tangent=Vector((-math.sin(angle),0,math.cos(angle)))
            tilt=math.radians(pitch);across=tangent*math.cos(tilt)+Vector((0,1,0))*math.sin(tilt)
            normal=Vector((0,1,0))*math.cos(tilt)-tangent*math.sin(tilt)
            for t,n in ((-1,-1),(1,-1),(1,1),(-1,1)):verts.append(tuple(radial*r+across*(t*chord/2)+normal*(n*.006)))
        faces=[(0,3,2,1),(8,9,10,11)]
        for row in (0,1):
            for i in range(4):j=(i+1)%4;faces.append((row*4+i,row*4+j,(row+1)*4+j,(row+1)*4+i))
        blade=mesh_object(col,new+'cooling fan swept blade '+str(k),verts,faces,material('machine_steel'));uv_for_visible_surface(blade)
        blade.parent=rotor;blade.matrix_parent_inverse=Matrix.Identity(4);blade.matrix_basis=Matrix.Identity(4)
        blade['actual_rotor_blade']=True;blade['hub_attachment']='root spans radius .065-.070 inside .105 rotor hub, with common rotor-local frame'
        blades.append(blade)
    washer=p.cyl(col,new+'fan spindle retaining washer',(0,2.247,1.08),.045,.018,material('brass'),'Y')
    cap=p.cyl(col,new+'fan spindle retained cap',(0,2.264,1.08),.033,.030,material('gunmetal_dark'),'Y',vertices=6)
    for o in (bearing,shaft,hub,washer,cap):
        if not o.data.uv_layers:uv_for_visible_surface(o)
    receipt=json.loads((src/'construction-receipt.json').read_text())
    def joint(a,b,label):receipt['contacts'].append(dict(a=a.name,b=b.name,label=label))
    joint(shaft,bearing,'fan spindle seated in cabinet bearing');joint(hub,bearing,'rotor hub on supported bearing face')
    joint(washer,shaft,'retaining washer held on spindle');joint(cap,shaft,'retaining cap closes spindle end')
    for blade in blades:joint(blade,hub,'pitched blade root seats into rotating hub')
    receipt.update(revision='V03 six seated pitched fan blades and proper spindle/hub',previous_source_sha256=sha(source),
        fan_revision=3,fan_blade_count=6,fan_rotor_hub=hub.name,fan_bearing=bearing.name,fan_before=before,
        fan_description='Six broad pitched blades constructed in a common rotor-local frame; roots penetrate the real rotating hub. Separate fixed cabinet bearing, spindle and retaining cap. No stale world-matrix parenting.',
        owner_correction='Fan looked sparse and a blade appeared to float free; add blades and attach them properly.')
    for name in ('port_manifest.json','part_provenance.json'):shutil.copy2(src/name,out/name)
    manifest=json.loads((out/'port_manifest.json').read_text())
    for port in manifest['ports']:
        port['interface_kind']='fluid' if port['id']=='conditioned_hydrogen_input' else 'sealed_item_transfer'
        if port['interface_kind']=='sealed_item_transfer':
            port['payload']='tp-mh7-raw-metallicized-pellet';port['native_fluid_box']=None
            port['owner_override']='Raw solid pellets leave this device; no second gameplay fluid connection.'
    (out/'port_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    shutil.copytree(src/'textures',out/'textures')
    # Packed maps are authoritative; point external paths at this local copy.
    for image in bpy.data.images:
        if image.source=='FILE' and str(src/'textures') in image.filepath:image.filepath=str(out/'textures'/Path(image.filepath).relative_to(src/'textures'))
    bpy.ops.file.pack_all();s.frame_set(25);target=out/'crucible-v03.blend';bpy.ops.wm.save_as_mainfile(filepath=str(target),check_existing=False)
    receipt['source_sha256']=sha(target);(out/'construction-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    s.render.filepath=str(out/'working-front.png');bpy.ops.render.render(write_still=True)
    print('CRUCIBLE_FAN_REBUILT',len(blades),sha(target),flush=True)


if __name__=='__main__':main()
