"""Distinct 3x4 electrolysis pilot using verified purifier donor assemblies.

New reconstruction from the approved style/process packet; unseen historical
v0.2 meshes are not claimed. Source, GLB and actual review renders precede QA.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Matrix,Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
import refine_process as p
from blender_build import uv_for_visible_surface
from mechanical_routes import hollow_route,hollow_sleeve,compression_joint
sys.path.insert(0,str(Path(__file__).resolve().parent.parent))
from blender_camera_guard import install_canonical_camera

PREFIX='TP_ELECTROLYZER_V01 | '
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--registry',required=True)
    ap.add_argument('--material-donor',required=True);ap.add_argument('--out',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);regpath=Path(args.registry).resolve()
    donor=Path(args.material_donor).resolve();out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Retain prior candidates')
    out.mkdir(parents=True);registry=json.loads(regpath.read_text());regsha=sha(regpath)
    if len(registry['parts'])<2:raise RuntimeError('Inspect real cumulative library before starting')
    bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene
    mats={}
    keys=['ferrocrete','ferrocrete_dark','machine_steel','iron','brass','martian_red','gunmetal_dark','dark_recess']
    with bpy.data.libraries.load(str(donor),link=False) as (fr,to):
        wanted=['TP Library | '+key for key in keys]
        if any(name not in fr.materials for name in wanted):raise RuntimeError('Packed source materials missing')
        to.materials=wanted
    for key,material in zip(keys,to.materials):
        mat=material.copy();mat.name='TP Electrolyzer V01 | '+key
        if mat.asset_data:mat.asset_clear()
        mat['surface_plan']='model-local FMPL material; physical tile UVs, steel vessel wrap and axial tubing'
        mats[key]=mat
    def plain(name,color,rough=.4,metal=0.,transmission=0.,emission=0.):
        m=bpy.data.materials.new('TP Electrolyzer V01 | '+name);m.use_nodes=True
        bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1)
        bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
        bs.inputs['Transmission Weight'].default_value=transmission
        bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=emission
        return m
    mats['ceramic']=plain('electrical porcelain',(.72,.73,.64),.32)
    mats['glass']=plain('clear pressure window',(.78,.91,.94),.065,transmission=.95)
    mats['water']=plain('inspection electrolyte',(.05,.29,.35),.14,transmission=.68)
    mats['bubble']=plain('gas nucleation tracers',(.57,.87,.91),.12,transmission=.35,emission=.12)
    cols={name:bpy.data.collections.new(name) for name in ('FRAME','PROCESS','PIPING','CONTROLS','PORT_MARKERS')}
    for col in cols.values():s.collection.children.link(col)
    added=[];instances=[];assemblies=[]
    def own(ob,label,role,col):
        ob.name=PREFIX+label;ob['assembly_role']=role
        ob['source_or_guess']='new_reconstruction_from_reference; process packet; physically inferred assembly'
        if ob.type=='MESH' and not ob.data.uv_layers:uv_for_visible_surface(ob)
        added.append(ob);return ob
    def box(label,loc,size,material='iron',role='FRAME',bevel=.01):
        ob=p.block(cols[role],label,loc,size,mats[material],bevel)
        uv_for_visible_surface(ob);return own(ob,label,role,cols[role])
    def cyl(label,loc,r,depth,material='machine_steel',axis='Z',role='PROCESS',vertices=48):
        ob=p.cyl(cols[role],label,loc,r,depth,mats[material],axis,vertices)
        return own(ob,label,role,cols[role])
    def pipe(label,points,r=.07,material='iron'):
        ob=hollow_route(cols['PIPING'],PREFIX+label,points,r,r*.72,mats[material]);added.append(ob);return ob
    def sleeve(label,pt,axis,length,outer,inner,material='iron',role='PROCESS',segments=48):
        ob=hollow_sleeve(cols[role],PREFIX+label,pt,axis,length,outer,inner,mats[material],segments);added.append(ob);return ob
    def beam(label,a,b,width=.08,depth=.06,material='machine_steel',role='FRAME'):
        a,b=Vector(a),Vector(b);ob=box(label,(a+b)/2,(width,depth,(b-a).length),material,role,.006)
        ob.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return ob
    def bolt(label,pt,axis='Z',r=.023):return cyl(label,pt,r,.035,'brass',axis,'FRAME',6)
    def boolean_hole(ob,label,loc,r,depth,axis='Z'):
        bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=r,depth=depth,location=loc)
        cut=bpy.context.object
        if axis=='Y':cut.rotation_euler.x=math.pi/2
        if axis=='X':cut.rotation_euler.y=math.pi/2
        bpy.context.view_layer.objects.active=ob
        mod=ob.modifiers.new(label,'BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cut
        bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cut,do_unlink=True)
    def reuse(part_id,label,transform,colname):
        entry=next(r for r in registry['parts'] if r['part_id']==part_id and r['revision']=='v1')
        if entry['status']!='verified':raise RuntimeError('Unverified donor part')
        source=regpath.parent/entry['source_blend']
        if sha(source)!=entry['source_sha256']:raise RuntimeError('Registered source changed')
        with bpy.data.libraries.load(str(source),link=False) as (fr,to):to.collections=[entry['collection']]
        collection=to.collections[0];collection.name=PREFIX+label;cols[colname].children.link(collection)
        # Appended objects need a depsgraph update before reading their saved
        # normalized matrices. Otherwise Blender can return identity matrices.
        bpy.context.view_layer.update()
        local_frames={ob:ob.matrix_world.copy() for ob in collection.all_objects}
        material_copies={}
        for ob in collection.all_objects:
            ob.name=PREFIX+label+' / '+ob.name
            ob.matrix_world=transform @ local_frames[ob]
            for slot in ob.material_slots:
                if slot.material:
                    if slot.material not in material_copies:
                        m=slot.material.copy();m.name='TP Electrolyzer V01 | donor '+m.name
                        if m.asset_data:m.asset_clear()
                        material_copies[slot.material]=m
                    slot.material=material_copies[slot.material]
            ob['library_instance']=label
        instances.append(dict(part_id=part_id,revision='v1',source_blend=entry['source_blend'],
            source_sha256=entry['source_sha256'],transform=[list(row) for row in transform],instance=label))
        return collection
    # Footing leaves all .49-ID mouths fully above its .10-tile upper face.
    box('ferrocrete equipment footing',(0,0,.05),(2.90,3.90,.10),'ferrocrete_dark')
    for x in (-1.25,1.25):
        for a,b in ((-1.82,.10),(.90,1.82)):
            box('split side skid rail '+str((x,a)),(x,(a+b)/2,.18),(.16,b-a,.14),'iron')
    for a,b in ((-1.25,-.40),(.40,1.25)):
        box('front rail clear of water mouth '+str(a),((a+b)/2,-1.82,.18),(b-a,.16,.14),'iron')
    box('rear skid rail',(0,1.82,.18),(2.50,.16,.14),'iron')
    for x in (-1.13,1.13):
        for y in (-1.,1.):
            box('column shoe '+str((x,y)),(x,y,.26),(.29,.28,.08),'iron')
            # I-section upright with explicit web and front/rear flanges.
            box('red upright web '+str((x,y)),(x,y,1.20),(.045,.12,1.80),'martian_red')
            for dx in (-.055,.055):box('upright edge flange '+str((x,y,dx)),(x+dx,y,1.20),(.035,.15,1.80),'martian_red')
            for dx in (-.09,.09):bolt('column anchor '+str((x,y,dx)),(x+dx,y,.315))
    for y in (-1.,1.):
        box('overhead transverse web '+str(y),(0,y,2.16),(2.38,.045,.13),'machine_steel')
        for z in (2.105,2.215):box('bridge flange '+str((y,z)),(0,y,z),(2.38,.18,.025),'machine_steel')
    for x in (-1.13,1.13):box('upper longitudinal tie '+str(x),(x,0,2.16),(.13,2.0,.13),'martian_red')
    # Twin closed pressure/cell cassettes, with accessible real inspection slots.
    for i,x in enumerate((-.62,.62),1):
        box('cell bearing plinth '+str(i),(x,0,.25),(.88,.88,.18),'iron')
        cyl('cell bottom pressure closure '+str(i),(x,0,.43),.405,.18,'gunmetal_dark')
        body=sleeve('electrode chamber shell '+str(i),(x,0,1.18),(0,0,1),1.36,.38,.32,'machine_steel')
        bpy.ops.mesh.primitive_cube_add(size=1,location=(x,-.35,1.20));cut=bpy.context.object;cut.dimensions=(.16,.30,.62)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);bpy.context.view_layer.objects.active=body
        mod=body.modifiers.new('True pressure observation aperture','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cut
        bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cut,do_unlink=True)
        boolean_hole(body,'Water entry bore',(x,-.38,.55),.051,.30,'Y')
        for z in (.55,1.04,1.81):sleeve('seated pressure band '+str((i,z)),(x,0,z),(0,0,1),.055,.411,.375,'brass')
        sleeve('top gas collector closure '+str(i),(x,0,1.90),(0,0,1),.08,.42,.052,'gunmetal_dark')
        sleeve('top retained gas neck '+str(i),(x,0,2.005),(0,0,1),.15,.11,.050,'brass')
        for k in range(8):
            a=math.tau*k/8;bolt('cell head fastener '+str((i,k)),(x+.351*math.cos(a),.351*math.sin(a),1.955),r=.021)
        for dx in (-.29,.29):
            for y in (-.26,.26):cyl('cell tie rod '+str((i,dx,y)),(x+dx,y,1.19),.019,1.47,'iron')
        # A small real window, not a giant open luminous jar.
        pane=box('inspection glass '+str(i),(x,-.379,1.20),(.185,.025,.65),'glass','PROCESS',.006)
        for dx in (-.112,.112):box('window side retaining rail '+str((i,dx)),(x+dx,-.398,1.20),(.040,.035,.72),'brass','PROCESS',.004)
        for z in (.847,1.553):box('window cap retaining rail '+str((i,z)),(x,-.398,z),(.264,.035,.035),'brass','PROCESS',.004)
        cyl('contained electrolyte '+str(i),(x,0,1.16),.288,1.10,'water')
        for k in range(8):
            bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=.018+.003*(k%2),location=(x+(k%3-1)*.039,-.283,1.0))
            bubble=own(bpy.context.object,'visible electrode gas bubble '+str((i,k)),'PROCESS',cols['PROCESS'])
            for oldcol in list(bubble.users_collection):oldcol.objects.unlink(bubble)
            cols['PROCESS'].objects.link(bubble);bubble.data.materials.append(mats['bubble'])
            for frame in range(1,98,6):
                phase=((frame-1)/96+k/8)%1.
                bubble.location.z=.91+phase*.55;bubble.scale=(1,1,.85+.15*math.sin(math.tau*phase))
                bubble.keyframe_insert(data_path='location',index=2,frame=frame);bubble.keyframe_insert(data_path='scale',frame=frame)
    # Supported rear rectifier, cooling fins, ceramic standoffs and flat busbars.
    for x in (-.61,.61):box('rectifier foundation pier '+str(x),(x,1.28,.32),(.23,.46,.44),'iron')
    box('rectifier cast enclosure',(0,1.28,1.08),(1.72,.58,1.18),'gunmetal_dark')
    box('rectifier service cover',(0,.974,1.08),(1.56,.035,1.02),'martian_red','PROCESS',.018)
    for k in range(12):box('rear heat sink fin '+str(k),(-.75+k*.136,1.61,1.08),(.028,.14,1.0),'machine_steel','PROCESS',.004)
    for x in (-.62,.62):
        cyl('busbar insulated bridge stud '+str(x),(x,.93,2.25),.050,.15,'iron')
        for z in (2.23,2.27,2.31):sleeve('porcelain busbar rib '+str((x,z)),(x,.93,z),(0,0,1),.020,.090,.040,'ceramic')
        for a,b in (((x,.95,1.61),(x,.93,2.33)),((x,.93,2.33),(x,.15,1.99))):
            beam('flat rectifier bus strap '+str((x,a)),a,b,.055,.023,'brass','PROCESS')
    # Explicitly disjoint gas headers; large native-size mouths use the actual
    # verified donor meshes at new boundary planes, without stretching.
    ports=[]
    for role,center,yaw in (('hydrogen_output',(-1.5,.5,.36),math.pi),('oxygen_output',(1.5,.5,.36),0),('water_input',(0,-2,.36),-math.pi/2)):
        transform=Matrix.Translation(center) @ Matrix.Rotation(yaw,4,'Z')
        reuse('tp.mh7.factorio-fluid-mouth',role,transform,'PIPING')
        normal=transform.to_3x3() @ Vector((1,0,0))
        ports.append(dict(id=role,model_mouth_center=list(center),outward_normal=list(normal),
            bore_diameter=.49,flange_outer_diameter=.68,native_position=None,native_direction=None,verified_native=False))
    for sign,x in ((-1,-.62),(1,.62)):
        side=sign*1.33
        pipe(('hydrogen' if sign<0 else 'oxygen')+' independent upper gas header',[(x,0,2.08),(x,0,2.38),(side,0,2.38),(side,.5,2.38),
             (side,.5,.96),(sign*1.20,.5,.79),(sign*.84,.5,.79),(sign*.84,.5,.64),(sign*.92,.5,.64)],.070)
        sleeve('full-size straight gas receiving barrel '+str(sign),(sign*1.11,.5,.36),(1,0,0),.18,.285,.245,'iron','PIPING')
        reducer=p.cast_reducing_manifold(cols['PIPING'],PREFIX+'full-size gas mouth reducer '+str(sign),
            (sign*1.02,.5,.36),(sign*.92,.5,.64),.285,.070,mats['iron'],face_normal_at_start=(-sign,0,0),face_normal_at_end=(-sign,0,0))
        own(reducer,'full-size gas mouth reducer '+str(sign),'PIPING',cols['PIPING'])
        sleeve('gas valve pressure casing '+str(sign),(side,.5,1.25),(0,0,1),.14,.12,.050,'brass','PIPING')
        cyl('gas valve operating spindle '+str(sign),(side,.42,1.25),.022,.15,'iron','Y','PIPING')
        wheel=p.torus(cols['PIPING'],'gas isolation handwheel '+str(sign),(side,.335,1.25),.088,.012,mats['brass'],'Y')
        own(wheel,'gas isolation handwheel '+str(sign),'PIPING',cols['PIPING'])
        beam('gas riser rear support '+str(sign),(sign*1.13,1.,1.40),(side,.60,1.40),.06,.06)
        sleeve('gas riser actual saddle '+str(sign),(side,.5,1.40),(0,0,1),.05,.10,.071,'iron','PIPING')
    feed=p.cast_reducing_manifold(cols['PIPING'],PREFIX+'raw water full-size feed reducer',(0,-1.70,.36),(0,-1.15,.50),.285,.09,mats['iron'],face_normal_at_start=(0,1,0))
    own(feed,'raw water full-size feed reducer','PIPING',cols['PIPING'])
    pipe('common liquid water trunk',[(0,-1.15,.50),(0,-.65,.50)],.09)
    for x in (-.62,.62):
        pipe('separate water feed branch '+str(x),[(0,-.65,.50),(x,-.65,.50),(x,-.38,.55)],.07)
        compression_joint(cols['PIPING'],PREFIX+'cell water gland '+str(x),(x,-.38,.55),(0,-1,0),.07,mats['iron'],mats['brass'])
    # The real emergency-family donor panel is mounted on a supported front
    # service pedestal, clear of the water inlet and both process cells.
    reuse('tp.mh7.cogitator-console','front service cogitator',Matrix.Translation((.80,-1.61,.87)),'CONTROLS')
    box('console mounting pedestal',(.80,-1.57,.39),(.28,.25,.39),'iron')
    box('console seated foot',(.80,-1.57,.195),(.43,.36,.08),'iron')
    beam('console backing wedge',(.8,-1.57,.53),(.8,-1.57,.60),.45,.20,'iron')
    # Read camera and bounds from this actual model, not an illustration.
    s.render.engine='CYCLES';s.cycles.device='CPU';s.cycles.samples=24;s.cycles.seed=4362
    s.render.resolution_x=640;s.render.resolution_y=640;s.render.resolution_percentage=100
    s.render.fps=24;s.frame_start=1;s.frame_end=97;s.render.film_transparent=True
    s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
    cfg=dict(camera_policy='fmpl.factorio45.v1',capture_kind='entity',directions=[0,90,180,270],
        source_size=640,states={'idle':[1],'working':[25]},camera_override=dict(type='ORTHO',elevation_deg=45,azimuth_deg=0,
        distance=6*math.sqrt(2),target=[0,0,1.30],ortho_scale=6.35,shift_x=0,shift_y=0))
    camera=install_canonical_camera(s,cfg,bpy)
    for name,loc,power,size in (('Key',(-3,-4,7),1150,5),('Fill',(4,-2,5),700,4),('Rim',(0,5,6),1000,4)):
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.size=size
        ob=bpy.data.objects.new(name,data);s.collection.objects.link(ob);ob.location=loc
        ob.rotation_euler=(Vector((0,0,1.1))-ob.location).to_track_quat('-Z','Y').to_euler()
    s.world=bpy.data.worlds.new('Neutral industrial world');s.world.use_nodes=True
    s.world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.11,.11,.11,1)
    for ob in s.objects:
        if ob.type=='MESH' and not ob.data.uv_layers:uv_for_visible_surface(ob)
    bpy.ops.file.pack_all();s.frame_set(25)
    native=out/'electrolyzer-v01.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native),check_existing=False)
    (out/'port_manifest.json').write_text(json.dumps(dict(machine='electrolyzer',footprint=[3,4],ports=ports,
        native_target=None,native_fluidbox_verified=False),indent=2)+'\n')
    (out/'part_provenance.json').write_text(json.dumps(dict(registry_sha256=regsha,instances=instances),indent=2)+'\n')
    report=dict(status='candidate_native; first review pending',provenance='new_reconstruction_from_reference',
        source_packet='docs/art/metallic-hydrogen-chain/AGENT_BUILD_ORDER.md',material_donor_sha256=sha(donor),
        native_sha256=sha(native),reused_instances=len(instances),camera=camera,
        source_visible_process=['common water feed','two separately supported electrolyte cell chambers','independent H2 and O2 upper headers','rear rectifier and ceramic-supported flat busbars'],
        pending=['first actual image review','independent source/GLB audit and port clearance','model-specific finishing','full animation and native prototypes'])
    (out/'construction-receipt.json').write_text(json.dumps(report,indent=2)+'\n')
    s.render.filepath=str(out/'working-front.png');bpy.ops.render.render(write_still=True)
    print('ELECTROLYZER_NATIVE_PILOT_SAVED',native,flush=True)

if __name__=='__main__':main()
