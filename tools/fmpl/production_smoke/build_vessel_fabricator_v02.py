"""Owner-directed plate welding and open-frame hydroforming construction pilot."""
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
from mechanical_routes import mesh_object,hollow_route
from blender_build import uv_for_visible_surface
import refine_process as p


def main():
    ap=argparse.ArgumentParser()
    for name in ('registry','material-donor','out'):ap.add_argument('--'+name,required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve fabricator studies')
    out.mkdir(parents=True);m=MachineScene('Vessel Fabricator V02',args.material_donor,args.registry);s=m.scene;contacts=[]
    def joint(a,b,label):contacts.append(dict(a=a.name,b=b.name,label=label))
    def own(obj,label):uv_for_visible_surface(obj);return m.own(obj,label,'PROCESS')
    def boolean(obj,cutter):
        bpy.context.view_layer.objects.active=obj
        for mod in list(obj.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=obj.modifiers.new('Actual die/pressure opening','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter;bpy.ops.object.modifier_apply(modifier=mod.name)
        bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6);bm.to_mesh(obj.data);bm.free()
    def drill(obj,center,r,depth,axis='X'):
        cutter=m.cyl('temporary bore',center,r,depth,'iron',axis);boolean(obj,cutter);bpy.data.objects.remove(cutter,do_unlink=True)
    base=m.box('full 4x4 equipment footing',(0,0,.06),(3.88,3.88,.12),'ferrocrete_dark')
    # Open-air plate hydroforming: supported edge lands clamp the welded
    # flanges, while the central pressure blank stays exposed as it expands.
    low=m.box('fixed front clamping land',(0,-.55,.915),(1.44,.11,.04),'machine_steel')
    rear_land=m.box('fixed rear clamping land',(0,.55,.915),(1.44,.11,.04),'machine_steel')
    lower_beams=[]
    for y in (-.65,.65):
        beam=m.box('open lower frame side '+str(y),(0,y,.51),(2.40,.20,.12),'martian_red');lower_beams.append(beam)
        for x in (-.65,.65):
            post=m.box('clamp land support '+str((x,y)),(x,math.copysign(.58,y),.7325),(.16,.16,.325),'iron')
            joint(post,beam,'clamping land post on open side beam');joint(low if y<0 else rear_land,post,'lower clamping land carried by post')
    for x in (-.90,.90):
        foot=m.box('clamping frame grounded foot '+str(x),(x,0,.235),(.36,1.48,.23),'iron')
        tie=m.box('low open-frame cross tie '+str(x),(x,0,.40),(.18,1.48,.10),'iron')
        joint(foot,base,'forming-frame foot grounded');joint(tie,foot,'cross tie on foot')
        for beam in lower_beams:joint(beam,tie,'open side beam carried by low cross tie')
    high=m.box('open upper front frame',(0,-.65,1.20),(2.68,.16,.12),'martian_red')
    upper_rear=m.box('open upper rear frame',(0,.65,1.20),(2.68,.16,.12),'martian_red');upper_parts=[upper_rear]
    for x in (-1.26,1.26):
        bridge=m.box('raised upper end bridge '+str(x),(x,0,1.20),(.16,1.46,.12),'iron');upper_parts.append(bridge)
        joint(bridge,high,'upper bridge joins front side');joint(bridge,upper_rear,'upper bridge joins rear side')
    for y in (-.55,.55):
        jaw=m.box('upper flange clamping land '+str(y),(0,y,.985),(1.44,.11,.04),'machine_steel');upper_parts.append(jaw)
        for x in (-.60,.60):
            post=m.box('upper jaw standoff '+str((x,y)),(x,math.copysign(.58,y),1.075),(.14,.17,.14),'iron');upper_parts.append(post)
            joint(post,high if y<0 else upper_rear,'jaw standoff carried by open upper frame');joint(jaw,post,'upper flange land supported by standoff')
    n=64
    # Closed two-sheet pressure blank. The welded plate edges remain in the
    # parting plane; only the body expands plastically into the cavity.
    bxs=(-1.18,-1.0,-.93,-.80,-.65,.65,.80,.93,1.0,1.18);rys=(.11,.11,.26,.43,.48,.48,.43,.26,.11,.11)
    initial_z=(.11,.11,.115,.12,.13,.13,.12,.115,.11,.11)
    verts=[];expanded=[]
    for inner in (False,True):
        for x,ry,rz in zip(bxs,rys,initial_z):
            for i in range(n):
                a=math.tau*i/n;wall=.025 if inner else 0
                verts.append((x,(ry-wall)*math.cos(a),.95+(rz-wall)*math.sin(a)))
                expanded.append((x,(ry-wall)*math.cos(a),.95+(ry-wall)*math.sin(a)))
    rings=len(bxs);faces=[]
    for side in range(2):
        offset=side*rings*n
        for j in range(rings-1):
            for i in range(n):
                k=(i+1)%n;f=(offset+j*n+i,offset+j*n+k,offset+(j+1)*n+k,offset+(j+1)*n+i);faces.append(tuple(reversed(f)) if side else f)
    for end in (0,rings-1):
        for i in range(n):
            k=(i+1)%n;face=(end*n+i,rings*n+end*n+i,rings*n+end*n+k,end*n+k);faces.append(tuple(reversed(face)) if end else face)
    blank=own(mesh_object(m.cols['PROCESS'],'Welded twin steel plate pressure blank',verts,faces,m.mats['machine_steel']),'welded two-plate pressure blank')
    blank.shape_key_add(name='Basis');formed=blank.shape_key_add(name='Hydroformed vessel')
    for vertex,co in zip(formed.data,expanded):vertex.co=co
    for key in blank.data.shape_keys.key_blocks:
        for vertex in key.data:vertex.co.z-=.95
    blank.location.z=.95
    flange=[]
    for y in (-.535,.535):
        rail=m.box('welded sheet flange '+str(y),(0,y,.95),(1.38,.11,.03),'machine_steel');flange.append(rail);joint(rail,blank,'sheet edge joins pressure blank')
        seam=m.cyl('actual longitudinal weld seam '+str(y),(0,math.copysign(.48,y),.95),.014,1.37,'iron','X');flange.append(seam);joint(seam,blank,'weld bead follows actual plate edge')
    plug=m.cyl('welded closed blind end',(-1.19,0,.95),.108,.04,'iron','X');joint(plug,blank,'blind end welded to round blank neck')
    hinge=m.cyl('fixed full die hinge shaft',(0,.73,.95),.05,3.30,'machine_steel','X')
    moving=[high,*upper_parts]
    for x in (-1.50,1.50):
        foot=m.box('rear hinge grounded foot '+str(x),(x,.90,.19),(.30,.40,.14),'iron');post=m.box('rear hinge pedestal '+str(x),(x,.90,.59),(.18,.25,.66),'martian_red')
        bearing=m.sleeve('fixed hinge bearing '+str(x),(x,.73,.95),(1,0,0),.17,.12,.051,'iron');tie=m.beam('hinge bearing support '+str(x),(x,.90,.84),(x,.73,.78),.10,.08)
        joint(foot,base,'hinge foot grounded');joint(post,foot,'hinge pedestal on foot');joint(tie,post,'hinge tie seated on pedestal');joint(bearing,tie,'hinge bearing carried by tie');joint(hinge,bearing,'fixed hinge shaft seated in bearing')
    for x in (-.98,.98):
        lug=m.sleeve('moving upper die hinge lug '+str(x),(x,.73,.95),(1,0,0),.18,.11,.051,'brass');moving.append(lug)
        arm=m.beam('upper frame hinge arm '+str(x),(x,.65,1.20),(x,.73,.95),.08,.08);moving.append(arm)
        drill(arm,(x,.73,.95),.051,.20)
        joint(arm,upper_rear,'hinge arm attached to rear open frame');joint(lug,arm,'hinge lug supported by actual arm')
    lift_arm=m.beam('upper die lift arm',(1.10,.60,1.24),(1.78,.60,1.24),.09,.10);moving.append(lift_arm);joint(lift_arm,upper_rear,'rear lift arm mounted on upper frame clear of welding gantry')
    pivot=bpy.data.objects.new(m.prefix+'upper die hinge control',None);m.cols['PROCESS'].objects.link(pivot);pivot.location=(0,.73,.95);bpy.context.view_layer.update()
    for obj in moving:obj.parent=pivot;obj.matrix_parent_inverse=Matrix.Translation((0,.73,.95)).inverted()
    anchor=Vector((1.78,1.40,.30));lift_point=Vector((1.78,.60,1.24))
    foot=m.box('lift ram grounded clevis foot',anchor-Vector((0,0,.13)),(.24,.30,.10),'iron');joint(foot,base,'lift ram clevis foot grounded')
    for x in (1.69,1.87):
        cheek=m.box('lift ram clevis cheek '+str(x),(x,1.40,.265),(.04,.14,.11),'iron');joint(cheek,foot,'trunnion cheek carried on grounded foot')
    pin=m.cyl('fixed lift trunnion pin',anchor,.035,.24,'machine_steel','X')
    eye=m.sleeve('upper die lift cylinder trunnion',anchor,(1,0,0),.12,.07,.036,'brass');joint(eye,pin,'lift cylinder pivots on actual clevis pin')
    ram=m.sleeve('upper die lift cylinder',(0,0,0),(0,0,1),.60,.065,.037,'gunmetal_dark');rod=m.cyl('upper die lift piston',(0,0,0),.035,1,'machine_steel')
    joint(ram,eye,'cylinder seated in pivoting trunnion');joint(rod,lift_arm,'piston end seated in moving rear lift arm')
    # Front gantry: welding carriage and direct conductive sliding shoes.
    for x in (-1.50,1.50):
        shoe=m.box('weld gantry grounded shoe '+str(x),(x,-.78,.19),(.42,.44,.14),'iron');column=m.box('red weld gantry column '+str(x),(x,-.70,1.12),(.20,.22,1.72),'martian_red')
        joint(shoe,base,'gantry shoe grounded');joint(column,shoe,'gantry column on shoe')
    rail=m.box('rigid spanning seam-tool rail',(0,-.70,2.04),(3.80,.22,.18),'martian_red')
    for x in (-1.5,1.5):joint(rail,s.objects[m.prefix+'red weld gantry column '+str(x)],'seam rail carried by gantry')
    guide=m.box('welding tool linear guide',(0,-.54,2.04),(3.60,.055,.085),'machine_steel')
    for x in (-1.2,0,1.2):
        mount=m.box('linear guide mounting standoff '+str(x),(x,-.58,2.04),(.09,.065,.055),'iron')
        joint(mount,rail,'linear guide standoff seated on gantry');joint(guide,mount,'linear guide supported by actual standoff')
    carriage=m.box('guided welding carriage',(-1.62,-.49,2.04),(.23,.10,.22),'iron');joint(carriage,guide,'carriage retained on actual linear guide')
    torch=m.cyl('supported seam welding torch',(-1.62,-.48,1.445),.042,.83,'brass');tip=m.cyl('actual welding contact tip',(-1.62,-.48,.995),.016,.065,'machine_steel')
    neck=m.box('torch carriage mounting saddle',(-1.62,-.49,1.88),(.15,.10,.22),'iron');joint(neck,carriage,'torch saddle carried on carriage');joint(torch,neck,'torch seated in saddle');joint(tip,torch,'contact tip retained in torch')
    trolley=bpy.data.objects.new(m.prefix+'welding travel control',None);m.cols['PROCESS'].objects.link(trolley);trolley.location=(-1.62,0,0);bpy.context.view_layer.update()
    for obj in (carriage,neck,torch,tip):obj.parent=trolley;obj.matrix_parent_inverse=Matrix.Translation((-1.62,0,0)).inverted()
    for z in (2.20,2.27):
        bus=m.box('insulated welding supply rail '+str(z),(0,-.70,z),(3.60,.035,.025),'brass')
        for x in (-1.35,0,1.35):
            stand=m.box('bus insulation standoff '+str((x,z)),(x,-.77,(2.13+z)/2),(.045,.04,z-2.13),'dark_recess')
            bracket=m.box('rear conductor bracket '+str((x,z)),(x,-.745,z),(.04,.09,.022),'dark_recess')
            joint(stand,rail,'insulator seated on beam');joint(bracket,stand,'rear conductor bracket carried by insulator');joint(bus,bracket,'supply rail supported from rear')
        shoe=m.box('moving current collector '+str(z),(-1.62,-.655,z),(.11,.055,.055),'iron');shoe.parent=trolley;shoe.matrix_parent_inverse=Matrix.Translation((-1.62,0,0)).inverted()
        contact=m.box('sliding conductor contact pad '+str(z),(-1.62,-.681,z),(.06,.022,.018),'brass',bevel=.001);contact.parent=trolley;contact.matrix_parent_inverse=Matrix.Translation((-1.62,0,0)).inverted()
        joint(contact,shoe,'spring contact pad retained in moving collector');joint(contact,bus,'conductive pad bears on front face of supply rail')
        lead=m.pipe('carriage-mounted welding lead '+str(z),[(-1.62,-.64,z),(-1.62,-.40,z),(-1.62,-.40,1.85),(-1.62,-.48,1.85)],.018,'gunmetal_dark')
        lead.parent=trolley;lead.matrix_parent_inverse=Matrix.Translation((-1.62,0,0)).inverted();joint(lead,shoe,'weld lead attached to collector');joint(lead,neck,'weld lead attached to torch saddle')
    # Coaxial sealed pressure mandrel and independently grounded tailstock.
    mandrel=m.sleeve('hollow pressure injection mandrel',(1.30,0,.95),(1,0,0),.50,.078,.045,'machine_steel')
    seal=m.sleeve('internal neck pressure seal',(1.10,0,.95),(1,0,0),.07,.0855,.077,'dark_recess');joint(seal,mandrel,'internal pressure seal retained on mandrel');joint(seal,blank,'pressure seal closes actual blank neck bore')
    clamp=m.sleeve('external neck restraint',(1.13,0,.95),(1,0,0),.12,.14,.111,'brass');joint(clamp,blank,'close-fitting neck restraint on round neck')
    head=m.sleeve('fixed pressure tailstock head',(1.43,0,.95),(1,0,0),.30,.16,.079,'iron');joint(head,mandrel,'mandrel seated in pressure head')
    pedestal=m.box('grounded pressure tailstock',(1.46,0,.455),(.28,.40,.67),'martian_red');joint(pedestal,base,'tailstock grounded');joint(head,pedestal,'pressure head supported outside bore')
    end=m.sleeve('closed annular tailstock pressure cap',(1.61,0,.95),(1,0,0),.06,.16,.051,'iron');joint(end,head,'pressure cap closes tailstock around feed bore')
    head_seal=m.sleeve('tailstock mandrel gland seal',(1.32,0,.95),(1,0,0),.07,.0795,.0775,'dark_recess');joint(head_seal,head,'mandrel gland seals actual head bore');joint(head_seal,mandrel,'mandrel gland retains pressure around mandrel outside')
    line_seal=m.sleeve('pressure inlet gland seal',(1.635,0,.95),(1,0,0),.05,.052,.0475,'dark_recess');joint(line_seal,end,'pressure-line gland seals cap bore')
    reservoir=m.box('closed forming-fluid reservoir',(-.98,1.25,.40),(.60,.70,.55),'gunmetal_dark');joint(reservoir,base,'forming reservoir grounded')
    cavity=m.box('temporary reservoir cavity',(-.98,1.25,.40),(.50,.60,.45),'iron',bevel=0);boolean(reservoir,cavity);bpy.data.objects.remove(cavity,do_unlink=True)
    drill(reservoir,(-1.10,.94,.40),.0288,.20,'Y')
    drill(reservoir,(-.98,1.49,.67),.03456,.18,'Z')
    lid=m.box('forming reservoir service lid',(-.98,1.25,.695),(.65,.75,.04),'iron');joint(lid,reservoir,'reservoir lid seated on housing')
    drill(lid,(-.98,1.49,.695),.03456,.10,'Z')
    pump=m.cyl('forming pressure pump motor',(-.98,1.25,.85),.13,.32,'gunmetal_dark','Y');joint(pump,lid,'pump carried on reservoir lid')
    pump_head=m.cyl('bored forming pump head',(-.98,1.49,.85),.13,.16,'iron','Y');drill(pump_head,(-.98,1.49,.85),.03456,.40,'Z');joint(pump_head,pump,'bored pressure head mounted on motor face')
    suction=m.pipe('reservoir suction standpipe',[(-.98,1.49,.53),(-.98,1.49,.85)],.048,'machine_steel');joint(suction,pump_head,'suction standpipe enters bored pump chamber');joint(suction,lid,'standpipe seated in matching lid bore')
    m.reuse('tp.mh7.factorio-fluid-mouth','forming-fluid intake',Matrix.Translation((-2,.50,.36))@Matrix.Rotation(math.pi,4,'Z'),'PIPING')
    receive=m.sleeve('forming-fluid receiving barrel',(-1.64,.50,.36),(1,0,0),.18,.285,.245,'iron');reducer=own(p.cast_reducing_manifold(m.cols['PIPING'],'Coaxial forming inlet reducer',(-1.55,.50,.36),(-1.28,.50,.40),.285,.04,m.mats['iron'],face_normal_at_start=(1,0,0),face_normal_at_end=(1,0,0)),'straight forming inlet reducer')
    joint(reducer,receive,'straight coaxial reducer joins receiving barrel')
    # Match the actual downstream bore instead of leaving a second annular lip.
    for vertex in list(reducer.data.vertices)[192:256]:
        vertex.co.y=.50+(vertex.co.y-.50)*(.0288/(.04*.49/.57));vertex.co.z=.40+(vertex.co.z-.40)*(.0288/(.04*.49/.57))
    reducer['nominal_output_bore_diameter_tiles']=.0576
    # Explicit 0.10-radius elbow clears the left cross-tie and lower foot.
    # A short quadratic fillet here folds its inside wall; use a real arc.
    feed_path=[(-1.28,.50,.40)]+[(-1.20+.10*math.cos(-math.pi/2+i*math.pi/24),.60+.10*math.sin(-math.pi/2+i*math.pi/24),.40) for i in range(13)]+[(-1.10,.96,.40)]
    feed=m.own(hollow_route(m.cols['PIPING'],'local forming-fluid feed',feed_path,.04,.0288,m.mats['iron'],rounded=False),'local forming-fluid feed','PIPING');joint(feed,reservoir,'forming-fluid line passes drilled wall into reservoir cavity')
    # Dedicated low service corridor lies inboard of the actuator, then turns
    # outboard only beyond its forward endpoint and the tailstock pedestal.
    pressure=m.pipe('supported high-pressure forming line',[(-.98,1.49,.85),(-.98,1.49,1.08),(-.98,1.75,1.08),(1.65,1.75,1.08),(1.65,1.75,.60),(1.65,.35,.60),(1.80,.35,.60),(1.80,0,.60),(1.80,0,.95),(1.61,0,.95)],.048,'machine_steel');joint(pressure,end,'pressure line reaches open annular tailstock feed');joint(pressure,pump_head,'pressure line starts in bored pump head');joint(pressure,line_seal,'pressure feed seated in sealed cap gland')
    for x in (-.9,.5,1.5):
        pad=m.box('rear pressure line support '+str(x),(x,1.75,.57),(.09,.10,.90),'iron');joint(pad,base,'rear pressure-line stanchion grounded')
        saddle=m.sleeve('rear pressure line saddle '+str(x),(x,1.75,1.08),(1,0,0),.07,.075,.049,'brass');joint(saddle,pad,'pressure saddle carried by stanchion');joint(saddle,pressure,'pressure line held in external saddle')
    # Plate loading rollers are open and accessible; precise native inserter
    # hand-to-image alignment is intentionally not part of this machine.
    for y in (-1.12,-1.48):
        roller=m.cyl('plate loading roller '+str(y),(-.20,y,.28),.085,1.50,'machine_steel','X')
        for x in (-1.02,.62):
            stand=m.box('loading roller support '+str((x,y)),(x,y,.19),(.13,.17,.14),'iron');joint(stand,base,'loading roller support grounded');joint(roller,stand,'loading roller supported at both ends')
    for z in (.385,.42):m.box('input steel plate '+str(z),(-.20,-1.30,z),(1.35,.55,.03),'machine_steel')
    m.reuse('tp.mh7.cogitator-console','front right cogitator',Matrix.Translation((1.35,-1.35,.80)),'CONTROLS')
    m.box('cogitator pedestal',(1.35,-1.35,.35),(.25,.25,.34),'iron');m.box('cogitator grounded sole',(1.35,-1.35,.15),(.40,.40,.06),'iron')
    def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
    for frame in range(0,290):
        u=(max(frame,1)-1)/288
        closed=smooth((u-.35)/.15) if u<.50 else 1 if u<.75 else 1-smooth((u-.75)/.15)
        pivot.rotation_euler.x=math.radians(-105)*(1-closed);pivot.keyframe_insert(data_path='rotation_euler',index=0,frame=frame)
        x=-1.62 if frame==0 or u<.03 else -.65+1.30*smooth((u-.03)/.22) if u<.25 else .65+(-1.62-.65)*smooth((u-.25)/.10) if u<.35 else -1.62
        trolley.location.x=x;trolley.keyframe_insert(data_path='location',index=0,frame=frame)
        formed.value=0 if frame==0 or u>.985 else smooth((u-.50)/.18);formed.keyframe_insert(data_path='value',frame=frame)
        # Factorio owns item creation/removal. Keep the displayed blank at real
        # size: shrinking it for handoff drags its fixed neck through the mandrel.
        for obj in (blank,plug,*flange):obj.scale=(1,1,1)
        bpy.context.view_layer.update();target=pivot.matrix_world@(lift_point-Vector((0,.73,.95)));axis=(target-anchor).normalized();length=(target-anchor).length
        ram.location=anchor+axis*.35;ram.rotation_euler=axis.to_track_quat('Z','Y').to_euler();ram.keyframe_insert(data_path='location',frame=frame);ram.keyframe_insert(data_path='rotation_euler',frame=frame)
        rod.location=anchor+axis*((.50+length)/2);rod.scale.z=length-.50;rod.rotation_euler=axis.to_track_quat('Z','Y').to_euler()
        for prop in ('location','rotation_euler','scale'):rod.keyframe_insert(data_path=prop,frame=frame)
    for action in bpy.data.actions:
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:key.interpolation='LINEAR'
    m.camera(1.05,6.7);s.frame_end=289;s['working_cycle_seconds']=12;s['animation_states']=json.dumps(dict(idle=[0],working=[7,43,79,115,151,187,223,259]))
    m.save(out,'fabricator-v02.blend')
    (out/'port_manifest.json').write_text(json.dumps(dict(machine='pressure-vessel-fabricator',footprint=[4,4],ports=[dict(id='forming_fluid_intake',model_mouth_center=[-2,.5,.36],outward_normal=[-1,0,0],native_position=None,native_direction=None,verified_native=False,fluid='forming medium; final gameplay fluid identity pending')],native_target=None),indent=2)+'\n')
    (out/'construction-receipt.json').write_text(json.dumps(dict(status='hydroforming construction pilot; independent mechanics/flow/export and finishing pending',source_sha256=sha(out/'fabricator-v02.blend'),contacts=contacts,
        owner_process='Steel plates are welded together, then high-pressure forming material is pumped inside to force the blank into a shape.',process='Weld supported two-sheet blank with clamp open; park torch; clamp exposed welded flanges in open frame; pressurize through sealed hollow mandrel; retain plastic formed shape; depressurize and open frame.',
        provenance='new_reconstruction_from_reference; historical v0.2 native bytes unrecovered',cycle_seconds=12,morph='Initially flattened welded plates expand into an exposed vessel; edge flanges and round pressure-seal necks remain fixed',
        pending=['Source and actual-export morph/hinge/torch/pressure-path clearance','Complete actual fluid-mouth reducer and reservoir/pump connection details','Model-specific finish and relevant audio','Four idle/working views and native 4x4 fluid/item prototype']),indent=2)+'\n')
    print('HYDROFORMING_PILOT_SAVED',sha(out/'fabricator-v02.blend'),flush=True)


if __name__=='__main__':main()
