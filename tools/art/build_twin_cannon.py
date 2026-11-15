"""Author the heavy twin cannon, using the reviewed family studio and tools.

Blender --python THIS -- CAMERA_MATERIAL_SOURCE OUTPUT_ROOT
The bunker foundation is deliberately absent from this animated cap.
"""
from pathlib import Path
import sys
# Reuse the established geometric constructors and packed studio materials.
# Execute only the initialization/helpers, never the earlier weapon geometry.
kit=(Path(__file__).with_name('build_bullet_turrets.py')).read_text()
kit=kit[:kit.index('    # Standard interface, supported yoke')]
kit=kit.replace("for variant in ('chicago-piano','twin-minigun'):","for variant in ('twin-cannon',):")
exec(compile(kit,'reviewed_turret_constructors','exec'),globals())

def cylinder(name,a,b,r,mat='steel',parent=None,vertices=24):
    a,b=Vector(a),Vector(b);delta=b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=delta.length,location=(a+b)/2)
    obj=bpy.context.object;obj.rotation_euler=delta.to_track_quat('Z','Y').to_euler()
    finish(obj,name,mat,parent,min(.004,delta.length*.2))
    layer=obj.data.uv_layers.active
    for polygon in obj.data.polygons:
        if len(polygon.vertices)!=4:continue
        angles=[math.atan2(obj.data.vertices[obj.data.loops[li].vertex_index].co.y,
                           obj.data.vertices[obj.data.loops[li].vertex_index].co.x)/math.tau for li in polygon.loop_indices]
        seam=max(angles)-min(angles)>.5
        for li,angle in zip(polygon.loop_indices,angles):
            if seam and angle<0:angle+=1
            layer.data[li].uv=(angle*math.tau*r*2,obj.data.vertices[obj.data.loops[li].vertex_index].co.z*2)
    return obj

# The adapter contacts the existing bunker socket; a broad casting carries
# both independently trunnioned guns and the rear ammunition machinery.
cylinder('Heavy socket adapter',(0,0,1.70),(0,0,1.88),.83,'dark')
tube('Traverse bearing keeper',(0,0,1.84),(0,0,1.96),.87,.10,'steel')
hull=profile_body('Unified stepped armoured turret casting',0,2.22,
    [(-.77,1.96),(.94,1.96),(1.12,2.18),(.93,2.56),(.32,2.72),(-.48,2.67),(-.84,2.39)],'dark')
for side in (-1,1):
    profile_body('Sloped red side armour',side*1.105,.09,
        [(-.72,2.09),(.78,2.09),(.98,2.24),(.79,2.51),(.20,2.64),(-.43,2.59)],'red')
    for y in (-.56,.08,.70):
        cylinder('Armour retention bolt',(side*1.15,y,2.30),(side*1.18,y,2.30),.045,'steel',vertices=6)
    box('Recessed side service hatch',(side*1.16,.56,2.34),(.025,.35,.22),'dark',bevel=.004)
    for z in (2.29,2.35,2.41):box('Service hatch cooling louvre',(side*1.18,.56,z),(.015,.25,.022),'steel',bevel=.003)

sys.path.insert(0,str(Path(__file__).resolve().parent))
from twin_cannon_mantlet_mount import integrate_mantlet
from twin_cannon_hatch_stays import build_hatch_stays
gun_roots=[];gun_flashes=[];rams=[];mantlets=[]
for bank,x in enumerate((-.58,.58)):
    # Separate mantlet shells visibly seat in a shared front face.
    mantle=empty('INDEPENDENT_MANTLET_'+str(bank),(x,-.63,2.61))
    mantlets.append(mantle)
    cylinder('Recessed moving mantlet seat',(x,-.25,2.61),(x,-.84,2.61),.40,'dark',mantle)
    tube('Mantlet armoured lip',(x,-.82,2.61),(x,-.91,2.61),.42,.10,'red',mantle)
    tube('Mantlet bronze bearing',(x,-.90,2.61),(x,-.96,2.61),.29,.055,'brass',mantle)
    for j in range(8):
        a=j*math.tau/8;dx=.35*math.cos(a);dz=.35*math.sin(a)
        cylinder('Mantlet locking bolt',(x+dx,-.92,2.61+dz),(x+dx,-.95,2.61+dz),.025,'steel',mantle,6)
    gun=empty('INDEPENDENT_RECOIL_'+str(bank),(x,-.70,2.61),mantle);gun_roots.append(gun)
    tube('Heavy hollow gun tube',(x,-.78,2.61),(x,-2.52,2.61),.135,.047,'steel',gun)
    tube('Cast recoil sleeve',(x,-.86,2.61),(x,-1.40,2.61),.205,.055,'dark',gun)
    for y in (-1.01,-1.29):tube('Barrel sleeve keeper',(x,y-.04,2.61),(x,y+.04,2.61),.22,.035,'steel',gun)
    tube('Thick muzzle collar',(x,-2.35,2.61),(x,-2.55,2.61),.17,.080,'dark',gun)
    for dx in (-.26,.26):
        cylinder('Independent recoil recuperator',(x+dx,.03,2.53),(x+dx,-1.16,2.53),.065,'dark',mantle)
        cylinder('Recuperator piston',(x+dx,-1.10,2.53),(x+dx,-1.40,2.53),.029,'steel',gun)
    cover=profile_body('Individual armoured breech cover',x,.75,
        [(-.52,2.64),(.61,2.64),(.72,2.81),(.40,2.98),(-.31,2.93)],'red')
    hull=integrate_mantlet(globals(),hull,cover,x,bank)
    slope=-math.atan(.07/.31)
    gasket=box('Conforming breech hatch gasket',(x,.22,3.025),(.43,.26,.015),'dark',bevel=.003);gasket.rotation_euler.x=slope
    hatch=box('Seated breech inspection cover',(x,.22,3.041),(.40,.24,.025),'dark',bevel=.005);hatch.rotation_euler.x=slope
    rotation=Matrix.Rotation(slope,3,'X');normal=rotation@Vector((0,0,1))
    for dx in (-.15,.15):
        for dy in (-.075,.075):
            p=Vector((x,.22,3.041))+rotation@Vector((dx,dy,.014))
            cylinder('Breech hatch retaining bolt',p,p+normal*.022,.016,'steel',vertices=6)
    build_hatch_stays(globals(),hatch,x)
    ram=empty('LOADING_RAM_'+str(bank),(x,.86,2.79));rams.append(ram)
    cylinder('Rear loading piston',(x,.67,2.79),(x,1.20,2.79),.060,'steel',ram)
    box('Ram drive casting',(x,1.26,2.79),(.26,.22,.25),'dark',bevel=.04)

# Mesh-covered flexible side feeds follow the owner's drawn reference.
sys.path.insert(0,str(Path(__file__).resolve().parent))
from twin_cannon_mesh_feed import build_mesh_feeds
from twin_cannon_awareness import build_awareness
belt_rounds,update_feed,feed_review=build_mesh_feeds(globals())
build_awareness(globals())

from twin_cannon_motion import author_motion
author_motion(globals())
from twin_cannon_aerial_motion import author_aerial_motion
from twin_cannon_motion import SHOTS
author_aerial_motion(globals(),SHOTS)
for o in fx:o.hide_render=True
S['variant']='twin-cannon';S['mount_socket']=[0,0,1.70];S['base_included']=False
S['cycle_ticks']=90;S['shot_ticks']=[0,45];S['shell_belt_indexed']=True
S['optics_fitted_to_integrated_armour']=True
S['mesh_covered_side_feeds']=True;S['communications_aerials']=3
S['integrated_mantlet_casting']=True;S['mantlet_socket_radius']=.422
S['surface_plan']='Oxide-red removable armour and reinforced chute corners; dark cast body and enclosed loaders; woven galvanised wire enclosure on all four chute faces; brass cartridges visible inside; protected optical, thermal, radar and feed-observer sensors; three connected aerials.'
for im in bpy.data.images:
    if im.source=='FILE' and not im.packed_file:im.pack()
native=O/'twin-cannon.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for o in created:
    if o not in fx:o.select_set(True)
root.select_set(True);bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=str(O/'twin-cannon.glb'),use_selection=True,export_format='GLB',export_apply=True,export_animations=False)
for view,yaw in [('front',0),('rear',math.pi),('quarter',math.pi/4),('side',math.pi/2)]:
    root.rotation_euler.z=yaw;S.render.filepath=str(O/(view+'.png'));bpy.ops.render.render(write_still=True)
# A genuine alternate-angle close-up for the owner's feed-path review.
root.rotation_euler.z=0
for obj in created:obj.hide_render=obj not in feed_review or obj in fx
target=Vector((-1.10,1.10,2.42));S.camera.location=target+Vector((-6.5,2.2,3.0))
S.camera.rotation_euler=(target-S.camera.location).to_track_quat('-Z','Y').to_euler()
S.camera.data.ortho_scale=2.85;S.render.filepath=str(O/'feed-detail.png');bpy.ops.render.render(write_still=True)
for obj in created:obj.hide_render=obj in fx
target=Vector((-.58,.44,3.06));S.camera.location=target+Vector((-2.5,3,3.5))
S.camera.rotation_euler=(target-S.camera.location).to_track_quat('-Z','Y').to_euler()
S.camera.data.ortho_scale=1.35;S.render.filepath=str(O/'stay-detail.png');bpy.ops.render.render(write_still=True)
(O/'contract.json').write_text(json.dumps({'status':'MODEL_REVIEW_PENDING','base_included':False,'mount':[0,0,1.70],
    'cycle_ticks':90,'shot_ticks':[0,45],'review_timeline_ticks':480,'steady_cycle_source_range':[90,179],
    'aerial_motion':'Flexible radio whips: recoil impulses and traverse inertia; rigid telemetry blade',
    'recoil_stroke':.90,'return_to_battery_tick':80,'muzzle_effect':'native explosion-gunshot at active barrel',
    'cadence_status':'provisional 45-tick spacing; steady alternation owner-confirmed',
    'native_sha256':hashlib.sha256(native.read_bytes()).hexdigest(),'gameplay_status':'not yet registered',
    'feed_reference':'Owner sketch: mesh-covered flexible belt rises at an angle, levels, enters rear side of enclosed loader',
    'mesh_enclosure_faces':4,'radio_aerials':3,'sensor_types':['optical','thermal','rangefinder','flank tracking','search radar','rear feed observer'],
    'remaining_family':['artillery turret design','missile turret design']},indent=2)+'\n')
print('TWIN_CANNON_MODEL_READY',str(O),flush=True)
