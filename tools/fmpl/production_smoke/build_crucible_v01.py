"""Distinct 5x5 metallization pressure crucible, editable construction pilot.

New reconstruction from the approved process packet; not recovered v0.2 bytes.
Fictional process topology, not a pressure-vessel engineering specification.
"""
import argparse
import json
import math
from pathlib import Path
import sys
import bpy
import bmesh
from mathutils import Matrix, Vector

sys.path.insert(0,str(Path(__file__).resolve().parent))
from mh7_machine_scene import MachineScene,sha
from mechanical_routes import mesh_object,hollow_route,compression_joint
from blender_build import uv_for_visible_surface
import refine_process as p


def main():
    ap=argparse.ArgumentParser()
    for name in ('registry','material-donor','out'): ap.add_argument('--'+name,required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);out=Path(args.out).resolve()
    if out.exists(): raise FileExistsError('Retain crucible construction studies')
    out.mkdir(parents=True);m=MachineScene('Metallization Crucible V01',args.material_donor,args.registry);s=m.scene
    contacts=[];routes=[];assemblies=[]
    def joint(a,b,label): contacts.append(dict(a=a.name,b=b.name,label=label))
    def own(ob,label,role='PROCESS'):
        uv_for_visible_surface(ob);return m.own(ob,label,role)
    def drill(ob,label,center,radius,depth,axis):
        bpy.context.view_layer.objects.active=ob
        for modifier in list(ob.modifiers): bpy.ops.object.modifier_apply(modifier=modifier.name)
        bpy.ops.mesh.primitive_cylinder_add(vertices=40,radius=radius,depth=depth,location=center);cut=bpy.context.object
        if axis=='X': cut.rotation_euler.y=math.pi/2
        elif axis=='Y': cut.rotation_euler.x=math.pi/2
        bpy.context.view_layer.objects.active=ob;mod=ob.modifiers.new(label,'BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cut
        bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cut,do_unlink=True)
        bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
        bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6)
        bm.to_mesh(ob.data);bm.free();ob.data.update()
    def lathe(label,profile,mat='machine_steel',segments=80):
        verts=[(r*math.cos(math.tau*i/segments),r*math.sin(math.tau*i/segments),z) for r,z in profile for i in range(segments)]
        faces=[]
        for row in range(len(profile)):
            nxt=(row+1)%len(profile)
            for i in range(segments):
                j=(i+1)%segments;faces.append((row*segments+i,row*segments+j,nxt*segments+j,nxt*segments+i))
        return own(mesh_object(m.cols['PROCESS'],label,verts,faces,m.mats[mat]),label)
    def tapered_haunch(label,angle):
        radial=Vector((math.cos(angle),math.sin(angle),0));tangent=Vector((-math.sin(angle),math.cos(angle),0))
        low=radial*2.15+Vector((0,0,.30));high=radial*1.10+Vector((0,0,2.14))
        verts=[]
        for center,width in ((low,.46),(high,.25)):
            for a,b in ((-1,-1),(1,-1),(1,1),(-1,1)):
                verts.append(tuple(center+radial*(a*width/2)+tangent*(b*.24/2)))
        faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
        ob=own(mesh_object(m.cols['FRAME'],label,verts,faces,m.mats['martian_red']),label,'FRAME')
        bevel=ob.modifiers.new('Cast haunch rounded edges','BEVEL');bevel.width=.025;bevel.segments=2
        return ob,radial,tangent
    def radial_fastener(label,angle,z,radius=1.145):
        normal=Vector((math.cos(angle),math.sin(angle),0));ob=m.cyl(label,normal*radius+Vector((0,0,z)),.028,.042,'brass',vertices=6)
        ob.rotation_euler=normal.to_track_quat('Z','Y').to_euler();return ob
    base=m.box('full footprint equipment footing',(0,0,.06),(4.88,4.88,.12),'ferrocrete_dark')
    plinth=m.cyl('thick annular pressure plinth',(0,0,.23),1.29,.34,'gunmetal_dark',vertices=80)
    sole=m.cyl('vessel lower pressure closure',(0,0,.43),1.09,.16,'iron',vertices=80)
    shell=m.sleeve('thick wall central pressure vessel',(0,0,1.35),(0,0,1),1.80,1.04,.88,'machine_steel',segments=80)
    joint(plinth,base,'central plinth grounded');joint(sole,plinth,'pressure closure carried by plinth');joint(shell,sole,'vessel seated on lower closure')
    roof=lathe('closed graded pressure crown',[(1.04,2.25),(1.04,2.29),(.91,2.42),(.67,2.54),(.34,2.59),(.30,2.59),(.30,2.50),(.64,2.45),(.86,2.34),(.96,2.25)])
    joint(roof,shell,'crown seated on pressure wall')
    crown=m.sleeve('crown service hatch retaining flange',(0,0,2.58),(0,0,1),.09,.40,.30,'iron',segments=64)
    lid=m.cyl('closed crown service hatch',(0,0,2.65),.35,.08,'gunmetal_dark',vertices=64)
    joint(crown,roof,'crown flange seated');joint(lid,crown,'crown cover closes service bore')
    for k in range(8):
        a=math.tau*k/8;m.cyl('crown flange stud '+str(k),(.365*math.cos(a),.365*math.sin(a),2.655),.023,.06,'brass',vertices=6)
    bands=[]
    for index,z in enumerate((.60,1.45,2.12)):
        band=m.sleeve('seated pressure retaining band '+str(index),(0,0,z),(0,0,1),.14,1.135,1.035,'iron',segments=80)
        bands.append(band);joint(band,shell,'pressure band has full circumferential seat')
        for k in range(12):radial_fastener('band retained radial head '+str((index,k)),math.tau*k/12,z)
    for k in range(4):
        a=math.pi/4+k*math.pi/2;brace,radial,tangent=tapered_haunch('tapered pressure haunch '+str(k),a)
        center=radial*2.15;shoe=m.box('haunch grounded shoe '+str(k),(*center.xy,.205),(.60,.60,.17),'iron')
        joint(shoe,base,'haunch shoe on foundation');joint(brace,shoe,'tapered casting seated in shoe');joint(brace,bands[2],'haunch loads upper pressure collar')
        back=m.beam('haunch steel back brace '+str(k),radial*2.10+Vector((0,0,.30)),radial*1.10+Vector((0,0,1.45)),.14,.12,'gunmetal_dark')
        joint(back,shoe,'back brace grounded');joint(back,bands[1],'back brace supports middle collar')
        upper=m.box('haunch upper mounting cheek '+str(k),radial*1.13+Vector((0,0,2.12)),(.24,.28,.25),'martian_red');upper.rotation_euler.z=a
        joint(upper,brace,'haunch cap retained on casting')
        for sign in (-1,1):
            anchor=center+tangent*sign*.21;m.cyl('haunch foundation anchor '+str((k,sign)),(*anchor.xy,.315),.036,.055,'brass',vertices=6)
        assemblies.append(dict(name=brace.name,classification='new_reconstruction_from_reference',role='Four red diagonal load paths into grounded shoes'))
    # Front pressure hatch: true wall opening, closed lid, supported hinge/latches.
    drill(shell,'Front maintenance pressure hatch opening',(0,-1.01,1.08),.275,.48,'Y')
    flange=m.sleeve('front pressure hatch receiving collar',(0,-1.055,1.08),(0,1,0),.17,.355,.275,'iron',segments=64)
    hatch=m.cyl('closed front pressure hatch',(0,-1.18,1.08),.303,.09,'gunmetal_dark','Y',vertices=64)
    joint(flange,shell,'maintenance collar seated through real shell opening');joint(hatch,flange,'closed pressure lid on collar')
    for z in (.93,1.23):
        lug=m.box('hatch grounded hinge lug '+str(z),(-.34,-1.10,z),(.10,.21,.09),'iron')
        hinge=m.sleeve('hatch bronze hinge knuckle '+str(z),(-.35,-1.225,z),(0,0,1),.12,.055,.025,'brass')
        joint(lug,flange,'hinge lug attached to retaining collar');joint(hinge,lug,'hinge knuckle supported')
    pin=m.cyl('hatch retained hinge pin',(-.35,-1.225,1.08),.024,.50,'machine_steel')
    for k in range(3):
        a=-math.pi/2+k*math.pi/2;center=Vector((.32*math.cos(a),-1.23,1.08+.32*math.sin(a)))
        keeper=m.box('pressure hatch latch keeper '+str(k),(center.x,-1.11,center.z),(.105,.18,.10),'iron')
        dog=m.box('pressure hatch closed latch dog '+str(k),center,(.14,.07,.065),'brass');dog.rotation_euler.y=-a
        joint(keeper,flange,'latch keeper anchored in collar');joint(dog,keeper,'closed dog straddles cover edge')
    spindle=m.cyl('hatch handwheel supported spindle',(0,-1.30,1.08),.032,.15,'iron','Y')
    wheel=m.torus('hatch handwheel rim',(0,-1.39,1.08),.15,.022,'brass','Y')
    for k in range(3):
        a=math.tau*k/3;spoke=m.beam('hatch handwheel spoke '+str(k),(0,-1.39,1.08),(.15*math.cos(a),-1.39,1.08+.15*math.sin(a)),.025,.025,'brass','PROCESS')
        joint(spoke,spindle,'actual spoke reaches supported spindle');joint(wheel,spoke,'actual spoke reaches handwheel rim')
    joint(spindle,hatch,'handwheel spindle seated in lid')
    # Distinct low service input and protected product-transfer route.
    ports=[]
    for role,sign,z,small,mat in (('conditioned_hydrogen_input',-1,1.05,.09,'iron'),('metallicized_intermediate_output',1,.90,.11,'brass')):
        center=(sign*2.5,0,.36);normal=(sign,0,0)
        m.reuse('tp.mh7.factorio-fluid-mouth',role,Matrix.Translation(center) @ Matrix.Rotation(math.pi if sign<0 else 0,4,'Z'),'PIPING')
        barrel=m.sleeve(role+' full-size receiving barrel',(sign*2.11,0,.36),(1,0,0),.18,.285,.245,'iron','PIPING',64)
        # A reducer changes diameter along one axis. Separate constant-bore,
        # circular elbows turn the flow: no mismatched ring frames or twisted
        # short taper between a horizontal pipe and a vertical nozzle.
        taper=p.cast_reducing_manifold(m.cols['PIPING'],role+' coaxial reducer',(sign*2.02,0,.36),(sign*1.78,0,.36),.285,small,m.mats['iron'],face_normal_at_start=(-sign,0,0),face_normal_at_end=(-sign,0,0))
        own(taper,role+' straight coaxial cast reducer','PIPING')
        taper['reducer_axes_parallel']=True
        # Match the final inner ring to the actual smaller process tube.
        for vertex in list(taper.data.vertices)[192:256]:
            vertex.co.y*=.72/(.49/.57);vertex.co.z=.36+(vertex.co.z-.36)*.72/(.49/.57)
        points=[(sign*1.78,0,.36),(sign*1.76,0,.36)]
        points.extend((sign*(1.76-.20*math.sin(math.pi*i/24)),0,.56-.20*math.cos(math.pi*i/24)) for i in range(1,13))
        points.append((sign*1.56,0,z-.20))
        points.extend((sign*(1.36+.20*math.cos(math.pi*i/24)),0,z-.20+.20*math.sin(math.pi*i/24)) for i in range(1,13))
        points.append((sign*.98,0,z))
        tube=own(hollow_route(m.cols['PIPING'],role+' true radius process route',points,small,small*.72,m.mats[mat],segments=40,rounded=False),role+' smooth circular elbow process route','PIPING')
        drill(shell,role+' drilled vessel nozzle',(sign*1.01,0,z),small*.72,.38,'X')
        nozzle=m.sleeve(role+' seated pressure nozzle',(sign*1.08,0,z),(1,0,0),.25,small*1.55,small*.72,'iron','PIPING',48)
        joint(nozzle,shell,'actual pressure nozzle at route end');joint(tube,nozzle,'process tube enters chamber through drilled nozzle')
        x=sign*1.56;clamp_z=(.56+z-.20)/2
        foot=m.box(role+' offset riser support foot',(x,.20,.19),(.30,.40,.14),'gunmetal_dark')
        post=m.box(role+' grounded riser support',(x,.20,(clamp_z+.26)/2),(.07,.08,clamp_z-.26),'martian_red')
        saddle=m.sleeve(role+' straight riser clamp',(x,0,clamp_z),(0,0,1),.06,small+.030,small+.001,'iron','PIPING')
        tie=m.beam(role+' offset clamp tie',(x,.22,clamp_z),(x,small+.018,clamp_z),.045,.045,'iron','PIPING')
        joint(post,foot,'riser support grounded');joint(tie,post,'offset clamp tie mounted on post');joint(saddle,tie,'riser clamp retained outside pipe bore')
        if sign>0:
            guard=m.sleeve('protected product transfer pressure housing',(1.18,0,z),(1,0,0),.32,.225,small+.03,'gunmetal_dark','PIPING',48)
            for x in (1.05,1.31): m.sleeve('transfer housing retaining flange '+str(x),(x,0,z),(1,0,0),.055,.25,.14,'iron','PIPING')
            joint(guard,nozzle,'transfer shield mounted on vessel pressure nozzle; process tube retains radial clearance')
        ports.append(dict(id=role,model_mouth_center=list(center),outward_normal=list(normal),bore_diameter=.49,flange_outer_diameter=.68,native_position=None,native_direction=None,verified_native=False))
        routes.append(dict(id=role,mesh=tube.name,points=points,sampled_path=True,bend_radius=.20,reducer=taper.name,reducer_axes_parallel=True,nozzle=nozzle.name,classification='source-backed symbolic process, straight coaxial reducer plus two true circular elbows'))
    # Two seated thermal contact rings and rear enclosed power/service cabinet.
    for z in (1.72,1.93):
        ring=m.sleeve('seated thermal contact band '+str(z),(0,0,z),(0,0,1),.045,1.065,1.035,'brass',segments=80)
        joint(ring,shell,'thermal band seated on vessel skin')
        for x in (-.32,.32):
            strap=m.box('thermal bus contact strap '+str((x,z)),(x,1.045,z),(.07,.10,.12),'brass')
            joint(strap,ring,'thermal strap overlaps actual seated ring')
            m.pipe('protected rear thermal bus '+str((x,z)),[(x,1.08,z),(x,1.47,z),(x,1.64,1.0)],.033,'brass')
    cabinet=m.box('rear power and closed cooling cabinet',(0,1.89,.96),(1.20,.46,1.48),'gunmetal_dark')
    for x in (-.45,.45):
        foot=m.box('rear service cabinet grounded foot '+str(x),(x,1.89,.18),(.24,.53,.12),'iron');joint(cabinet,foot,'power cabinet on grounded feet')
    for x in (-.48,.48):m.box('rear service cabinet split cover seam '+str(x),(x,2.13,.96),(.025,.035,1.20),'brass')
    # Guarded radiator fan on rear face, shaft and motor anchored to cabinet.
    fan_center=Vector((0,2.20,1.08))
    shroud=m.sleeve('cooling fan protective shroud',fan_center,(0,1,0),.15,.37,.33,'iron',segments=48)
    hub=m.cyl('cooling fan bearing hub',fan_center,.07,.18,'brass','Y')
    fan=bpy.data.objects.new(m.prefix+'supported cooling fan rotor',None);m.cols['PROCESS'].objects.link(fan);fan.location=fan_center
    bpy.context.view_layer.update()
    for k in range(3):
        a=math.tau*k/3;ob=m.beam('cooling fan swept blade '+str(k),fan_center+Vector((.06*math.cos(a),0,.06*math.sin(a))),fan_center+Vector((.29*math.cos(a),0,.29*math.sin(a))),.06,.035,'machine_steel','PROCESS')
        world=ob.matrix_world.copy();ob.parent=fan;ob.matrix_world=world
    for x in (-.22,0,.22):
        half=math.sqrt(.34**2-x*x);m.beam('fan front protective guard '+str(x),(x,2.30,1.08-half),(x,2.30,1.08+half),.022,.025,'gunmetal_dark')
    joint(shroud,cabinet,'fan shroud attached to cabinet rear');joint(hub,cabinet,'fan bearing supported by cabinet')
    # Reachable front corridor: separate low grated deck, no full-width roof bars.
    for x in (-.50,.50):m.box('maintenance corridor edge rail '+str(x),(x,-1.78,.20),(.065,1.05,.10),'iron')
    for y in (-2.24,-2.12,-2.,-1.88,-1.76,-1.64,-1.52,-1.40,-1.28):m.box('maintenance corridor grated tread '+str(y),(0,y,.19),(.98,.045,.09),'machine_steel')
    m.reuse('tp.mh7.cogitator-console','reachable service cogitator',Matrix.Translation((1.03,-1.91,.90)),'CONTROLS')
    pedestal=m.box('cogitator grounded pedestal',(1.03,-1.91,.3975),(.28,.30,.395),'iron')
    m.box('cogitator pedestal sole',(1.03,-1.91,.165),(.48,.48,.09),'iron')
    m.pipe('console enclosed service conduit',[(1.03,-1.90,.58),(.82,-1.70,.40),(.70,-1.10,.40)],.035,'gunmetal_dark')
    # Small guarded process witness, not a glass pressure chamber.
    lens=bpy.data.materials.new(m.prefix+'small process witness cyan');lens.use_nodes=True;bs=lens.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(.015,.22,.26,1);bs.inputs['Metallic'].default_value=.25;bs.inputs['Roughness'].default_value=.22
    bs.inputs['Emission Color'].default_value=(.015,.55,.65,1);bs.inputs['Emission Strength'].default_value=2
    for x in (-.23,.23):
        y=-math.sqrt(1.04**2-x*x);drill(shell,'small protected witness aperture '+str(x),(x,y,1.83),.065,.25,'Y')
        rim=m.sleeve('process witness metal bezel '+str(x),(x,y-.03,1.83),(0,1,0),.08,.095,.065,'iron')
        glass=m.cyl('closed process witness lens '+str(x),(x,y-.07,1.83),.064,.025,'dark_recess','Y');glass.data.materials[0]=lens
        joint(rim,shell,'witness bezel seated on drilled wall');joint(glass,rim,'small inspection lens retained by bezel')
    # Conservative visible motion: protected cooling fan; vessel and hatch stay closed.
    for frame in range(0,194):
        fan.rotation_euler.y=0 if frame==0 else math.tau*7*(frame-1)/192
        fan.keyframe_insert(data_path='rotation_euler',index=1,frame=frame)
    for action in bpy.data.actions:
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:key.interpolation='LINEAR'
    # Smooth cylindrical walls while retaining planar cap normals.
    for ob in s.objects:
        if ob.type=='MESH':
            for face in ob.data.polygons:
                if len(face.vertices)==4 and abs(face.normal.z)<.97: face.use_smooth=True
    m.camera(1.20,7.7);s.frame_end=193;s['working_cycle_seconds']=8
    s['animation_states']=json.dumps(dict(idle=[0],working=[7,31,55,79,103,127,151,175]))
    m.save(out,'crucible-v01.blend')
    (out/'port_manifest.json').write_text(json.dumps(dict(machine='metallization-crucible',footprint=[5,5],ports=ports,native_target=None,native_fluidbox_verified=False),indent=2)+'\n')
    (out/'construction-receipt.json').write_text(json.dumps(dict(status='construction pilot; independent reopen and visual review pending',
        provenance='new_reconstruction_from_reference; historical v0.2 native bytes not recovered',source_sha256=sha(out/'crucible-v01.blend'),
        contacts=contacts,process_routes=routes,assemblies=assemblies,cycle_seconds=8,
        design='Closed thick-walled pressure vessel, three seated pressure bands, four tapered red haunches and steel back braces, real closed hinged hatch, separate supported injector/product transfer, rear thermal cabinet and guarded fan, clear front maintenance corridor',
        pending=['Independent source/export bores, contacts, bounds and motion clearances','Model-specific surface maps and exported closeup review','Relevant pressure/thermal sound','Four-direction state capture','Actual native prototype and pipe fitting']),indent=2)+'\n')
    print('CRUCIBLE_V01_NATIVE_SAVED',sha(out/'crucible-v01.blend'),flush=True)


if __name__=='__main__':main()
