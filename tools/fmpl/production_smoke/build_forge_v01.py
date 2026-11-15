"""Distinct 3x3 pellet forge: open hopper, auger, guided press and item tray."""
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
from mechanical_routes import mesh_object
from blender_build import uv_for_visible_surface


def main():
    ap=argparse.ArgumentParser()
    for name in ('registry','material-donor','out'):ap.add_argument('--'+name,required=True)
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);out=Path(args.out).resolve()
    if out.exists():raise FileExistsError('Preserve forge studies')
    out.mkdir(parents=True);m=MachineScene('Pelletization Forge V01',args.material_donor,args.registry);s=m.scene;contacts=[]
    def joint(a,b,label):contacts.append(dict(a=a.name,b=b.name,label=label))
    def own(ob,label,role='PROCESS'):uv_for_visible_surface(ob);return m.own(ob,label,role)
    def cut(ob,center,radius,depth,axis='Z'):
        bpy.context.view_layer.objects.active=ob
        for mod in list(ob.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.ops.mesh.primitive_cylinder_add(vertices=40,radius=radius,depth=depth,location=center);cutter=bpy.context.object
        if axis=='Y':cutter.rotation_euler.x=math.pi/2
        if axis=='X':cutter.rotation_euler.y=math.pi/2
        bpy.context.view_layer.objects.active=ob;mod=ob.modifiers.new('Actual process/guide opening','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter
        bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
        bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6);bmesh.ops.triangulate(bm,faces=list(bm.faces));bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-6);bm.to_mesh(ob.data);bm.free()
    def root(label,center,objects):
        parent=bpy.data.objects.new(m.prefix+label,None);m.cols['PROCESS'].objects.link(parent);parent.location=center;bpy.context.view_layer.update()
        for ob in objects:ob.parent=parent;ob.matrix_parent_inverse=Matrix.Translation(center).inverted()
        return parent
    base=m.box('full equipment footing',(0,0,.06),(2.88,2.88,.12),'ferrocrete_dark')
    for x in (-.89,.89):
        shoe=m.box('press column grounded shoe '+str(x),(x,-.10,.18),(.46,.52,.12),'iron')
        web=m.box('red press column web '+str(x),(x,-.10,1.09),(.10,.28,1.74),'martian_red')
        joint(shoe,base,'press shoe on footing');joint(web,shoe,'column web seated on shoe')
        for y in (-.27,.07):
            flange=m.box('red press column flange '+str((x,y)),(x,y,1.09),(.26,.05,1.74),'martian_red');joint(flange,shoe,'column flange on grounded shoe')
        for dx in (-.16,.16):m.cyl('press foundation anchor '+str((x,dx)),(x+dx,-.25,.265),.025,.05,'brass',vertices=6)
    beam=m.box('rigid overhead press crossbeam',(0,-.10,1.94),(2.15,.36,.16),'martian_red');cut(beam,(0,-.10,1.94),.161,.30)
    for x in (-.89,.89):joint(beam,s.objects[m.prefix+'red press column web '+str(x)],'crossbeam carried by grounded columns')
    bed=m.box('die supporting transverse bed',(0,-.10,.46),(1.60,.58,.22),'gunmetal_dark');cut(bed,(0,-.10,.46),.102,.40)
    for x in (-.45,.45):
        pier=m.box('die bed grounded pier '+str(x),(x,-.10,.25),(.30,.50,.26),'iron');joint(pier,base,'die pier grounded');joint(bed,pier,'die bed on pier')
    # Conical extrusion die: a genuine narrowing, open core.
    n=64;verts=[]
    for r,z in ((.15,.54),(.15,.66),(.08,.66),(.055,.54)):
        verts.extend((r*math.cos(math.tau*i/n),-.10+r*math.sin(math.tau*i/n),z) for i in range(n))
    faces=[]
    for row in range(4):
        nxt=(row+1)%4
        for i in range(n):j=(i+1)%n;faces.append((row*n+i,row*n+j,nxt*n+j,nxt*n+i))
    die=own(mesh_object(m.cols['PROCESS'],'Actual open tapered die',verts,faces,m.mats['machine_steel']),'open tapered pellet die');joint(die,bed,'die seated over drilled bed core')
    for k in range(4):
        a=math.pi/4+k*math.pi/2;m.cyl('die flange stud '+str(k),(.20*math.cos(a),-.10+.20*math.sin(a),.60),.022,.06,'brass',vertices=6)
    crosshead=m.box('guided moving crosshead',(0,-.10,1.32),(.76,.24,.11),'machine_steel')
    moving=[crosshead]
    for x in (-.30,.30):
        cut(crosshead,(x,-.10,1.32),.036,.30)
        guide=m.cyl('fixed press guide rod '+str(x),(x,-.10,1.25),.0345,1.20,'machine_steel')
        lower=m.sleeve('guide lower socket '+str(x),(x,-.10,.645),(0,0,1),.15,.075,.035,'iron')
        upper=m.sleeve('guide upper socket '+str(x),(x,-.10,1.85),(0,0,1),.14,.075,.035,'iron')
        boss=m.sleeve('moving crosshead guide bearing '+str(x),(x,-.10,1.32),(0,0,1),.16,.073,.0355,'brass')
        moving.append(boss);joint(lower,bed,'lower guide socket seated on bed');joint(guide,lower,'guide supported in close-fitting lower socket');joint(upper,beam,'upper guide socket carried by crossbeam');joint(boss,crosshead,'moving bearing retained in crosshead')
    punch=m.cyl('on-axis press punch',(0,-.10,.94),.050,.10,'machine_steel');moving.append(punch)
    neck=m.cyl('punch mounting shank',(0,-.10,1.12),.043,.30,'iron');moving.append(neck);joint(punch,neck,'press punch on retained shank');joint(neck,crosshead,'punch shank carried by crosshead')
    press=root('complete guided ram',(0,-.10,1.32),moving)
    actuator=m.sleeve('closed hydraulic press cylinder',(0,-.10,2.14),(0,0,1),.52,.16,.048,'gunmetal_dark')
    mount=m.sleeve('actuator seated mounting flange',(0,-.10,1.965),(0,0,1),.09,.22,.159,'iron')
    cap=m.cyl('closed actuator pressure head',(0,-.10,2.435),.18,.07,'iron')
    gland=m.sleeve('actuator piston gland',(0,-.10,1.88),(0,0,1),.10,.09,.0465,'brass')
    piston=m.cyl('telescoping press piston rod',(0,-.10,1.6),.045,1,'machine_steel')
    joint(mount,beam,'actuator flange supported by crossbeam');joint(actuator,mount,'actuator seated through flange');joint(cap,actuator,'closed cylinder head on body');joint(gland,actuator,'piston gland seated in cylinder')
    for x in (-.185,.185):
        for y in (-.20,0):m.cyl('actuator mounting stud '+str((x,y)),(x,y,2.02),.022,.08,'brass',vertices=6)
    for z in (2.03,2.26):m.sleeve('cylinder retaining band '+str(z),(0,-.10,z),(0,0,1),.03,.18,.159,'brass')
    # Open tapered feeder with real wall thickness and no opaque lid.
    verts=[]
    for xhalf,yhalf,z in ((.50,.36,1.60),(.105,.105,.80),(.465,.325,1.60),(.09,.09,.80)):
        verts.extend((sx*xhalf,.80+sy*yhalf,z) for sx,sy in ((-1,-1),(1,-1),(1,1),(-1,1)))
    faces=[]
    for i in range(4):j=(i+1)%4;faces.extend(((i,j,4+j,4+i),(8+i,12+i,12+j,8+j),(i,8+i,8+j,j),(4+i,4+j,12+j,12+i)))
    hopper=own(mesh_object(m.cols['PROCESS'],'Open feeder hopper',verts,faces,m.mats['machine_steel']),'open raw pellet hopper')
    for x in (-.50,.50):m.box('hopper top side lip '+str(x),(x,.80,1.60),(.045,.76,.045),'iron')
    for y in (.44,1.16):m.box('hopper top end lip '+str(y),(0,y,1.60),(1.04,.045,.045),'iron')
    for x in (-.48,.48):
        foot=m.box('hopper grounded foot '+str(x),(x,.80,.18),(.25,.40,.12),'iron')
        post=m.box('hopper supported upright '+str(x),(x,.80,.91),(.10,.10,1.38),'martian_red')
        back=m.beam('hopper rear diagonal brace '+str(x),(x,1.19,.22),(x,.80,1.41),.06,.06,'iron')
        backfoot=m.box('hopper back brace grounded shoe '+str(x),(x,1.19,.18),(.20,.24,.12),'iron')
        joint(foot,base,'hopper foot grounded');joint(post,foot,'hopper post on foot');joint(hopper,post,'open hopper rim carried by posts');joint(back,backfoot,'hopper brace on actual rear shoe');joint(backfoot,base,'rear brace shoe grounded')
    feed_z=.80
    housing=m.sleeve('short auger feed housing',(0,.55,feed_z),(0,1,0),.90,.13,.09,'iron')
    cut(housing,(0,.80,feed_z+.13),.082,.24)
    joint(housing,hopper,'hopper enters drilled upper feed port')
    for y in (.27,.94):
        foot=m.box('auger grounded foot '+str(y),(0,y,.18),(.32,.22,.12),'gunmetal_dark')
        post=m.box('auger supporting pedestal '+str(y),(0,y,.43),(.15,.15,.43),'martian_red')
        seat=m.sleeve('auger supported saddle '+str(y),(0,y,feed_z),(0,1,0),.12,.155,.129,'iron')
        # Post carries the lower outside of its saddle, never the flow core.
        post.location.z=(.24+feed_z-.155)/2;post.dimensions.z=feed_z-.155-.24
        joint(post,foot,'auger pedestal grounded');joint(seat,post,'auger saddle on pedestal');joint(housing,seat,'auger housing retained in saddle')
    auger_root=bpy.data.objects.new(m.prefix+'auger rotor',None);m.cols['PROCESS'].objects.link(auger_root);auger_root.location=(0,0,feed_z)
    shaft=m.cyl('auger supported drive shaft',(0,.63,feed_z),.025,1.0,'machine_steel','Y');bpy.context.view_layer.update();shaft.parent=auger_root;shaft.matrix_parent_inverse=Matrix.Translation((0,0,-feed_z))
    verts=[];segments=96
    for i in range(segments+1):
        t=i/segments;a=math.tau*3*t
        for r,dy in ((.023,-.004),(.075,-.004),(.075,.004),(.023,.004)):verts.append((r*math.cos(a),.16+.82*t+dy,r*math.sin(a)))
    faces=[(0,3,2,1),(segments*4,segments*4+1,segments*4+2,segments*4+3)]
    for i in range(segments):
        for k in range(4):j=(k+1)%4;faces.append((i*4+k,i*4+j,(i+1)*4+j,(i+1)*4+k))
    flight=own(mesh_object(m.cols['PROCESS'],'Retained auger helical flight',verts,faces,m.mats['brass']),'actual auger flight');flight.parent=auger_root;flight.matrix_parent_inverse=Matrix.Identity(4)
    motor=m.cyl('rear feeder drive motor',(0,1.22,feed_z),.16,.30,'gunmetal_dark','Y')
    for x in (-.11,.11):
        leg=m.box('feeder motor grounded leg '+str(x),(x,1.22,.43),(.09,.24,.60),'iron');joint(leg,base,'motor leg grounded');joint(motor,leg,'motor supported on legs')
    endcap=m.sleeve('auger rear bearing closure',(0,1.015,feed_z),(0,1,0),.04,.14,.026,'iron')
    coupling=m.sleeve('auger keyed drive coupling',(0,1.06,feed_z),(0,1,0),.10,.058,.025,'brass')
    joint(endcap,housing,'feed bearing closure on housing');joint(coupling,motor,'drive coupling retained by motor')
    # Solid stock leaves the auger onto an open gravity shoe. This stays behind
    # the punch sweep, rather than routing a narrow pipe through the press.
    normal_z=.09/math.hypot(.09,.10)
    chute=m.beam('open die feed shoe floor',(0,.10,.71-.0125*normal_z),(0,.01,.61-.0125*normal_z),.20,.025,'machine_steel','PROCESS')
    for x in (-.10,.10):m.beam('die feed shoe side '+str(x),(x,.10,.755),(x,.01,.655),.025,.11,'iron','PROCESS')
    joint(chute,housing,'open feed shoe meets lower auger lip')
    # Open U extraction chute below the drilled bed, with front pickup tray.
    chute_floor=m.beam('inclined product chute floor',(0,-.10,.29),(0,-1.08,.18),.34,.035,'machine_steel')
    for x in (-.17,.17):m.beam('product chute side '+str(x),(x,-.10,.34),(x,-1.08,.23),.025,.10,'iron')
    for y in (-.32,-.85):
        u=(y+.10)/(-1.08+.10);top=.29-.11*u-.0175/math.sqrt(1+(.11/.98)**2)
        support=m.box('product chute grounded support '+str(y),(0,y,(.12+top)/2),(.32,.14,top-.12),'iron');joint(support,base,'extraction chute support grounded');joint(support,chute_floor,'chute floor carried on grounded pedestal')
    tray=m.box('open front item pickup tray',(0,-1.08,.155),(.78,.56,.05),'machine_steel')
    for x in (-.37,.37):m.box('pickup tray side guard '+str(x),(x,-1.08,.245),(.04,.56,.13),'iron')
    m.reuse('tp.mh7.cogitator-console','front left cogitator',Matrix.Translation((-1.05,-.92,.77)),'CONTROLS')
    m.box('cogitator grounded pedestal',(-1.05,-.92,.3325),(.26,.26,.305),'iron');m.box('cogitator sole',(-1.05,-.92,.155),(.42,.40,.07),'iron')
    m.pipe('short protected console conduit',[(-1.05,-.80,.53),(-1.05,-.48,.53),(-.90,-.27,.53)],.026,'gunmetal_dark')
    workpiece=m.cyl('one visible transforming pellet',(0,-.10,.70),.075,.10,'machine_steel')
    def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
    for frame in range(0,194):
        u=(max(frame,1)-1)/192
        load=0 if u<.15 else smooth((u-.15)/.25) if u<.40 else 1 if u<.50 else 1-smooth((u-.50)/.20) if u<.70 else 0
        press.location.z=1.32-.34*load;press.keyframe_insert(data_path='location',index=2,frame=frame)
        lower=press.location.z+.055;piston.location.z=(1.92+lower)/2;piston.scale.z=1.92-lower
        piston.keyframe_insert(data_path='location',frame=frame);piston.keyframe_insert(data_path='scale',frame=frame)
        auger_root.rotation_euler.y=math.tau*5*u;auger_root.keyframe_insert(data_path='rotation_euler',index=1,frame=frame)
        if frame==0 or u<.05 or u>.98:workpiece.scale=(0,0,0)
        elif u<.50:
            q=max(0,(load-.4117647)/.5882353);h=.10-.02*q
            workpiece.scale=(1-.30*q,1-.30*q,h/.10);workpiece.location=(0,-.10,.70 if q==0 else .89-.34*load-h/2)
        elif u<.60:
            workpiece.scale=(.70,.70,.80);workpiece.location=(0,-.10,.51-.18*smooth((u-.50)/.10))
        else:
            t=smooth((u-.60)/.32);workpiece.scale=(.70,.70,.80);workpiece.location=(0,-.10-1.05*t,.33-.11*t)
        workpiece.keyframe_insert(data_path='location',frame=frame);workpiece.keyframe_insert(data_path='scale',frame=frame)
    for action in bpy.data.actions:
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:key.interpolation='LINEAR'
    m.camera(1.05,5.8);s.frame_end=193;s['working_cycle_seconds']=8;s['animation_states']=json.dumps(dict(idle=[0],working=[7,31,55,79,103,127,151,175]))
    m.save(out,'forge-v01.blend')
    (out/'port_manifest.json').write_text(json.dumps(dict(machine='pelletization-forge',footprint=[3,3],ports=[],item_interfaces=[
        dict(id='raw_pellet_feed',kind='solid item',model_access_edge=[0,1.5,1.2],opening_center=[0,.80,1.60],native_pickup_verified=False),
        dict(id='finished_pellet_pickup',kind='solid item',model_access_edge=[0,-1.5,.20],tray_center=[0,-1.08,.18],native_pickup_verified=False)],native_fluidbox_count=0,native_target=None),indent=2)+'\n')
    (out/'construction-receipt.json').write_text(json.dumps(dict(status='construction pilot; independent mechanics, finishing and native work pending',source_sha256=sha(out/'forge-v01.blend'),
        provenance='new_reconstruction_from_reference; historical v0.2 native bytes unrecovered',contacts=contacts,press=dict(center=[0,-.10],crosshead_idle_z=1.32,stroke=.34,punch_radius=.050,die_minimum_radius=.055,guide_radius=.0345,guide_hole_radius=.036),
        pending=['Independent ram/guide/actuator contacts and full swept collision audit','Verify hopper-auger-die-tray material path and pellet support','Machine-specific surfaces and working sound','Four idle/working rotations and native item interfaces','Processing must preserve remaining instability, HP and quality; no timer refresh']),indent=2)+'\n')
    print('FORGE_V01_NATIVE_SAVED',sha(out/'forge-v01.blend'),flush=True)


if __name__=='__main__':main()
