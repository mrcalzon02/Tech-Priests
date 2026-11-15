"""Three-cylinder reciprocating hydrogen compressor, distinct 3x4 pilot."""
import argparse
import json
import math
from pathlib import Path
import sys
import bpy
import bmesh
from mathutils import Matrix,Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from mh7_machine_scene import MachineScene,sha
from mechanical_routes import compression_joint
from blender_build import uv_for_visible_surface
import refine_process as p


def main():
    ap=argparse.ArgumentParser();ap.add_argument('--registry',required=True)
    ap.add_argument('--material-donor',required=True);ap.add_argument('--out',required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Retain prior compressor candidates')
    out.mkdir(parents=True);m=MachineScene('Hydrogen Compressor V01',args.material_donor,args.registry);s=m.scene
    def drill(ob,label,center,radius,depth,axis):
        bpy.context.view_layer.objects.active=ob
        # Apply the authored bevel before the cut. Applying a later Boolean
        # while retaining the earlier bevel used to evaluate that bevel twice.
        for modifier in list(ob.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
        bpy.ops.mesh.primitive_cylinder_add(vertices=40,radius=radius,depth=depth,location=center);cut=bpy.context.object
        if axis=='X':cut.rotation_euler.y=math.pi/2
        if axis=='Y':cut.rotation_euler.x=math.pi/2
        bpy.context.view_layer.objects.active=ob;mod=ob.modifiers.new(label,'BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cut
        bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cut,do_unlink=True)
        bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
        bmesh.ops.triangulate(bm,faces=list(bm.faces))
        bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6);bm.to_mesh(ob.data);bm.free();ob.data.update()
    def root(label,center,objects):
        ob=bpy.data.objects.new(m.prefix+label,None);m.cols['PROCESS'].objects.link(ob);ob.location=center
        bpy.context.view_layer.update()
        for child in objects:child.parent=ob;child.matrix_parent_inverse=Matrix.Translation(center).inverted()
        return ob
    def joint(a,b,label):contacts.append(dict(a=a.name,b=b.name,label=label))
    contacts=[];kinematics=[];cylinders=[]
    base=m.box('equipment footing',(0,0,.05),(2.90,3.90,.10),'ferrocrete_dark')
    for x in (-1.25,1.25):
        rail=m.box('longitudinal bed rail '+str(x),(x,0,.18),(.14,3.55,.16))
        drill(rail,'Full fluid-mouth relief through bed rail',(x,.5,.36),.25,.40,'X')
    for y in (-1.7,1.5):m.box('transverse bed tie '+str(y),(0,y,.18),(2.5,.14,.16),'martian_red')
    for x in (-.72,0,.72):
        for y in (.05,.8):
            foot=m.box('saddle sole '+str((x,y)),(x,y,.145),(.56,.29,.09),'iron')
            saddle=m.box('machined concave saddle '+str((x,y)),(x,y,.39),(.42,.18,.52),'martian_red',bevel=.01)
            drill(saddle,'True cylinder bearing seat',(x,y,.78),.252,.30,'Y')
            joint(foot,base,'saddle sole on footing');joint(saddle,foot,'saddle seated on sole')
            for dx in (-.22,.22):m.cyl('saddle anchor '+str((x,y,dx)),(x+dx,y,.205),.024,.035,'brass',vertices=6)
        shell=m.sleeve('closed horizontal compressor cylinder '+str(x),(x,.40,.78),(0,1,0),1.10,.25,.20,'machine_steel')
        cylinders.append(shell)
        front=m.sleeve('front pressure closure and piston passage '+str(x),(x,-.18,.78),(0,1,0),.10,.29,.038,'gunmetal_dark')
        back=m.cyl('rear pressure head '+str(x),(x,.98,.78),.29,.10,'gunmetal_dark','Y')
        gland=m.sleeve('piston rod compression gland '+str(x),(x,-.255,.78),(0,1,0),.09,.075,.034,'brass')
        joint(front,shell,'front head seated on shell');joint(back,shell,'rear head seated on shell');joint(gland,front,'rod gland seated on head')
        for y in (.05,.45,.9):m.sleeve('seated cylinder cooling band '+str((x,y)),(x,y,.78),(0,1,0),.027,.277,.249,'iron')
        for k in range(8):
            a=math.tau*k/8
            for y in (-.245,1.045):m.cyl('pressure head fastener '+str((x,y,k)),(x+.245*math.cos(a),y,.78+.245*math.sin(a)),.018,.026,'brass','Y',vertices=6)
        for dx in (-.13,.13):m.box('crosshead guide '+str((x,dx)),(x+dx,-.57,.78),(.035,.57,.12),'iron')
        for y in (-.79,-.36):
            pedestal=m.box('guide bearing pedestal '+str((x,y)),(x,y,.34),(.35,.10,.48),'martian_red')
            tie=m.box('guide bearing tie '+str((x,y)),(x,y,.64),(.35,.13,.16),'iron')
            drill(tie,'Actual rod clearance under supported guide rails',(x,y,.78),.09,.30,'Y')
            joint(pedestal,base,'guide support on footing');joint(tie,pedestal,'crosshead guide supported')
        slider=m.box('guided crosshead slider '+str(x),(x,-.57,.78),(.22,.12,.11),'machine_steel','PROCESS')
        wrist=m.cyl('crosshead retained wrist pin '+str(x),(x,-.57,.78),.043,.20,'brass','X')
        rod=m.cyl('working piston rod '+str(x),(x,-.35,.78),.028,1.,'machine_steel','Y')
        link=m.cyl('connecting rod shaft '+str(x),(x,-.9,.78),.030,1.,'iron')
        eye_a=m.torus('crank pin retained eye '+str(x),(x,-1.13,.78),.049,.014,'brass','X')
        eye_b=m.torus('wrist pin retained eye '+str(x),(x,-.57,.78),.049,.014,'brass','X')
        webs=[m.cyl('crank cheek web '+str((x,dx)),(x+dx,-1.25,.78),.16,.035,'gunmetal_dark','X') for dx in (-.09,.09)]
        pin=m.cyl('eccentric crank pin '+str(x),(x,-1.13,.78),.038,.20,'brass','X')
        crank=root('crank assembly '+str(x),(x,-1.25,.78),webs+[pin])
        kinematics.append(dict(x=x,phase=len(kinematics)*math.tau/3,slider=slider,wrist=wrist,piston=rod,link=link,eye_a=eye_a,eye_b=eye_b,crank=crank))
    # A real transverse shaft in two foundation-supported bearing towers.
    # Interrupted main journals leave each connecting-rod bay clear. Twin
    # cheek webs carry torque through the actual eccentric pin instead of a
    # solid central shaft passing through each moving connecting rod.
    for a,b in ((-1.235,-.81),(-.63,-.09),(.09,.63),(.81,1.235)):
        m.cyl('common crankshaft main journal '+str((a,b)),((a+b)/2,-1.25,.78),.043,b-a,'iron','X')
    for x in (-1.18,1.18):
        foot=m.box('shaft bearing sole '+str(x),(x,-1.25,.145),(.30,.50,.09),'iron')
        tower=m.box('shaft bearing tower '+str(x),(x,-1.25,.43),(.16,.30,.56),'martian_red')
        housing=m.sleeve('shaft bearing housing '+str(x),(x,-1.25,.78),(1,0,0),.15,.105,.044,'brass')
        support=m.box('shaft bearing cap seat '+str(x),(x,-1.25,.705),(.20,.28,.11),'iron')
        drill(support,'Clear shaft core through bearing seat',(x,-1.25,.78),.046,.40,'X')
        joint(foot,base,'shaft tower grounded');joint(tower,foot,'shaft tower on sole');joint(support,tower,'bearing cap supported');joint(housing,support,'bearing casing seated')
    # Side-mounted drive motor and a protected, visible supported flywheel.
    motor=m.cyl('cast electric drive motor',(-1.03,-1.25,.78),.24,.24,'gunmetal_dark','X')
    for y in (-1.40,-1.10):m.box('motor mounting leg '+str(y),(-1.03,y,.36),(.26,.10,.52),'iron')
    for k in range(6):m.sleeve('motor cooling fin '+str(k),(-1.13+k*.04,-1.25,.78),(1,0,0),.012,.265,.238,'machine_steel')
    hub=m.cyl('flywheel keyed hub',(.99,-1.25,.78),.085,.16,'brass','X')
    rim=m.torus('flywheel machined rim',(.99,-1.25,.78),.31,.035,'machine_steel','X')
    spokes=[]
    for k in range(3):
        a=math.tau*k/3
        spokes.append(m.beam('flywheel radial spoke '+str(k),(.99,-1.25,.78),(.99,-1.25+.31*math.cos(a),.78+.31*math.sin(a)),.045,.045,'martian_red','PROCESS'))
    flywheel=root('flywheel rotor',(.99,-1.25,.78),[hub,rim]+spokes)
    guard=m.sleeve('fixed flywheel outer guard',(.99,-1.25,.78),(1,0,0),.12,.385,.36,'iron')
    for y in (-1.60,-.90):m.beam('flywheel guard footing '+str(y),(1.06,y,.17),(1.06,y,.63),.04,.06,'martian_red')
    # Three separately bored suction and discharge branches; no shared gas exit.
    ports=[]
    for role,center,yaw in (('hydrogen_suction',(-1.5,.5,.36),math.pi),('hydrogen_discharge',(1.5,.5,.36),0)):
        m.reuse('tp.mh7.factorio-fluid-mouth',role,Matrix.Translation(center) @ Matrix.Rotation(yaw,4,'Z'),'PIPING')
        normal=(-1,0,0) if yaw else (1,0,0)
        ports.append(dict(id=role,model_mouth_center=list(center),outward_normal=list(normal),bore_diameter=.49,flange_outer_diameter=.68,native_position=None,native_direction=None,verified_native=False))
    for sign,y,height,label in ((-1,.2,1.20,'suction'),(1,.75,1.34,'discharge')):
        m.sleeve(label+' full size receiving barrel',(sign*1.11,.5,.36),(1,0,0),.18,.285,.245,'iron','PIPING')
        neck=(sign*1.08,y,.78 if sign<0 else .85)
        reducer=p.cast_reducing_manifold(m.cols['PIPING'],label+' mouth reducer',(sign*1.02,.5,.36),neck,.285,.08,m.mats['iron'],face_normal_at_start=(-sign,0,0),face_normal_at_end=(0,0,1))
        m.own(reducer,label+' cast mouth reducer','PIPING');uv_for_visible_surface(reducer)
        header=m.pipe(label+' independent pressure header',[neck,(sign*1.08,y,height),(-sign*1.,y,height)],.08,'iron' if sign<0 else 'brass')
        m.cyl(label+' closed header end',(-sign*1.,y,height),.080,.027,'iron','X','PIPING')
        for x in (-.72,0,.72):
            branch=m.pipe(label+' cell branch '+str(x),[(x,y,height),(x,y,.99)],.045,'iron' if sign<0 else 'brass')
            drill(header,'Open lower branch passage only '+str(x),(x,y,height-.075),.034,.15,'Z')
            drill(branch,'Open header intersection '+str(x),(x,y,height),.058,.24,'X')
            drill(cylinders[(-.72,0,.72).index(x)],label+' actual chamber nozzle',(x,y,1.03),.034,.22,'Z')
            compression_joint(m.cols['PIPING'],m.prefix+label+' cell nozzle '+str(x),(x,y,1.03),(0,0,1),.045,m.mats['iron'],m.mats['brass'])
        # A real support clip and grounded post at the remote header end.
        post_top=height-.102
        m.box(label+' header support post',(-sign*.96,y,(post_top+.10)/2),(.065,.08,post_top-.10),'martian_red')
        m.sleeve(label+' header support saddle',(-sign*.96,y,height),(1,0,0),.07,.102,.081,'iron','PIPING')
    m.reuse('tp.mh7.cogitator-console','service cogitator',Matrix.Translation((-.82,-1.66,.72)),'CONTROLS')
    m.box('console grounded pedestal',(-.82,-1.62,.2675),(.26,.26,.335),'iron')
    m.box('console pedestal foot',(-.82,-1.62,.135),(.43,.36,.07),'iron')
    # Exact slider-crank solution, 120-degree phases, four-second loop.
    samples=[]
    for frame in range(0,98):
        theta=math.tau*(max(frame,1)-1)/96;row=[]
        flywheel.rotation_euler.x=theta;flywheel.keyframe_insert(data_path='rotation_euler',index=0,frame=frame)
        for unit in kinematics:
            angle=theta+unit['phase'];x=unit['x'];crank=unit['crank']
            crank.rotation_euler.x=angle;crank.keyframe_insert(data_path='rotation_euler',index=0,frame=frame)
            a=Vector((x,-1.25+.12*math.cos(angle),.78+.12*math.sin(angle)))
            y=-1.25+.12*math.cos(angle)+math.sqrt(.67**2-(.12*math.sin(angle))**2)
            b=Vector((x,y,.78))
            for key in ('slider','wrist','eye_b'):
                ob=unit[key];ob.location=b;ob.keyframe_insert(data_path='location',frame=frame)
            unit['eye_a'].location=a;unit['eye_a'].keyframe_insert(data_path='location',frame=frame)
            link=unit['link'];link.location=(a+b)/2;link.rotation_mode='QUATERNION';link.rotation_quaternion=(b-a).to_track_quat('Z','Y');link.scale.z=(b-a).length
            for channel in ('location','rotation_quaternion','scale'):link.keyframe_insert(data_path=channel,frame=frame)
            piston=unit['piston'];piston.location=(x,(y+.05)/2,.78);piston.scale.z=.05-y
            # Cylinder helper axis Y is a static object rotation: native Z
            # scaling changes its local axial length after that rotation.
            piston.keyframe_insert(data_path='location',frame=frame);piston.keyframe_insert(data_path='scale',frame=frame)
            row.append(dict(x=x,crank_pin=list(a),crosshead=list(b),connecting_rod_length=(b-a).length))
        if frame in (0,1,13,25,37,49,61,73,85,97):samples.append(dict(frame=frame,units=row))
    for action in bpy.data.actions:
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:key.interpolation='LINEAR'
    m.camera(.82,6.1);s['working_cycle_seconds']=4;s['animation_states']=json.dumps(dict(idle=[0],working=list(range(1,97,12))))
    target=out/'compressor-v01.blend';m.save(out,target.name)
    (out/'port_manifest.json').write_text(json.dumps(dict(machine='hydrogen-compressor',footprint=[3,4],ports=ports,native_target=None,native_fluidbox_verified=False),indent=2)+'\n')
    (out/'construction-receipt.json').write_text(json.dumps(dict(status='candidate_native; independent mechanical/visual audit pending',
        revision='V01 distinct reciprocating construction',native_sha256=sha(target),provenance='new reconstruction from MH7 process packet; historical v0.2 not recovered',
        contacts=contacts,kinematics=samples,dimensions=dict(crank_radius=.12,connecting_rod_length=.67,phase_degrees=[0,120,240]),
        pending=['actual source/export mechanical contact and moving clearance audit','source/export front/rear/clay review','model-specific finishing','state capture','native prototype/pipe fitting']),indent=2)+'\n')
    print('COMPRESSOR_NATIVE_SAVED',sha(target),flush=True)


if __name__=='__main__':main()
