"""Source-preserving service line correction on the real purifier V15.

Fittings use explicit process receivers; nothing is snapped to the closest
arbitrary surface. Old routes, gauges and console stay independently editable.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector, Matrix

sys.path.insert(0,str(Path(__file__).resolve().parent))
from mechanical_routes import hollow_route,compression_joint,hollow_sleeve
from refine_process import hash_original_meshes,block
from blender_build import uv_for_visible_surface
from pipe_bore_clearance import verify_bores
from camera_profile import audit_scene
import refine_process as process_helpers
import importlib.util

PREFIX='TP_MH7_V16 | '
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--source',required=True)
    ap.add_argument('--out',required=True); ap.add_argument('--expected-sha',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:])
    src=Path(args.source).resolve(); out=Path(args.out).resolve()
    if sha(src)!=args.expected_sha: raise ValueError('Wrong V15 native source')
    if out.exists(): raise FileExistsError('Keep earlier source/candidates')
    out.mkdir(parents=True)
    bpy.ops.wm.open_mainfile(filepath=str(src)); s=bpy.context.scene; s.frame_set(25)
    frozen_objects=[o for o in s.objects if o.type=='MESH' and o.name.startswith(('MH7_','FMPL_PROCESS |'))]
    frozen=hash_original_meshes(frozen_objects)
    col=bpy.data.collections.new('TP | V16 named service routing and fitted receivers'); s.collection.children.link(col)
    steam=[o for o in s.objects if o.type=='MESH' and not o.hide_render and o.name.startswith('TP_MH7_V15 |')]
    if len(steam)!=12: raise ValueError('Expected V15 native steam derivative')
    steam_root=bpy.data.objects.new(PREFIX+'emitter-anchored plume envelope',None); col.objects.link(steam_root)
    anchor=Vector((.94,.60,2.913))
    steam_root.matrix_world=Matrix.Translation(anchor) @ Matrix.Scale(1.12,4) @ Matrix.Translation(-anchor)
    for ob in steam:
        if ob.parent is not None: raise ValueError('Unexpected source steam parent')
        ob.parent=steam_root; ob.matrix_parent_inverse=Matrix.Identity(4)
    steam_root['purpose']='12% emitter-relative envelope increase; preserve real volume/noise and closing animation poses'
    metal=bpy.data.materials['TP Water Purifier V14 | iron'].copy(); metal.name='TP Purifier V16 | service iron'
    brass=bpy.data.materials['TP Water Purifier V14 | brass'].copy(); brass.name='TP Purifier V16 | fitted brass'
    dark=bpy.data.materials['TP Library | gunmetal_dark'].copy(); dark.name='TP Purifier V16 | armored cable'
    hidden=[]; ledger=[]; routes=[]
    def hide_route(label):
        matches=[o for o in s.objects if o.type=='MESH' and not o.hide_render and
                 ('FMPL_PROCESS | '+label+' / section ' in o.name or 'FMPL_PROCESS | '+label+' / cast elbow ' in o.name)]
        if not matches: raise ValueError('Missing visible source route '+label)
        for ob in matches: ob.hide_render=True; hidden.append(ob.name)
    def create(label,points,radius,receivers,electrical=False,intentional_open=False):
        ob=hollow_route(col,PREFIX+label,points,radius,radius*.72,dark if electrical else metal)
        routes.append(ob)
        axes=[Vector(points[1])-Vector(points[0]),Vector(points[-2])-Vector(points[-1])]
        for i,(pt,axis,receiver) in enumerate(zip((points[0],points[-1]),axes,receivers)):
            if receiver is None and intentional_open and i==1:
                ledger.append(dict(route=ob.name,end=i,point=list(pt),receiver=None,
                    classification='intentional gravity air-gap outlet above drain grate',status='requires rendered support/air-gap review'))
                continue
            if not receiver: raise ValueError('Unclassified endpoint '+label)
            target=bpy.data.objects.get(receiver)
            if target is None: raise ValueError('Missing named receiver '+receiver)
            fittings=compression_joint(col,PREFIX+label+' endpoint '+str(i),pt,axis,radius,metal,brass,electrical)
            ledger.append(dict(route=ob.name,end=i,point=list(pt),axis=list(axis.normalized()),
                receiver=target.name,fittings=[o.name for o in fittings],
                classification='electrical gland' if electrical else 'pressure compression union',
                source_or_guess='explicit source process endpoints; new route geometry',status='constructed; independent contact/clearance pending'))
        return ob
    # Source gauge heads were embedded behind the right load column. Mount
    # source-preserving copies on its front face, below the raised console.
    gauge_sources=['instrument rack front face']
    for i in (1,2): gauge_sources += ['working pressure dial '+str(i),'working dial lens '+str(i),'working gauge needle '+str(i)]
    for label in gauge_sources:
        old=bpy.data.objects['FMPL_PROCESS | '+label]
        new=old.copy();new.data=old.data.copy();col.objects.link(new)
        new.name=PREFIX+'visible gauge panel / '+label;new.hide_render=False
        new.location+=Vector((0,-.18,-.32));new['derives_from']=old.name
        old.hide_render=True;hidden.append(old.name)
    panel=PREFIX+'visible gauge panel / instrument rack front face'
    for z in (.84,1.10):
        support=block(col,PREFIX+'gauge panel column standoff '+str(z),(1.12,-1.237,z),(.25,.036,.06),metal,.004)
        support['intended_support_receiver']='MH7_cast red load column.002'
    for i,x,y,height,gx in ((1,-.92,-1.,1.73,.81),(2,-.50,-1.03,1.80,1.36)):
        hide_route('filter %d pressure impulse tube'%i)
        hide_route('pressure gauge %d hardline'%i)
        points=[(x,y,1.57),(x,y,height),(x+.09,-.94,height),(gx,-.94,height),
                (gx,-.94,1.04),(gx,-1.30,1.04),(.94 if i==1 else 1.30,-1.30,1.04)]
        create('filter %d dedicated pressure gauge line'%i,points,.028,
            ('FMPL_PROCESS | filter %d vertical cartridge pressure crown'%i,
             panel))
    hide_route('pressure relief to exhaust elbow')
    vent=create('hollow vessel relief to open vent',[(.645,.50,2.35),(.94,.60,2.55),(.94,.60,2.775)],.089,
           ('FMPL_PROCESS | open double-wall steel treatment vessel',
            'TP_MH7_V14 | UV surfaced / FMPL_PROCESS | relief vent emitter / open steel throat'))
    hide_route('return condensate pipe from working relief')
    create('vent condensate into actual trap',[(.94,.689,2.65),(.94,.82,2.65),(1.06,.82,2.21),
           (1.04,.53,1.90),(1.04,.53,1.68)],.053,
           (vent.name,'FMPL_PROCESS | relief condensate trap gasket'))
    # Drill only the actual side branch into the new hollow standpipe. The
    # cutter begins in its lumen and exits one wall, leaving no opposite hole.
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.053*.72,depth=.24,location=(.94,.72,2.65))
    cutter=bpy.context.object;cutter.rotation_euler.x=math.pi/2
    bpy.context.view_layer.objects.active=vent
    mod=vent.modifiers.new('Actual open condensate side branch','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
    create('trap return to treatment shell',[(1.04,.53,1.48),(1.04,.53,1.42),(.92,.53,1.42),(.92,.53,.85),
           (.79,.42,.75),(.70,.38,.75)],.045,
           ('FMPL_PROCESS | relief condensate trap','FMPL_PROCESS | open double-wall steel treatment vessel'))
    hide_route('pump metal pressure bleeder')
    create('pump bleeder to fitted valve',[(-1.12,-.84,.845),(-1.18,-.91,.96),
           (-1.18,-.99,.96),(-1.18,-.99,1.035)],.046,
           ('FMPL_PROCESS | low mounted intake centrifugal pump','FMPL_PROCESS | pump bleed-valve bonnet'))
    hide_route('process sump gravity return')
    create('sump into supported drain air gap',[(.59,-.375,.68),(.67,-.438,.68),
           (.84,-.79,.58),(.84,-.98,.58),(.84,-1.11,.48),(.84,-1.275,.48),(.84,-1.275,.41)],.050,
           ('FMPL_PROCESS | open double-wall steel treatment vessel',None),intentional_open=True)
    # New conduit lands on the actual junction and full-sized raised console.
    hide_route('control panel motor power armored conduit')
    original_box=bpy.data.objects['FMPL_PROCESS | control junction terminal box']
    original_box.hide_render=True; hidden.append(original_box.name)
    junction=original_box.copy(); junction.data=original_box.data.copy(); col.objects.link(junction)
    junction.name=PREFIX+'supported visible electrical junction'; junction.hide_render=False
    junction.location+=Vector((.54,-.17,.12)); junction['derives_from']=original_box.name
    foot=block(col,PREFIX+'junction foot seated on front chassis',(1.11,-1.30,.5325),(.18,.18,.055),metal,.005)
    uv_for_visible_surface(foot); foot['intended_support_receiver']='MH7_chassis width rail'
    pivot=Vector((1.12,-1.18,0)); T=Matrix.Translation((.12,0,.775)) @ Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(12),4,'Z') @ Matrix.Translation(-pivot)
    entry=T @ Vector((.80,-1.045,1.10)); outside=T @ Vector((.80,-.90,1.10))
    create('junction to raised console rear gland',[(1.015,-1.32,.63),(.90,-1.32,.63),
           (.74,-.85,.75),(.74,-.85,outside.z),tuple(outside),tuple(entry)],.038,
           (junction.name,'TP_MH7_V14 | console / service interface casting'),True)
    create('junction to intake motor armored conduit',[(1.11,-1.415,.57),(.80,-1.43,.57),
           (-1.05,-1.43,.57),(-1.27,-1.34,.65),(-1.27,-1.225,.65)],.038,
           (junction.name,'FMPL_PROCESS | pump drive fitted cast housing'),True)
    # Match the final metal approach axis to each real glass branch. The old
    # solid elbow spheres are retained hidden, not left blocking the bore.
    # Rebuild the raw inlet glass branch as well: its old far endpoint passed
    # through a filter housing. Real liquid and two animated tracers follow it.
    raw_start=(-.62,-1.33,1.19);raw_end=(-.383,-1.242,1.19)
    for old in list(s.objects):
        if old.type=='MESH' and not old.hide_render and 'FMPL_PROCESS | raw-canister inlet /' in old.name:
            old.hide_render=True;hidden.append(old.name)
    fx_spec=importlib.util.spec_from_file_location('purifier_source_fluid_fx',Path(__file__).resolve().parent.parent/'effects/fluid_steam_fx.py')
    fx=importlib.util.module_from_spec(fx_spec);fx_spec.loader.exec_module(fx)
    fx._clear_flow(process_helpers,col,PREFIX+'raw-canister inlet',raw_start,raw_end,
        bpy.data.materials['FMPL FX | glass-clear'],bpy.data.materials['FMPL | purifier raw-water olive-amber V11'],
        bpy.data.materials['FMPL | purifier raw olive-ochre foam V11'])
    new_raw_glass=next(o for o in col.objects if o.name.endswith(PREFIX+'raw-canister inlet / transparent tube'))
    witness_specs={
        'raw witness feed from pump':([(-1.305,-.70,.67),(-1.445,-.70,.67),(-1.445,-1.3857,1.19),(-.7701,-1.3857,1.19),raw_start],.037),
        'raw witness return to first filter':([(-.75,-1.09,.79),(-.8609,-1.0441,.79),(-.92,-1.00,.67)],.037),
        'clean witness feed from treatment outlet':([(.69,-.18,.79),(.92,-.60,1.03),(.9222,-.9427,1.19),(.84,-1.08,1.19)],.037),
        'clean witness return to discharge casting':([(.84,-1.05,.79),(.9122,-.9072,.79),(.93,-.66,.72),(.9421,-.2941,.66)],.037),
    }
    witness_routes={}
    for label,(points,radius) in witness_specs.items():
        hide_route(label)
        ob=hollow_route(col,PREFIX+label,points,radius,radius*.72,metal)
        routes.append(ob); witness_routes[label]=ob
    # The four sample branch pairs retain their original, continuous glass
    # routes. Replace wrong-axis torus-only glands with real coaxial fittings.
    channel_names=('raw-canister inlet','raw-canister outlet','clean-canister inlet','clean-canister outlet')
    for label in channel_names:
        matches=[o for o in s.objects if not o.hide_render and o.type=='MESH' and
                 'FMPL_PROCESS | '+label+' / transparent tube' in o.name]
        if label=='raw-canister inlet': matches=[new_raw_glass]
        if len(matches)!=1: raise ValueError('Sight line source missing: '+label)
        ob=matches[0]; n=32
        if len(ob.data.vertices)!=128: raise ValueError('Sight tube topology changed')
        ends=[sum((ob.matrix_world @ v.co for v in list(ob.data.vertices)[k:k+n]),Vector())/n for k in (0,n)]
        old=bpy.data.objects['FMPL_PROCESS | '+label+' / seated vessel connector gland']
        old.hide_render=True; hidden.append(old.name)
        tank_index=1 if label.startswith('raw') else 2
        tank=bpy.data.objects['TP_MH7_V14 | UV surfaced / FMPL_PROCESS | sample station %d enlarged transparent vessel'%tank_index]
        tank_end=1 if label.endswith('inlet') else 0
        # Both ends of the old glass branch need a true gland; the far end is
        # an intentional pipe-to-pipe union with its named metal witness route.
        witness='raw witness feed from pump' if label=='raw-canister inlet' else (
                'raw witness return to first filter' if label=='raw-canister outlet' else (
                'clean witness feed from treatment outlet' if label=='clean-canister inlet' else 'clean witness return to discharge casting'))
        line_objs=[witness_routes[witness]]
        for i,point in enumerate(ends):
            axis=ends[1-i]-point
            joint=compression_joint(col,PREFIX+label+' sight gland '+str(i),point,axis,.055,metal,brass)
            receiver=tank.name if i==tank_end else [o.name for o in line_objs]
            ledger.append(dict(route=ob.name,end=i,point=list(point),axis=list(axis.normalized()),
                receiver=receiver,fittings=[o.name for o in joint],classification='sample-vessel gland' if i==tank_end else 'glass/metal compression union',
                status='constructed; independent branch/contact audit pending'))
    for label,end,receiver in (
        ('raw witness feed from pump',0,'FMPL_PROCESS | low mounted intake centrifugal pump'),
        ('raw witness return to first filter',1,'FMPL_PROCESS | filter 1 cartridge body'),
        ('clean witness feed from treatment outlet',0,'FMPL_PROCESS | open double-wall steel treatment vessel'),
        ('clean witness return to discharge casting',1,'TP_MH7_V14 | UV surfaced / FMPL_PROCESS | clarified water outlet casting'),
    ):
        ob=witness_routes[label]; points=ob['route_points']
        pt=Vector(points[0 if end==0 else -1]); adjacent=Vector(points[1 if end==0 else -2]); axis=adjacent-pt
        fittings=compression_joint(col,PREFIX+label+' process tap',pt,axis,.037,metal,brass)
        ledger.append(dict(route=ob.name,end=end,point=list(pt),axis=list(axis.normalized()),receiver=receiver,
            fittings=[o.name for o in fittings],classification='witness branch compression tap',status='constructed; independent contact pending'))
    # Compact supported clamps at known frame/panel points, not random studs.
    for i,(point,size,parent,role) in enumerate((
        ((.904,-1.30,1.10),(.11,.09,.05),panel,'gauge downpipe clamp'),
        ((1.305,-1.30,1.10),(.04,.09,.05),panel,'second gauge downpipe clamp'),
        ((1.005,.53,1.37),(.05,.10,.04),'FMPL_PROCESS | steam vent radiator support','trap return support'),
        ((.94,-1.275,.3925),(.06,.07,.085),'FMPL_PROCESS | floor drain trough near front right','drain lip support'),
    )):
        ob=block(col,PREFIX+role,point,size,metal,.005); uv_for_visible_surface(ob)
        ob['intended_support_receiver']=parent
    for label,point,outer,inner in (
        ('first pressure tube saddle',(.81,-1.30,1.10),.045,.029),
        ('second pressure tube saddle',(1.36,-1.30,1.10),.045,.029),
        ('trap return saddle',(.92,.53,1.37),.067,.046),
        ('drain outlet saddle',(.84,-1.275,.435),.075,.051),
    ):
        hollow_sleeve(col,PREFIX+label,point,(0,0,1),.035,outer,inner,metal)
    for x in (-.8,.2):
        hollow_sleeve(col,PREFIX+'floor cable saddle '+str(x),(x,-1.43,.57),(1,0,0),.035,.053,.039,metal)
        bracket=block(col,PREFIX+'floor cable support '+str(x),(x,-1.365,.505),(.10,.07,.05),metal,.004)
        uv_for_visible_surface(bracket); bracket['intended_support_receiver']='MH7_chassis width rail'
    for ob in col.objects:
        if ob.name.startswith('FMPL_PROCESS | '+PREFIX):
            ob.name=ob.name.removeprefix('FMPL_PROCESS | ')
        if ob.type=='MESH' and not ob.data.uv_layers: uv_for_visible_surface(ob)
    # The old drain/grate sat inside an uncut chassis beam. Preserve that beam
    # and open a supported service recess in its visible derivative.
    oldrail=bpy.data.objects['MH7_chassis width rail'];oldrail.hide_render=True;hidden.append(oldrail.name)
    rail=oldrail.copy();rail.data=oldrail.data.copy();col.objects.link(rail)
    rail.name=PREFIX+'front chassis with real drain recess';rail.hide_render=False;rail['derives_from']=oldrail.name
    bpy.ops.mesh.primitive_cube_add(size=1,location=(.73,-1.29,.425));cut=bpy.context.object;cut.dimensions=(.50,.22,.30)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bpy.context.view_layer.objects.active=rail
    mod=rail.modifiers.new('Open drain trench in chassis','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cut
    bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cut,do_unlink=True)
    bpy.context.view_layer.update()
    if hash_original_meshes(frozen_objects)!=frozen: raise RuntimeError('Original mesh/transform changed')
    camera=audit_scene(s,bpy); bore=verify_bores(s)
    if not bore['passed']: raise RuntimeError('Service fittings obstruct canonical exterior bores')
    s.render.engine='CYCLES'; s.cycles.device='CPU'; s.cycles.samples=24; s.cycles.seed=4359
    s.render.resolution_x=512; s.render.resolution_y=512; s.render.resolution_percentage=100
    s.render.image_settings.file_format='PNG'; s.render.image_settings.color_mode='RGBA'; s.render.film_transparent=True
    bpy.ops.file.pack_all(); native=out/'water-purifier-v16.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(native),check_existing=False)
    report=dict(status='candidate_native; named service fixtures need independent contact and collision QA',
        source_sha256=sha(src),output_sha256=sha(native),source_geometry_digest=frozen,
        source_meshes_preserved=True,hidden_superseded_routes=hidden,camera=camera,bores=bore,
        new_hollow_routes=[o.name for o in routes],endpoint_ledger=ledger,
        steam_envelope_scale=1.12,steam_anchor=list(anchor),
        actual_native_ports_verified=False,prototype_installed=False,
        next=['independent all-endpoint census and contact/clearance','source-camera render inspection','repair demonstrated defects'])
    (out/'service-fit-receipt.json').write_text(json.dumps(report,indent=2)+'\n')
    for state,frame in (('idle',1),('working',25)):
        s.frame_set(frame); s.render.filepath=str(out/(state+'.png')); bpy.ops.render.render(write_still=True)
    print('V16_SERVICE_SOURCE_SAVED',native,flush=True)

if __name__=='__main__': main()
