"""Three indexed nests with supported cap slides and a travelling hollow head."""
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


def main():
    ap=argparse.ArgumentParser()
    for key in ('registry','material-donor','out'):ap.add_argument('--'+key,required=True)
    ap.add_argument('--material-prefix',default='TP Library | ')
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve assembler studies')
    out.mkdir(parents=True);m=MachineScene('Canister Assembler V02',args.material_donor,args.registry,args.material_prefix);s=m.scene;contacts=[]
    def joint(a,b,label):contacts.append(dict(a=a.name,b=b.name,label=label))
    def own(o,label):uv_for_visible_surface(o);return m.own(o,label,'PROCESS')
    def drill_box(obj,center,size):
        cutter=m.box('temporary witness opening',center,size,'iron',bevel=.018);bpy.context.view_layer.objects.active=obj
        mod=obj.modifiers.new('True front witness aperture only','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter;bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(cutter,do_unlink=True);bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6);bm.to_mesh(obj.data);bm.free()
    def clearance(obj,center,size):
        cutter=m.box('temporary rectangular clearance',center,size,'iron',bevel=0);bpy.context.view_layer.objects.active=obj
        for modifier in list(obj.modifiers):bpy.ops.object.modifier_apply(modifier=modifier.name)
        modifier=obj.modifiers.new('Actual machined slide channel','BOOLEAN');modifier.operation='DIFFERENCE';modifier.solver='EXACT';modifier.object=cutter;bpy.ops.object.modifier_apply(modifier=modifier.name)
        bpy.data.objects.remove(cutter,do_unlink=True);bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6);bm.to_mesh(obj.data);bm.free()
    def parent(o,control):o.parent=control;o.matrix_parent_inverse=Matrix.Identity(4);return o
    def empty(label,location=(0,0,0)):
        o=bpy.data.objects.new(m.prefix+label,None);m.cols['PROCESS'].objects.link(o);o.location=location;return o
    base=m.box('full 4x4 equipment footing',(0,0,.06),(3.88,3.88,.12),'ferrocrete_dark')
    bed=m.box('three-station bored mounting bed',(0,.20,.30),(3.28,.92,.14),'iron')
    for x in (-1.30,1.30):
        support=m.box('bed grounded pedestal '+str(x),(x,.20,.195),(.30,.78,.15),'martian_red');joint(support,base,'bed pedestal grounded');joint(bed,support,'bed seated on end pedestal')
    cap_controls=[];cap_rods=[];cap_lifts=[];canisters=[]
    for x in (-1.0,0.0,1.0):
        nest=m.sleeve('indexed canister nest '+str(x),(x,.20,.405),(0,0,1),.07,.335,.245,'iron');joint(nest,bed,'annular nest seated on mounting bed')
        sole=m.cyl('canister closed bottom '+str(x),(x,.20,.48),.28,.08,'gunmetal_dark');joint(sole,nest,'canister supported in indexed nest')
        # One continuous hollow shell, formed shoulder and real open neck.
        profile=[(.28,.52),(.28,1.17),(.26,1.24),(.18,1.34),(.10,1.39),(.10,1.45)]
        n=64;verts=[];faces=[]
        for inner in (False,True):
            for radius,z in profile:
                r=radius-(.025 if inner else 0)
                for i in range(n):a=math.tau*i/n;verts.append((x+r*math.cos(a),.20+r*math.sin(a),z))
        count=len(profile)*n
        for side in (0,1):
            off=side*count
            for j in range(len(profile)-1):
                for i in range(n):
                    k=(i+1)%n;f=(off+j*n+i,off+j*n+k,off+(j+1)*n+k,off+(j+1)*n+i);faces.append(tuple(reversed(f)) if side else f)
        for end in (0,len(profile)-1):
            for i in range(n):k=(i+1)%n;f=(end*n+i,count+end*n+i,count+end*n+k,end*n+k);faces.append(tuple(reversed(f)) if end else f)
        body=own(mesh_object(m.cols['PROCESS'],'Hollow formed canister shell',verts,faces,m.mats['machine_steel']),'hollow canister shell '+str(x));canisters.append(body)
        drill_box(body,(x,-.075,.86),(.12,.12,.34));joint(body,sole,'hollow canister shell closed by bottom plate')
        # The window remains a shallow front aperture, never a through-slot.
        glass=m.box('recessed witness pane '+str(x),(x,-.066,.86),(.10,.012,.30),'dark_recess',bevel=.010)
        for dx in (-.069,.069):joint(m.box('witness window side flange '+str((x,dx)),(x+dx,-.083,.86),(.024,.027,.37),'brass'),body,'witness flange seated on actual shell')
        for z in (.683,1.037):joint(m.box('witness window end flange '+str((x,z)),(x,-.083,z),(.16,.027,.025),'brass'),body,'witness end flange seated on shell')
        joint(glass,body,'recessed pressure witness pane retained inside front wall')
        for z in (.60,1.14):
            band=m.sleeve('canister retaining band '+str((x,z)),(x,.20,z),(0,0,1),.065,.303,.279,'iron');joint(band,body,'retaining band seated on cylindrical shell')
            for i in range(8):
                a=math.tau*i/8;bolt=m.cyl('band retaining head '+str((x,z,i)),(x+.30*math.cos(a),.20+.30*math.sin(a),z),.014,.035,'brass','Z',vertices=6);joint(bolt,band,'retaining head mounted in actual band')
        # Two supported cap rails straddle the neck, leaving the fill core open.
        for dx in (-.145,.145):
            rail=m.box('cap transfer rail '+str((x,dx)),(x+dx,.68,1.51),(.035,.72,.035),'machine_steel')
            post=m.box('rear cap rail support '+str((x,dx)),(x+dx,1.00,.81125),(.065,.065,1.3825),'iron');joint(post,base,'rear cap rail post grounded on footing');joint(rail,post,'cap rail held by rear support')
        slide=empty('cap horizontal slide '+str(x));lift=empty('cap short lift '+str(x));lift.parent=slide
        cap=m.cyl('pressure cap plate '+str(x),(x,.20,1.47),.128,.035,'machine_steel');parent(cap,lift)
        rim=m.sleeve('cap locking lip '+str(x),(x,.20,1.457),(0,0,1),.025,.13,.102,'brass');parent(rim,lift);joint(rim,cap,'locking lip seated on cap underside')
        carrier=m.box('cap carrier rear saddle '+str(x),(x,.37,1.54),(.34,.08,.07),'iron');parent(carrier,slide)
        for dx in (-.145,.145):clearance(carrier,(x+dx,.37,1.51),(.037,.20,.037))
        for dx in (-.14,.14):
            jaw=m.box('cap rim lifting jaw '+str((x,dx)),(x+dx,.20,1.49),(.035,.22,.055),'iron');parent(jaw,lift);joint(jaw,cap,'cap jaw engages outer locking lip')
            guide=m.box('cap jaw lift guide '+str((x,dx)),(x+dx,.34,1.535),(.06,.12,.10),'machine_steel');parent(guide,slide)
            clearance(guide,(x+math.copysign(.145,dx),.34,1.51),(.037,.20,.037));clearance(guide,(x+dx,.291,1.54),(.037,.042,.22))
            joint(guide,carrier,'short jaw guide retained in carrier')
        cylinder=m.sleeve('cap slide actuator '+str(x),(x,1.15,1.54),(0,1,0),.30,.055,.026,'gunmetal_dark')
        back=m.box('cap actuator rear mount '+str(x),(x,1.15,.8025),(.18,.27,1.365),'martian_red');joint(back,base,'cap actuator mount grounded');
        collar=m.sleeve('cap actuator mounting collar '+str(x),(x,1.15,1.54),(0,1,0),.10,.070,.054,'iron');joint(collar,back,'actuator collar seated on grounded cradle');joint(cylinder,collar,'cap cylinder held in actual collar')
        rod=m.cyl('cap slide piston '+str(x),(x,.70,1.54),.025,1,'machine_steel','Y');joint(rod,carrier,'piston nose seated in sliding cap saddle');cap_controls.append(slide);cap_lifts.append(lift);cap_rods.append(rod)
    # Rigid overhead X guide and one guided dual filling/sealing carriage.
    for x in (-1.62,1.62):
        foot=m.box('gantry grounded shoe '+str(x),(x,.93,.19),(.40,.66,.14),'iron');column=m.box('red gantry upright '+str(x),(x,.95,1.28),(.20,.30,2.04),'martian_red');joint(foot,base,'gantry shoe grounded');joint(column,foot,'gantry upright on shoe')
    beam=m.box('spanning head guide beam',(0,.95,2.37),(3.64,.36,.18),'martian_red')
    for x in (-1.62,1.62):joint(beam,s.objects[m.prefix+'red gantry upright '+str(x)],'guide beam carried by end upright')
    guide=m.box('ground head linear guide',(0,.725,2.37),(3.14,.09,.10),'machine_steel')
    for x in (-1.25,0,1.25):joint(m.box('linear guide standoff '+str(x),(x,.775,2.37),(.10,.08,.07),'iron'),beam,'linear guide standoff seated on beam')
    travel=empty('head X index control');carriage=m.box('retained travelling head carriage',(0,.64,2.37),(.40,.14,.27),'iron');parent(carriage,travel);joint(carriage,guide,'carriage retained on actual X guide')
    bridge=m.sleeve('carriage annular tool bracket',(0,.20,2.25),(0,0,1),.08,.22,.10,'iron');parent(bridge,travel)
    rear=m.box('moving head rear crosshead',(0,.64,2.20),(.46,.14,.10),'iron');parent(rear,travel);joint(rear,carriage,'rear crosshead mounted under actual carriage')
    for x in (-.18,.18):
        arm=m.box('open cantilever side arm '+str(x),(x,.46,2.25),(.10,.52,.10),'iron');parent(arm,travel);joint(arm,rear,'cantilever arm carried by rear crosshead');joint(arm,bridge,'annular tool mount held between side arms')
    housing=m.sleeve('hollow electric press housing',(0,.20,2.10),(0,0,1),.36,.14,.091,'gunmetal_dark');parent(housing,travel);joint(housing,bridge,'annular press housing mounted under carriage bracket')
    punch=m.sleeve('annular cap sealing punch',(0,.20,1.80),(0,0,1),.12,.115,.055,'machine_steel');parent(punch,travel)
    piston=m.sleeve('telescoping hollow sealing ram',(0,0,0),(0,0,1),1,.09,.055,'machine_steel');parent(piston,travel)
    nozzle=m.sleeve('telescoping pellet fill tube',(0,.20,1.95),(0,0,1),.30,.045,.0324,'brass');parent(nozzle,travel)
    # Moving hopper and feed are entirely carried by the carriage; no fixed
    # pipe or lead bridges a moving axis without a real sliding interface.
    funnel=own(mesh_object(m.cols['PROCESS'],'Open metering hopper',[(r*math.cos(math.tau*i/64),.48+r*math.sin(math.tau*i/64),z) for r,z in ((.06,2.39),(.23,2.72),(.255,2.78),(.22,2.77),(.20,2.71),(.04,2.39)) for i in range(64)],
        [(j*64+i,j*64+(i+1)%64,(j+1)*64+(i+1)%64,(j+1)*64+i) for j in range(5) for i in range(64)],m.mats['iron']),'open metered pellet hopper');parent(funnel,travel);funnel.location.z=.10
    support=m.beam('moving hopper bracket',(.32,.48,2.445),(.17,.48,2.70),.07,.06);parent(support,travel);joint(funnel,support,'hopper bracket meets outside wall, clear of throat')
    feed_path=[(0,.38+.10*math.cos(i*math.pi/24),2.47-.10*math.sin(i*math.pi/24)) for i in range(13)]
    feed_path += [(0,.30-.10*math.sin(i*math.pi/24),2.27+.10*math.cos(i*math.pi/24)) for i in range(13)]
    feed_path += [(0,.20,2.10)]
    supply=m.own(hollow_route(m.cols['PIPING'],'carriage pellet feed bore',feed_path,.065,.0468,m.mats['iron'],rounded=False),'carriage pellet feed bore','PIPING');parent(supply,travel)
    # A bored valve body bridges the deliberate blade gap. Its actual slot
    # clears the translating shutter; an upper notch clears the drive lug.
    valve=m.sleeve('bored sliding gate valve body',(0,.48,2.485),(0,0,1),.07,.095,.0468,'iron');parent(valve,travel)
    clearance(valve,(0,.48,2.483),(.60,.174,.017))
    clearance(valve,(.16,.43,2.525),(.18,.029,.07))
    joint(valve,funnel,'bored valve inlet seated around hopper throat')
    joint(supply,valve,'true-radius feed seated in bored valve outlet')
    guide_tube=m.sleeve('stationary nozzle guide sleeve',(0,.20,1.895),(0,0,1),.59,.052,.046,'machine_steel');parent(guide_tube,travel);joint(guide_tube,supply,'stationary guide seated inside fixed feed end')
    # Offset crank drives a real sliding gate. A solid shaft through the
    # hopper center blocks pellets even when it rotates, so keep the drive
    # outside the bore and open the throat with the guided shutter instead.
    meter=m.cyl('supported pellet metering spindle',(.45,.20,2.25),.026,.30,'machine_steel','Z');parent(meter,travel)
    crank=m.beam('meter eccentric arm',(0,0,-.14),(.08,0,-.14),.03,.03,'brass');parent(crank,meter)
    pin=m.cyl('meter eccentric pin',(.08,0,-.1575),.012,.08,'machine_steel');parent(pin,meter);joint(pin,crank,'eccentric pin retained on crank arm')
    for z in (2.18,2.32):
        bearing=m.sleeve('meter spindle bearing '+str(z),(.45,.20,z),(0,0,1),.04,.055,.027,'brass');parent(bearing,travel);joint(bearing,meter,'offset metering shaft retained in bearing')
        stand=m.beam('meter bearing outboard bridge '+str(z),(.18,.60,2.25),(.55,.60,2.25),.04,.04);parent(stand,travel);joint(stand,s.objects[m.prefix+'open cantilever side arm 0.18'],'bearing bridge grounded on head side arm')
        riser=m.beam('meter bearing outboard riser '+str(z),(.55,.60,2.25),(.55,.20,z),.04,.04);parent(riser,travel);joint(riser,stand,'outboard bearing riser carried by bridge')
        tip=m.beam('meter bearing radial seat '+str(z),(.55,.20,z),(.50,.20,z),.04,.04);parent(tip,travel);joint(tip,riser,'radial bearing seat carried by outboard riser');joint(tip,bearing,'bearing supported outside its shaft bore')
    gate_control=empty('meter gate slide control');parent(gate_control,travel)
    gate=m.box('actual sliding pellet gate',(0,.48,2.483),(.18,.17,.014),'machine_steel',bevel=.002);parent(gate,gate_control)
    lug_parts=[]
    points=[(.09,.43,2.483),(.09,.43,2.525),(.09,.33,2.525),(.28,.33,2.525),(.28,.33,2.04),(.20,.20,2.04)]
    for index,(a,b) in enumerate(zip(points,points[1:])):
        piece=m.beam('gate offset drive arm '+str(index),a,b,.025,.025);parent(piece,gate_control)
        joint(piece,lug_parts[-1] if lug_parts else gate,'offset drive arm connected above and outside fixed ways');lug_parts.append(piece)
    gate_pin=m.cyl('gate connecting-rod pivot',(.20,.20,2.06),.012,.07,'machine_steel');parent(gate_pin,gate_control);joint(gate_pin,lug_parts[-1],'drive pivot retained on lower offset arm')
    conrod=m.box('meter connecting rod',(0,0,0),(.025,.025,1),'iron',bevel=.003);parent(conrod,travel);joint(conrod,pin,'connecting rod seated on eccentric pin');joint(conrod,gate_pin,'connecting rod seated on gate drive pivot')
    mount=m.box('meter gate guide mount',(.32,.48,2.445),(.035,.24,.08),'iron');parent(mount,travel);joint(support,mount,'hopper bracket grounded on gate frame mount')
    brace=m.beam('gate guide bracket',(.18,.60,2.25),(.32,.48,2.44),.06,.04);parent(brace,travel);joint(brace,mount,'gate mount supported by bracket');joint(brace,s.objects[m.prefix+'open cantilever side arm 0.18'],'gate guide bracket grounded on side arm')
    for y in (.385,.575):
        rail=m.box('pellet gate linear way '+str(y),(.09,y,2.485),(.46,.025,.03),'iron',bevel=.002);parent(rail,travel);clearance(rail,(.09,.395 if y<.48 else .565,2.483),(.60,.020,.017));joint(rail,mount,'gate way supported by end mount')
    # Supported conductor rails and front sliding pads, derived from the
    # independently corrected fabricator construction rather than floating wire.
    for z in (2.50,2.57):
        bus=m.box('insulated conductor rail '+str(z),(0,1.10,z),(3.12,.035,.025),'brass')
        for x in (-1.30,0,1.30):
            mount=m.box('rear conductor mounting foot '+str((x,z)),(x,1.115,2.455),(.09,.15,.02),'iron');joint(mount,beam,'rear conductor foot seated on beam')
            ins=m.box('rear conductor insulator '+str((x,z)),(x,1.175,(2.46+z)/2),(.05,.04,z-2.46),'dark_recess');joint(ins,mount,'conductor insulator grounded on rear mounting foot')
            tab=m.box('conductor rear support tab '+str((x,z)),(x,1.14,z),(.04,.07,.022),'dark_recess');joint(tab,ins,'conductor tab supported on insulator');joint(bus,tab,'conductor rail supported from behind')
        shoe=m.box('sliding current collector '+str(z),(0,1.055,z),(.12,.055,.055),'iron');parent(shoe,travel)
        pad=m.box('conductive sliding pad '+str(z),(0,1.081,z),(.06,.022,.018),'brass',bevel=.001);parent(pad,travel);joint(pad,shoe,'spring pad retained in collector');joint(pad,bus,'pad bears on conductor front face')
        lead=m.pipe('carriage mounted power lead '+str(z),[(0,1.04,z),(-.32,1.04,z),(-.32,.58,z),(-.32,.58,2.27),(-.18,.64,2.27)],.018,'gunmetal_dark');parent(lead,travel);joint(lead,shoe,'lead attached to sliding current shoe');joint(lead,carriage,'lead terminates in moving head carriage')
    m.reuse('tp.mh7.cogitator-console','front right cogitator',Matrix.Translation((1.29,-1.29,.80)),'CONTROLS')
    m.box('cogitator grounded pedestal',(1.29,-1.29,.35),(.25,.25,.34),'iron');m.box('cogitator mounting sole',(1.29,-1.29,.15),(.40,.40,.06),'iron')
    for x in (-1.0,0.0):
        roller=m.cyl('shell loading roller '+str(x),(x,-1.13,.24),.07,.60,'machine_steel','X')
        for dx in (-.38,.38):joint(m.box('loading roller support '+str((x,dx)),(x+dx,-1.13,.18),(.14,.14,.12),'iron'),base,'loading roller stand grounded')
    def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
    for frame in range(386):
        t=0 if frame==0 else (frame-1)/24
        station=0 if t<5 else 1 if t<10 else 2;u=(t-station*5)/4
        x=(-1,0,1)[station]
        if 4<=t<5:x=-1+smooth(t-4)
        elif 9<=t<10:x=smooth(t-9)
        elif t>=14:x=1-2*smooth((t-14)/2)
        travel.location.x=x;travel.keyframe_insert(data_path='location',index=0,frame=frame)
        fill=smooth((u-.22)/.10) if u<.32 else 1 if u<.48 else 1-smooth((u-.48)/.12)
        fill=0 if u>1 or frame==0 else fill
        nozzle.location.z=-.42*fill;nozzle.keyframe_insert(data_path='location',index=2,frame=frame)
        press=smooth((u-.78)/.08) if u<.86 else 1 if u<.89 else 1-smooth((u-.89)/.05)
        press=0 if u>1 or frame==0 else press
        punch.location.z=-.2525*press;punch.keyframe_insert(data_path='location',index=2,frame=frame)
        bottom=1.86-.2525*press;piston.location=(0,.20,(2.10+bottom)/2);piston.scale.z=2.10-bottom
        piston.keyframe_insert(data_path='location',frame=frame);piston.keyframe_insert(data_path='scale',frame=frame)
        theta=math.pi*(1-fill);meter.rotation_euler.z=theta;meter.keyframe_insert(data_path='rotation_euler',index=2,frame=frame)
        gate_x=.25+.08*math.cos(theta)-math.sqrt(.17**2-(.08*math.sin(theta))**2)
        gate_control.location.x=gate_x;gate_control.keyframe_insert(data_path='location',index=0,frame=frame)
        a=Vector((.45+.08*math.cos(theta),.20+.08*math.sin(theta),2.075));b=Vector((gate_x+.20,.20,2.075))
        conrod.location=(a+b)/2;conrod.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();conrod.scale.z=(b-a).length
        for prop in ('location','rotation_euler','scale'):conrod.keyframe_insert(data_path=prop,frame=frame)
        for index,(slide,lift,rod) in enumerate(zip(cap_controls,cap_lifts,cap_rods)):
            q=(t-index*5)/4;open_amount=smooth((q-.06)/.12) if q<.18 else 1 if q<.60 else 1-smooth((q-.60)/.14)
            raise_amount=smooth(q/.06) if q<.06 else 1 if q<.74 else 1-smooth((q-.74)/.06)
            if q<0 or q>1 or frame==0:open_amount=raise_amount=0
            slide.location.y=.55*open_amount;slide.keyframe_insert(data_path='location',index=1,frame=frame)
            lift.location.z=.09*raise_amount;lift.keyframe_insert(data_path='location',index=2,frame=frame)
            front=.35+.55*open_amount;rod.location.y=(1.10+front)/2;rod.scale.z=1.10-front
            rod.keyframe_insert(data_path='location',index=1,frame=frame);rod.keyframe_insert(data_path='scale',index=2,frame=frame)
    for action in bpy.data.actions:
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:key.interpolation='LINEAR'
    m.camera(1.25,6.9);s.frame_end=385;s['working_cycle_seconds']=16;s['animation_states']=json.dumps(dict(idle=[0],working=[7+24*i for i in range(16)]))
    m.save(out,'assembler-v02.blend')
    (out/'port_manifest.json').write_text(json.dumps(dict(machine='canister-assembler',footprint=[4,4],ports=[],native_target=None,item_inputs=['formed metallicized pellet','empty pressure shell'],item_output='contained metallicized pellet',native_verified=False),indent=2)+'\n')
    (out/'construction-receipt.json').write_text(json.dumps(dict(status='V02 slower indexing and moving-clearance candidate; independent mechanics/export/finish/native pending',source_sha256=sha(out/'assembler-v02.blend'),contacts=contacts,
        provenance='new_reconstruction_from_reference; historical v0.2 native bytes unrecovered',three_primary_canisters=True,indexing='One guided head indexes across three fixed supported canister nests; independent cap slides expose and reseat each neck.',
        cycle_seconds=16,station_seconds=4,station_start_seconds=[0,5,10],between_station_index_seconds=1,return_seconds=2,feed_start_z=2.47,hopper_base_z=2.49,hopper_top_z=2.88,
        native_contract='Use live pellet references and the existing seal operation; preserve health, quality, decay stage and remaining lifetime. Never convert through an ordinary recipe that refreshes pellet state.',
        pending=['Independent moving assembly, cap/neck and granular feed bore audit','GLB state and loop inspection','Dedicated surfaces, appropriate sound and four directions','State-preserving native pellet/shell assembly and actual inserters']),indent=2)+'\n')
    print('ASSEMBLER_CONSTRUCTION_SAVED',sha(out/'assembler-v02.blend'),len(contacts),'CONTACTS',flush=True)


if __name__=='__main__':main()
