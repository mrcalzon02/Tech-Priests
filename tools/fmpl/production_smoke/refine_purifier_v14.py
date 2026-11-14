"""Source-preserving V14 console and drive-support pilot, not runtime approval.

Requires the actual V13 artifact. New objects use model-local copies of packed
FMPL PBR materials. No source mesh/transform, camera, fluid mouth or action is
rewritten. Run via Blender --background --factory-startup --python ... -- ...
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
import refine_process as p
from blender_build import uv_for_visible_surface
from camera_profile import audit_scene
from pipe_bore_clearance import verify_bores

PREFIX='TP_MH7_V14 | '

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def bounds(objects):
    vs=[o.matrix_world @ Vector(c) for o in objects for c in o.bound_box]
    return [[min(v[i] for v in vs) for i in range(3)],
            [max(v[i] for v in vs) for i in range(3)]]

def tree(ob):
    dg=bpy.context.evaluated_depsgraph_get()
    ev=ob.evaluated_get(dg)
    me=ev.to_mesh()
    try:
        return BVHTree.FromPolygons([ob.matrix_world @ v.co for v in me.vertices],
                                   [list(f.vertices) for f in me.polygons])
    finally:
        ev.to_mesh_clear()

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--source',required=True)
    ap.add_argument('--out-dir',required=True)
    ap.add_argument('--expected-sha',required=True)
    ap.add_argument('--samples',type=int,default=24)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:])
    src=Path(args.source).resolve(); out=Path(args.out_dir).resolve()
    if sha(src)!=args.expected_sha: raise RuntimeError('V13 source hash mismatch')
    out.mkdir(parents=True,exist_ok=True)
    target=out/'water-purifier-v14.blend'
    if target.exists(): raise FileExistsError('Use a new revision directory')
    bpy.ops.wm.open_mainfile(filepath=str(src))
    s=bpy.context.scene; s.frame_set(25)
    original=[o for o in s.objects if o.type=='MESH' and o.name.startswith('MH7_')]
    process=[o for o in s.objects if o.type=='MESH' and o.name.startswith('FMPL_PROCESS |')]
    frozen=p.hash_original_meshes(original+process)
    if len(original)!=50 or len(process)!=504: # 136 source + 368 V13 derivative
        raise RuntimeError(f'Unexpected V13 census {len(original)} + {len(process)}')
    camera=audit_scene(s,bpy)
    col=bpy.data.collections.new('TP | MH7 V14 source-safe mechanical repair')
    s.collection.children.link(col)
    mats={}
    for key in ('machine_steel','iron','brass','martian_red','gunmetal_dark','dark_recess'):
        m=bpy.data.materials['TP Library | '+key].copy()
        m.name='TP Water Purifier V14 | '+key
        if m.asset_data: m.asset_clear()
        m['surface_plan']='inherited packed FMPL PBR; physical planar tile UV on new metal'
        mats[key]=m
    added=[]
    def take(o,role):
        o.name=PREFIX+role
        o['part_id']='tp.mh7.v14.'+role.replace(' ','-')
        o['source_revision']='V13 artifact 13781794050'
        uv_for_visible_surface(o)
        added.append(o)
        return o
    def block(label,loc,size,mat='machine_steel',bevel=.008):
        return take(p.block(col,label,loc,size,mats[mat],bevel),label)
    def tube(label,a,b,r,inner,mat='machine_steel'):
        a,b=Vector(a),Vector(b)
        axis=(b-a).normalized(); u=axis.cross(Vector((0,0,1)))
        if u.length<.01: u=axis.cross(Vector((0,1,0)))
        u.normalize(); v=axis.cross(u).normalized(); n=32
        vs=[tuple(c+rad*(u*math.cos(math.tau*i/n)+v*math.sin(math.tau*i/n)))
            for c,rad in ((a,r),(b,r),(a,inner),(b,inner)) for i in range(n)]
        fs=[]
        for i in range(n):
            j=(i+1)%n
            fs.extend(((i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),
                       (i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)))
        me=bpy.data.meshes.new(label+' hollow fitting mesh'); me.from_pydata(vs,[],fs); me.update()
        ob=bpy.data.objects.new(label,me); col.objects.link(ob); me.materials.append(mats[mat])
        return take(ob,label)
    def beam(label,a,b,width,depth,mat='martian_red'):
        a,b=Vector(a),Vector(b)
        ob=block(label,(a+b)/2,(width,depth,(b-a).length),mat)
        ob.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
        return ob
    def bolt(label,loc):
        return take(p.cyl(col,label,loc,.025,.035,mats['brass'],vertices=6),label)
    def clone(src,label,T):
        ob=src.copy(); ob.data=src.data.copy(); col.objects.link(ob)
        ob.hide_render=False; ob.hide_viewport=False; ob.matrix_world=T @ src.matrix_world
        ob.name=PREFIX+label; ob['derives_from']=src.name
        added.append(ob)
        return ob

    # Preserve the entire old V13 console, including independently keyed bars.
    previous=[o for o in process if 'angled service console /' in o.name or
              'angled CRT live green readout bar' in o.name]
    if len(previous)!=11: raise RuntimeError('Expected six old controls and five keyed bars')
    for ob in previous: ob.hide_render=True
    yaw=math.radians(12)
    pivot=Vector((1.12,-1.18,0))
    R=Matrix.Translation(pivot) @ Matrix.Rotation(yaw,4,'Z') @ Matrix.Translation(-pivot)
    # The full casing cannot share the witness glass volume. Solve the lowest
    # clear service height in measured increments, retaining footprint and yaw.
    controls=[bpy.data.objects[n] for n in ('MH7_service interface casting','MH7_service inset CRT',
        'MH7_control push button','MH7_control push button.001',
        'MH7_control push button.002','MH7_control push button.003')]
    tank=bpy.data.objects['FMPL_PROCESS | sample station 2 enlarged transparent vessel']
    tb=bounds([tank]); candidates=[]
    for dz in [i*.025 for i in range(37)]:
        T=Matrix.Translation((.12,0,dz)) @ R
        pts=[T @ o.matrix_world @ v.co for o in controls for v in o.data.vertices]
        lo=[min(v[i] for v in pts) for i in range(3)]
        hi=[max(v[i] for v in pts) for i in range(3)]
        # Require a meaningful 0.025 tile clearance; conservative AABB test.
        clear=any(hi[k]+.025<tb[0][k] or lo[k]-.025>tb[1][k] for k in range(3))
        if clear and lo[0]>=-1.5 and hi[0]<=1.5 and lo[1]>=-1.5 and hi[1]<=1.5:
            candidates.append((dz,T)); break
    if not candidates: raise RuntimeError('No supported in-footprint console candidate')
    dz,T=candidates[0]
    console=[clone(o,'console / '+o.name.removeprefix('MH7_'),T) for o in controls]
    # A real side-wall extension keeps right-hand switch collars inside the
    # casting with a measured border. No control is independently scaled.
    ext=block('console cast side extension',(1.17,-1.18,.90),(.10,.27,.57),'iron')
    ext.matrix_world=T @ ext.matrix_world
    # Framed screen recess and seated button bosses in the same face plane.
    for label,loc,size in (
        ('CRT lower retaining edge',(.76,-1.347,.801),(.47,.035,.025)),
        ('CRT upper retaining edge',(.76,-1.347,1.109),(.47,.035,.025)),
        ('CRT left retaining edge',(.522,-1.347,.955),(.025,.035,.33)),
        ('CRT right retaining edge',(.998,-1.347,.955),(.025,.035,.33))):
        ob=block(label,loc,size,'brass',.004); ob.matrix_world=T @ ob.matrix_world
    for i,ob in enumerate(controls[2:]):
        loc=ob.matrix_world.translation
        a=Vector((loc.x,-1.343,loc.z)); b=Vector((loc.x,-1.29,loc.z))
        boss=tube(f'console seated button boss {i}',a,b,.043,.029,'iron')
        boss.matrix_world=T @ boss.matrix_world
    # Preserve all five original bar actions and local animation, moving them
    # by the same rigid change from the V13 frame to the corrected assembly.
    oldT=Matrix.Translation((.19,-.045,0)) @ R
    delta=T @ oldT.inverted()
    bars=[clone(o,'console live green bar '+str(i),delta) for i,o in enumerate(previous)
          if 'readout bar' in o.name]
    for x in (.92,1.11):
        a=T @ Vector((x,-1.15,.615)); b=Vector((a.x,a.y,.48))
        beam('console grounded stanchion '+str(x),b,a,.07,.09,'iron')
        block('console stanchion foot '+str(x),(b.x,b.y,.47),(.16,.18,.06),'iron')
        for dx in (-.05,.05): bolt('console foot bolt '+str((x,dx)),(b.x+dx,b.y,.511))
    # Mechanical wedge rails touch the full casting lower face.
    for x in (.62,1.08):
        a=T @ Vector((x,-1.305,.635)); b=T @ Vector((x,-1.065,.635))
        beam('console wedge rail '+str(x),a,b,.055,.065,'iron')

    # Preserve old bridge and build an I section inside its exact envelope.
    oldbridge=bpy.data.objects['FMPL_PROCESS | gearbox load-bearing overhead bridge']
    oldbridge.hide_render=True
    for z in (3.055,3.161):
        block('drive I beam flange '+str(z),(0,.1,z),(1.83,.22,.024))
    block('drive I beam web',(0,.1,3.108),(1.83,.045,.106))
    contact_graph=[]
    for side in (-1,1):
        x=side*.84
        shoe=block('drive metal landing shoe '+str(side),(side*.807,.1,2.697),(.225,.22,.108),'iron')
        # Two triangulated plate gussets join the pedestal's shoe to the
        # outer vessel wall. Their inner x edge penetrates the steel shell.
        for y in (.025,.175):
            verts=[(side*.735,y-.018,2.46),(side*.915,y-.018,2.705),(side*.735,y-.018,2.705),
                   (side*.735,y+.018,2.46),(side*.915,y+.018,2.705),(side*.735,y+.018,2.705)]
            me=bpy.data.meshes.new('supported triangular haunch')
            me.from_pydata(verts,[],[(0,1,2),(5,4,3),(0,3,4,1),(1,4,5,2),(2,5,3,0)])
            me.update(); ob=bpy.data.objects.new('gusset',me); col.objects.link(ob)
            me.materials.append(mats['martian_red']); take(ob,'drive gusset '+str((side,y)))
        for y in (.035,.165): bolt('drive shoe bolt '+str((side,y)),(x,y,2.767))
        contact_graph.append(dict(path=['motor housing','bearing ring','I-section bridge',
             'source red pedestal '+str(side),'metal landing shoe','triangulated haunch','steel vessel shell','source chassis','foundation'],
             status='constructed; independent contact verification required'))

    # Exact named P0 process receivers, taken from the source process route.
    # Each fitting has a receiving boss, two actual hollow flange plates,
    # gasket, and bolt groups. No external .49 bore hardware is changed.
    receivers={
        'manifold to mounted intake pump':('dirty inlet visible sight glass','low mounted intake centrifugal pump'),
        'pump to first vertical filter':('low mounted intake centrifugal pump','filter 1 cartridge body'),
        'first filter to second filter':('filter 1 vertical cartridge pressure crown','filter 2 cartridge body'),
        'second filter to central treatment inlet':('filter 2 vertical cartridge pressure crown','open double-wall steel treatment vessel'),
        'treatment outlet to clean discharge reducer':('open double-wall steel treatment vessel','clarified water outlet casting'),
    }
    fitted=[]
    for route,parents in receivers.items():
        ob=bpy.data.objects['FMPL_PROCESS | '+route+' / section 1']
        ends=[sum((ob.matrix_world @ v.co for v in list(ob.data.vertices)[k:k+32]),Vector())/32 for k in (0,32)]
        rad=(ob.matrix_world @ ob.data.vertices[0].co-ends[0]).length
        axis=(ends[1]-ends[0]).normalized()
        for i,(pt,parent) in enumerate(zip(ends,parents)):
            into=axis if i==0 else -axis
            receiver=bpy.data.objects['FMPL_PROCESS | '+parent]
            label='process union '+route+' '+str(i)
            # Boss overlaps the original receiver wall and pipe; no ring-only
            # appearance. The original tube and union preserve the same bore.
            boss=tube(label+' receiving neck',pt-into*.065,pt+into*.09,rad*1.27,rad*.72,'iron')
            for a,b in ((.005,.035),(.047,.077)):
                tube(label+' flange '+str(a),pt+into*a,pt+into*b,rad*1.64,rad*.72)
            tube(label+' seated gasket',pt+into*.035,pt+into*.047,rad*1.46,rad*.72,'dark_recess')
            u=into.cross(Vector((0,0,1)))
            if u.length<.01: u=into.cross(Vector((0,1,0)))
            u.normalize(); v=into.cross(u).normalized()
            for k in range(4):
                angle=math.tau*k/4+math.pi/4
                pos=pt+into*.088+rad*1.40*(u*math.cos(angle)+v*math.sin(angle))
                fast=p.cyl(col,label+' fastener '+str(k),pos,rad*.13,.04,mats['brass'],vertices=6)
                fast.rotation_euler=into.to_track_quat('Z','Y').to_euler()
                take(fast,label+' fastener '+str(k))
            bpy.context.view_layer.update()
            fitted.append(dict(line_name=ob.name,end=i,receiving_object=receiver.name,
                coupling_type='hollow gasketed flanged union with receiving neck',
                axis_error_degrees=0.,source_joint=list(pt),output_joint=list(pt),
                receiver_surface_intersections=len(tree(boss).overlap(tree(receiver))),
                QA_status='constructed; receiver surface contact requires independent readback'))
    (out/'fitted-joints.json').write_text(json.dumps(fitted,indent=2)+'\n')

    # Census every constructed straight hollow route segment; no nearest-
    # surface snapping or invented receiving hardware. Unresolved joints stay
    # explicitly pending until their named process receivers are verified.
    lines=[]
    for ob in process:
        if ob.hide_render or ' / section ' not in ob.name or len(ob.data.vertices)!=128: continue
        ends=[sum((ob.matrix_world @ v.co for v in list(ob.data.vertices)[k:k+32]),Vector())/32 for k in (0,32)]
        radius=(ob.matrix_world @ ob.data.vertices[0].co-ends[0]).length
        lines.append(dict(line_name=ob.name,A_xyz=list(ends[0]),B_xyz=list(ends[1]),
             diameter=radius*2,axis=list((ends[1]-ends[0]).normalized()),
             semantic='electrical' if 'conduit' in ob.name else 'fluid',
             receiving_object=None,coupling_type=None,QA_status='pending named endpoint/branch review'))
    (out/'line-endpoint-census.json').write_text(json.dumps(lines,indent=2)+'\n')
    # V13 contained procedural meshes with packed PBR but no UVs. Preserve
    # those data blocks and add explicit model-space UVs to visible copies;
    # otherwise the GLB retains maps with no usable surface coordinates.
    surfaced=[]
    for srcmesh in list(s.objects):
        if srcmesh.type!='MESH' or srcmesh.hide_render or srcmesh.data.uv_layers: continue
        ob=clone(srcmesh,'UV surfaced / '+srcmesh.name,Matrix.Identity(4))
        srcmesh.hide_render=True
        uv_for_visible_surface(ob)
        uv=ob.data.uv_layers.active
        verts=ob.data.vertices
        if len(verts)==128 and ' / section ' in srcmesh.name:
            a=sum((srcmesh.matrix_world @ v.co for v in list(verts)[:32]),Vector())/32
            b=sum((srcmesh.matrix_world @ v.co for v in list(verts)[32:64]),Vector())/32
            radius=(srcmesh.matrix_world @ verts[0].co-a).length
            for face in ob.data.polygons:
                indices=[ob.data.loops[k].vertex_index for k in face.loop_indices]
                seam=any(i%32==0 for i in indices) and any(i%32==31 for i in indices)
                for k,i in zip(face.loop_indices,indices):
                    angular=(32 if seam and i%32==0 else i%32)/32
                    uv.data[k].uv=(angular*math.tau*radius*1.25,((i//32)%2)*(b-a).length*1.25)
            method='axial physical-scale wrap with seam'
        elif 'open double-wall steel treatment vessel' in srcmesh.name:
            for face in ob.data.polygons:
                vs=[ob.matrix_world @ verts[ob.data.loops[k].vertex_index].co for k in face.loop_indices]
                angles=[math.atan2(v.y-.1,v.x) for v in vs]
                crossing=max(angles)-min(angles)>math.pi
                for k,v,angle in zip(face.loop_indices,vs,angles):
                    if crossing and angle<0: angle+=math.tau
                    uv.data[k].uv=(angle*.758*1.25,v.z*1.25)
            method='vessel circumferential wrap, vertical grain'
        else: method='physical-scale planar islands'
        ob['surface_mapping']=method
        surfaced.append(dict(source=srcmesh.name,derivative=ob.name,method=method))
    (out/'surface-derivatives.json').write_text(json.dumps(surfaced,indent=2)+'\n')
    bpy.context.view_layer.update()
    # Exact original mesh+transform equality remains mandatory even for hidden sources.
    if p.hash_original_meshes(original+process)!=frozen: raise RuntimeError('Source geometry changed')
    bore=verify_bores(s)
    if not bore['passed']: raise RuntimeError('V14 obstructed canonical bores: '+str(bore['hits']))
    # Local panel-plane measurements include every control vertex.
    inverse=T.inverted()
    pts=[inverse @ o.matrix_world @ v.co for o in console[1:] for v in o.data.vertices]
    content=[[min(v[i] for v in pts) for i in (0,2)],[max(v[i] for v in pts) for i in (0,2)]]
    margins=[content[0][0]-.39,1.22-content[1][0],content[0][1]-.615,1.185-content[1][1]]
    if min(margins)<.025: raise RuntimeError('Console frame containment failed '+str(margins))
    tank_overlaps=[o.name for o in console if tree(o).overlap(tree(tank))]
    if tank_overlaps: raise RuntimeError('Console intersects witness tank '+str(tank_overlaps))
    audit_scene(s,bpy)
    s.render.engine='CYCLES'; s.cycles.device='CPU'; s.cycles.samples=args.samples
    s.render.resolution_x=512; s.render.resolution_y=512; s.render.resolution_percentage=100
    s.render.image_settings.file_format='PNG'; s.render.image_settings.color_mode='RGBA'
    s.render.film_transparent=True; s.render.use_compositing=False
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(target),check_existing=False)
    receipt=dict(status='candidate_native; endpoint census incomplete',source_path=str(src),
        source_sha256=sha(src),source_mesh_digest=frozen,original_count=len(original),
        process_count=len(process),console_height_offset=dz,console_panel_margins=margins,
        console_tank_BVH_intersections=tank_overlaps,camera=camera,bores=bore,
        added_meshes=len(added),contact_graph=contact_graph,fitted_process_endpoints=len(fitted),
        source_preserving_UV_derivatives=len(surfaced),
        model_sha256=sha(target),runtime_integrated=False,owner_approved=False,
        pending=['all line endpoints/couplings','independent reopen/export/contact QA','render comparison','atlases','native prototype and pipe jig'])
    (out/'construction-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    for state,frame in (('idle',1),('working',25)):
        s.frame_set(frame); s.render.filepath=str(out/(state+'.png'))
        bpy.ops.render.render(write_still=True)
    print('V14_PILOT_SAVED',target,flush=True)

if __name__=='__main__': main()
