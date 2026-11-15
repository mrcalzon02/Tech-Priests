"""Bounded construction repair: open the actual water tee and band entries."""
import argparse
import json
import math
from pathlib import Path
import shutil
import sys
import bpy
import bmesh

sys.path.insert(0,str(Path(__file__).resolve().parent))
from refine_purifier_v14 import sha
from mechanical_routes import hollow_route
import refine_process as p
from blender_build import uv_for_visible_surface


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source-dir',required=True)
    ap.add_argument('--out',required=True)
    ap.add_argument('--gas-clearance',action='store_true')
    ap.add_argument('--level-water-feed',action='store_true')
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:])
    src=Path(args.source_dir).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Retain previous repair studies')
    out.mkdir(parents=True)
    source=src/'electrolyzer-v01.blend'
    bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene;s.frame_set(25)
    prefix='TP_ELECTROLYZER_V01 | ';cuts=[]
    if args.level_water_feed:
        names=['common liquid water trunk','separate water feed branch -0.62',
               'separate water feed branch 0.62','raw water full-size feed reducer']
        first=bpy.data.objects[prefix+names[0]];col=first.users_collection[0];material=first.data.materials[0]
        for name in names:bpy.data.objects.remove(bpy.data.objects[prefix+name],do_unlink=True)
        hollow_route(col,prefix+'common liquid water trunk',[(0,-1.15,.55),(0,-.65,.55)],.09,.0648,material)
        for x in (-.62,.62):
            hollow_route(col,prefix+'separate water feed branch '+str(x),[(0,-.65,.55),(x,-.65,.55),(x,-.38,.55)],.07,.0504,material)
        reducer=p.cast_reducing_manifold(col,prefix+'raw water full-size feed reducer',
            (0,-1.70,.36),(0,-1.15,.55),.285,.09,material,face_normal_at_start=(0,1,0),face_normal_at_end=(0,1,0))
        reducer.name=prefix+'raw water full-size feed reducer';uv_for_visible_surface(reducer)
    tee_z=.55 if args.level_water_feed else .50
    def drill(label,target,center,radius,depth,axis):
        ob=bpy.data.objects[prefix+target]
        bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=radius,depth=depth,location=center)
        cutter=bpy.context.object
        if axis=='X':cutter.rotation_euler.y=math.pi/2
        if axis=='Y':cutter.rotation_euler.x=math.pi/2
        bpy.context.view_layer.objects.active=ob
        mod=ob.modifiers.new(label,'BOOLEAN');mod.operation='DIFFERENCE'
        mod.solver='EXACT';mod.object=cutter
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(cutter,do_unlink=True)
        bm=bmesh.new();bm.from_mesh(ob.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
        bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
        bm.to_mesh(ob.data);bm.free();ob.data.update()
        ob['v02_repair']=label
        cuts.append(dict(object=ob.name,operation=label,center=center,radius=radius,depth=depth,axis=axis))
    drill('True transverse tee bore','common liquid water trunk',(0,-.65,tee_z),.051,.34,'X')
    for i,x in enumerate((-.62,.62),1):
        drill('True incoming tee bore','separate water feed branch '+str(x),(0,-.65,tee_z),.065,.36,'Y')
        drill('Pressure band drilled to actual water nozzle','seated pressure band '+str((i,.55)),(x,-.38,.55),.051,.30,'Y')
        if args.level_water_feed:
            drill('Water nozzle lower quadrant clearance','cell bottom pressure closure '+str(i),(x,-.38,.55),.051,.30,'Y')
    if args.gas_clearance:
        for sign,x in ((-1,-.62),(1,.62)):
            name=prefix+('hydrogen' if sign<0 else 'oxygen')+' independent upper gas header'
            old=bpy.data.objects[name];col=old.users_collection[0];material=old.data.materials[0]
            bpy.data.objects.remove(old,do_unlink=True)
            side=sign*1.33
            hollow_route(col,name,[(x,0,2.08),(x,0,2.38),(side,0,2.38),(side,.5,2.38),
                (side,.5,.96),(sign*.65,.5,.96),(sign*.65,.5,.64),(sign*.92,.5,.64)],.070,.0504,material)
            # Valve spindle terminates in the bonnet, outside the flow bore.
            spindle=bpy.data.objects[prefix+'gas valve operating spindle '+str(sign)]
            spindle.location.y=.35;spindle.dimensions.y=.14
            wheel=bpy.data.objects[prefix+'gas isolation handwheel '+str(sign)]
            wheel.location.y=.275
            cuts.append(dict(operation='wider lower gas return and bonnet-seated stem',sign=sign,
                             stem_front_back=[.28,.42],route=name))
    # Preserve source placement, camera, actions and material instances.
    bpy.ops.file.pack_all();target=out/'electrolyzer-v01.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(target),check_existing=False)
    for name in ('port_manifest.json','part_provenance.json'):
        shutil.copy2(src/name,out/name)
    report=dict(status='candidate_native; independent repair readback pending',
                source_sha256=sha(source),native_sha256=sha(target),revision='V02 water-path repair',
                operations=cuts,scope='Demonstrated water and optional gas path repairs; fixed camera/ports/actions',
                pending=['independent water core/route check','source and actual export renders','electrical/support audit','finishing and animation','native prototype'])
    (out/'construction-receipt.json').write_text(json.dumps(report,indent=2)+'\n')
    s.render.filepath=str(out/'working-front.png');bpy.ops.render.render(write_still=True)
    print('ELECTROLYZER_V02_SAVED',sha(target),flush=True)


if __name__=='__main__':main()
