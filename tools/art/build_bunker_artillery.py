"""Author a candidate revolving-breech siege gun on the shared turret socket.

Blender --background --python THIS -- PACKED_FAMILY_STUDIO CANDIDATE_OUT
Moving cap only. Source demonstration is distinct from native gameplay.
"""
from pathlib import Path
import sys

kit=Path(__file__).with_name('build_bullet_turrets.py').read_text()
kit=kit[:kit.index('    # Standard interface, supported yoke')]
kit=kit.replace("for variant in ('chicago-piano','twin-minigun'):","for variant in ('rolling-artillery',):")
kit=kit.replace('O=output/variant','O=output')
kit=kit.replace("source, output=map(Path,sys.argv[sys.argv.index('--')+1:])", "source, output=(Path(p).resolve() for p in sys.argv[sys.argv.index('--')+1:])")
exec(compile(kit,'shared_turret_studio','exec'),globals())

S.cycles.samples=24;S.camera.data.ortho_scale=11.0
S.camera.rotation_euler=(Vector((0,-.2,3.4))-S.camera.location).to_track_quat('-Z','Y').to_euler()
S.render.resolution_x=S.render.resolution_y=896
S.render.fps=60;S.frame_start=1;S.frame_end=601

def pin(name,a,b,r=.025,parent=None):
    return cylinder(name,a,b,r,'steel',parent,6)

# All geometry above the fixed bunker interface; no foundation follows yaw.
cylinder('Traverse bearing socket',(0,0,1.70),(0,0,1.88),1.02,'dark')
tube('Exposed azimuth bearing',(0,0,1.86),(0,0,1.96),1.04,.085,'steel')
for j in range(16):
    a=j*math.tau/16
    pin('Traverse bearing retainer',(math.cos(a)*.99,math.sin(a)*.99,1.86),
        (math.cos(a)*.99,math.sin(a)*.99,1.98),.026)
    pin('Traverse bearing anchor nut',(math.cos(a)*.99,math.sin(a)*.99,1.96),
        (math.cos(a)*.99,math.sin(a)*.99,2.02),.032)
# An actual pedestal transfers the yoke loads into the full bolt circle.
cylinder('Central load-bearing pedestal',(0,0,1.94),(0,0,2.22),.83,'dark')
cylinder('Thick pedestal distribution plate',(0,0,2.20),(0,0,2.36),1.50,'dark')
tube('Machined distribution plate edge',(0,0,2.29),(0,0,2.37),1.51,.055,'steel')
for j in range(8):
    a=j*math.tau/8
    gusset=profile_body('Radial pedestal gusset',0,.13,[(.54,1.96),(.84,1.96),(1.35,2.20),(.70,2.20)],'red')
    gusset.rotation_euler.z=a
for x in (-1.10,1.10):
    box('Bolted full-contact yoke foot',(x,0,2.42),(.38,1.40,.14),'steel',bevel=.016)
    for dx in (-.16,.16):
        for y in (-.52,.52):
            pin('Yoke foot anchor bolt',(x+dx,y,2.22),(x+dx,y,2.52),.020)
            pin('Visible yoke foot anchor nut',(x+dx,y,2.50),(x+dx,y,2.57),.024)
foundation_parts=set(created)
assembly=empty('CENTERED_ARTILLERY_MOUNT',(0,0,0))
for x in (-1.10,1.10):
    cheek=profile_body('Load-bearing fork cheek',x,.19,
        [(1.15,2.48),(2.55,2.48),(2.65,3.25),(2.08,4.74),(1.60,4.74),(1.05,3.60)],'dark')
    armour=profile_body('Inset sloped cheek armour',x+(.112 if x>0 else -.112),.045,
        [(1.20,2.58),(2.43,2.58),(2.45,2.75),(1.98,4.55),(1.65,4.55),(1.15,3.08)],'red')
    # A real clearance aperture through both plates carries the recoil link
    # under the elevated trunnion; painted-on slots would still collide.
    for casting in (cheek,armour):cut_port(casting,(x,2.20,3.70),(.70,.95,.88))
    for y,z in ((1.35,2.75),(2.40,2.75),(1.80,4.38)):
        pin('Cheek armour through-fastener',(x-.15,y,z),(x+.15,y,z),.041)
    cylinder('Elevation trunnion',(x-.16,1.85,4.55),(x+.16,1.85,4.55),.23,'steel')
    tube('Trunnion bearing retaining ring',(x-.18,1.85,4.55),(x+.18,1.85,4.55),.28,.09,'red')
    for j in range(8):
        a=j*math.tau/8
        pin('Trunnion cover bolt',(x-.20,1.85+.23*math.cos(a),4.55+.23*math.sin(a)),
            (x+.20,1.85+.23*math.cos(a),4.55+.23*math.sin(a)),.025)
box('Rear fork transverse tie',(0,2.45,2.62),(2.05,.19,.20),'steel',bevel=.024)

elevation=empty('ELEVATION_CRADLE',(0,1.85,3.40))
carriage=empty('DEEP_RECOIL_CARRIAGE',(0,0,3.40),elevation)
for x in (-1.45,1.45):
    profile_body('Longitudinal recoil-bed casting',x,.15,
        [(-1.12,2.92),(3.70,2.92),(3.70,3.13),(-1.12,3.13)],'dark',elevation)
    cylinder('Polished recoil slide',(x,-1.11,3.25),(x,3.70,3.25),.053,'steel',elevation)
    for y in (-1.03,3.56):
        box('Bearing pedestal on recoil bed',(x,y,3.15),(.25,.18,.21),'red',elevation,.015)
    for y in (.80,2.31):
        tube('Sliding carriage guide bushing',(x,y-.12,3.25),(x,y+.12,3.25),.087,.025,'brass',carriage)
    tube('Hydropneumatic recuperator',(x,-.93,3.55),(x,1.28,3.55),.105,.040,'dark',elevation)
    cylinder('Recuperator return rod',(x,.20,3.55),(x,2.43,3.55),.047,'steel',carriage)
    box('Recuperator clevis lug',(x,2.44,3.43),(.20,.16,.30),'red',carriage,.018)
    pin('Recuperator clevis pin',(x-.14,2.44,3.55),(x+.14,2.44,3.55),.056,carriage)
    side=1 if x>0 else -1
    for name,y in (('Forward cradle load strut',-1.03),('Rear cradle load strut',3.56)):
        cylinder(name,(side*1.10,1.85,3.40),(side*1.10,y,3.04),.075,'dark',elevation)
        cylinder(name+' bed connection',(side*1.10,y,3.04),(x,y,3.04),.075,'dark',elevation)

# Bored single gun tube, stepped forged breech and a vented muzzle brake.
tube('Hollow siege barrel',(0,-3.37,3.40),(0,.84,3.40),.215,.065,'steel',carriage)
tube('Forged barrel jacket',(0,-1.40,3.40),(0,.69,3.40),.335,.10,'dark',carriage)
for y in (-1.41,-.94,.55):
    tube('Jacket retaining collar',(0,y-.06,3.40),(0,y+.06,3.40),.365,.085,'steel',carriage)
for side in (-1,1):
    profile_body('Curved breech shoulder armour',side*.31,.12,
        [(-.86,3.30),(.91,3.30),(1.03,3.50),(.62,3.79),(-.54,3.75),(-.93,3.56)],'red',carriage)
    for y in (-.65,.56):
        pin('Shoulder armour fastener',(side*.35,y,3.58),(side*.40,y,3.58),.035,carriage)
tube('Bored muzzle-brake rear band',(0,-3.35,3.40),(0,-3.18,3.40),.295,.145,'dark',carriage)
tube('Bored muzzle-brake front band',(0,-3.91,3.40),(0,-3.80,3.40),.295,.145,'steel',carriage)
# Four real open exhaust windows, rather than a solid perforation texture.
for j in range(4):
    a=j*math.pi/2+.17
    arc_shell('Muzzle brake bridge',0,-3.80,-3.35,3.40,.295,.055,a,a+.42,'dark',carriage)
muzzle=empty('MUZZLE_ARTILLERY',(0,-3.93,3.40),carriage)
bore=empty('BREECH_BORE',(0,.84,3.40),carriage)

# A radial cylinder indexes three pressure chambers into the single bore.
# Its centre is lower than the bore; the upper chamber aligns exactly.
drum=empty('THREE_CHAMBER_BREECH',(0,1.50,2.80),carriage)
rounds=[]
for cell in range(3):
    a=math.pi/2+cell*math.tau/3;x=.60*math.cos(a);z=2.80+.60*math.sin(a)
    tube('Pressure chamber %d'%cell,(x,.86,z),(x,2.17,z),.209,.055,'dark',drum)
    for y in (.87,2.10):
        tube('Chamber locking ring %d'%cell,(x,y-.045,z),(x,y+.045,z),.230,.065,'steel',drum)
    shell=empty('LOADED_ARTILLERY_SHELL_%d'%cell,(x,1.55,z),drum);rounds.append(shell)
    cylinder('Brass case %d'%cell,(x,1.25,z),(x,2.12,z),.137,'brass',shell)
    tube('Case extraction rim %d'%cell,(x,2.08,z),(x,2.15,z),.151,.030,'steel',shell)
    bpy.ops.mesh.primitive_cone_add(vertices=24,radius1=.137,radius2=.018,depth=.30,location=(x,1.10,z))
    ob=bpy.context.object;ob.rotation_euler.x=math.pi/2;finish(ob,'Protected shell ogive %d'%cell,'red',shell)
    for y in (1.00,2.04):
        cylinder('Drum radial load web %d'%cell,(0,y,2.80),(x,y,z),.072,'steel',drum)
cylinder('Revolving breech central axle',(0,.78,2.80),(0,2.37,2.80),.135,'steel',carriage)
support_rings=[]
for y in (.80,2.31):
    support_rings.append(tube('Revolver outer support ring',(0,y-.045,2.80),(0,y+.045,2.80),.94,.06,'dark',carriage))
    for side in (-1,1):
        cylinder('Ring to recoil-bed structural strut',(side*.90,y,2.85),(side*1.32,y,2.85),.045,'dark',carriage)
        cylinder('Ring to recoil-bed structural strut upright',(side*1.32,y,2.85),(side*1.32,y,3.25),.045,'dark',carriage)
        cylinder('Ring to recoil-bed structural strut upper lug',(side*1.32,y,3.25),(side*1.37,y,3.32),.045,'dark',carriage)
# Protective crown and mesh inspection guards clear the entire drum sweep.
arc_shell('Curved rear breech crown',0,.85,2.27,2.80,.99,.055,.12,math.pi-.12,'red',carriage)
guard_wires=[]
for j in range(12):
    a=math.pi+j*math.pi/11
    x=.97*math.cos(a);z=2.80+.97*math.sin(a)
    guard_wires.append(cylinder('Lower inspection guard longitudinal wire',(x,.85,z),(x,2.28,z),.009,'steel',carriage))
for y in (1.00,1.23,1.46,1.69,1.92,2.15):
    arc_shell('Inspection guard curved cross wire',0,y-.005,y+.005,2.80,.97,.010,math.pi,math.tau,'steel',carriage)
guard_bands=[]
for bank,(y0,y1,y) in enumerate(((.81,.86,.83),(2.26,2.31,2.29))):
    band=arc_shell('Guard mounting band %d'%bank,0,y0,y1,2.80,.98,.05,math.pi,math.tau,'steel',carriage)
    band['attachment_targets']=json.dumps([support_rings[bank].name]);guard_bands.append(band)
    for j in range(5):
        a=math.pi+j*math.pi/4
        clamp=pin('Guard clamp fastener %d_%d'%(bank,j),(.925*math.cos(a),y,2.80+.925*math.sin(a)),
                  (1.00*math.cos(a),y,2.80+1.00*math.sin(a)),.018,carriage)
        clamp['attachment_targets']=json.dumps([band.name,support_rings[bank].name])
for wire in guard_wires:wire['attachment_targets']=json.dumps([o.name for o in guard_bands])
motor=box('Outboard breech-index motor',(.99,1.45,2.62),(.32,.63,.39),'dark',carriage,.055)
coupling=cylinder('Indexer reduction coupling',(.73,1.45,2.80),(1.10,1.45,2.80),.13,'brass',carriage)
line=conduit('Indexer lubrication return',[(1.14,1.63,2.64),(1.18,2.10,2.65),(1.10,1.50,2.80)],.023,'dark',carriage)
line['attachment_targets']=json.dumps([motor.name,coupling.name])

# Hinged rear service gate: opens outward, behind the maximum recoil extent.
gate=empty('REAR_RELOAD_GATE',(0,2.39,1.85),carriage)
gate_ring=arc_shell('Rear reload gate ring',0,2.37,2.46,2.80,.93,.10,0,math.tau,'red',gate)
def hinge_bore(body,x,radius):
    bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=radius,depth=.55,location=(x,2.39,1.85),rotation=(0,math.pi/2,0))
    cutter=bpy.context.object;mod=body.modifiers.new('Actual hinge-pin clearance bore','BOOLEAN');mod.object=cutter;mod.operation='DIFFERENCE'
    bpy.context.view_layer.objects.active=body;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
for x in (-.56,.56):
    cylinder('Reload gate cross brace',(x,2.43,2.20),(-x,2.43,3.40),.035,'steel',gate)
    knuckle=tube('Gate lower hinge knuckle',(x-.08,2.39,1.85),(x+.08,2.39,1.85),.075,.025,'steel',gate)
    lug=profile_body('Gate hinge structural lug',x,.10,[(2.39,1.85),(2.47,1.85),(2.49,2.13),(2.40,2.13)],'steel',gate)
    hinge_bore(lug,x,.050);lug['attachment_targets']=json.dumps([gate_ring.name,knuckle.name])
    knuckle['attachment_targets']=json.dumps([lug.name])
    for side in (-1,1):
        px=x+side*.12;az=2.80-math.sqrt(.91**2-px**2)
        clevis=profile_body('Fixed gate hinge clevis',px,.04,
            [(2.28,az-.05),(2.28,az+.05),(2.34,az+.05),(2.34,1.94),(2.44,1.90),(2.44,1.80),(2.28,1.80)],'steel',carriage)
        hinge_bore(clevis,px,.037);clevis['attachment_targets']=json.dumps([support_rings[1].name])
        start,end=(x-.18,x-.135) if side<0 else (x+.135,x+.18)
        head=pin('Captive gate hinge pin retainer',(start,2.39,1.85),(end,2.39,1.85),.050,carriage)
        head['attachment_targets']=json.dumps([clevis.name])
    pin('Gate hinge pin',(x-.16,2.39,1.85),(x+.16,2.39,1.85),.031,carriage)

# Optics remain on the static fork with a clear forward sight line.
box('Rangefinder mounting foot',(1.70,1.0,3.27),(.24,.28,.26),'dark',bevel=.025)
cylinder('Rangefinder cantilever on fork',(1.10,1.40,3.20),(1.70,1.0,3.27),.075,'steel')
profile_body('Armoured rangefinder',1.79,.28,[(.66,3.40),(1.28,3.40),(1.37,3.64),(.78,3.70),(.62,3.58)],'red')
for x in (1.73,1.85):
    cylinder('Forward optical glass',(x,.615,3.56),(x,.59,3.56),.041,'lens')
conduit('Optic shielded data line',[(1.79,1.32,3.49),(1.76,1.75,3.30),(1.14,1.65,2.80)],.021)
for x,h in ((-1.34,.86),(1.34,.57)):
    cylinder('Aerial socket support from fork',(math.copysign(1.10,x),1.40,2.80),(x,1.40,2.80),.065,'dark')
    cylinder('Telemetry aerial base',(x,1.40,2.75),(x,1.40,2.88),.078,'dark')
    cylinder('Telemetry whip',(x,1.40,2.88),(x,1.40,2.88+h),.015,'dark')

for obj in list(S.objects):
    if obj.parent==root and obj not in foundation_parts and obj!=assembly:parent_world(obj,assembly)
assembly.location.y-=1.85
elevation.location.z+=1.15
rest=carriage.location.copy()
for tick in range(601):
    S.frame_set(tick+1)
    down=max(0,min(1,(tick-250)/50));up=max(0,min(1,(tick-550)/50))
    angle=35*(1-down*down*(3-2*down)+up*up*(3-2*up))
    elevation.rotation_euler.x=-math.radians(angle);elevation.keyframe_insert('rotation_euler')
    shots=[t for t in (0,90,180) if t<=tick];age=tick-shots[-1] if shots else 1000
    if age<3:kick=.76*(.5-.5*math.cos(math.pi*age/3))
    elif age<7:kick=.76
    elif age<62:
        u=(age-7)/55;kick=.76*(1-u*u*(3-2*u))
    else:kick=0
    carriage.location=rest+Vector((0,kick,0));carriage.keyframe_insert('location')
    # Index only after the heavy recoiling group has returned to battery.
    indexes=0
    for shot in (0,90):
        u=max(0,min(1,(tick-shot-64)/18));indexes+=u*u*(3-2*u)
    if tick>=360:
        u=max(0,min(1,(tick-360)/80));indexes+=u*u*(3-2*u)
    drum.rotation_euler.y=indexes*math.tau/3;drum.keyframe_insert('rotation_euler')
    for cell,shell in enumerate(rounds):
        loaded=tick<=cell*90 or tick>=500
        shell.scale=(1,1,1) if loaded else (0,0,0);shell.keyframe_insert('scale')
    # Rearward gate swing stays outside both the drum and support ring.
    u=max(0,min(1,(tick-315)/45));v=max(0,min(1,(tick-500)/45))
    gate.rotation_euler.x=-math.radians(82)*(u*u*(3-2*u)-v*v*(3-2*v));gate.keyframe_insert('rotation_euler')
S.frame_set(1)
S['variant']='rolling-artillery';S['base_included']=False;S['mount_socket']=[0,0,1.70]
S['surface_plan']='Oxide red removable cheek and breech crown armour, dark forged load-bearing fork, longitudinal steel bore/recoil rails, brass cases and bushes. Real open muzzle-brake ports and lower mesh inspection guard. Packed family PBR maps, physical-scale per-part UVs.'
S['status']='CANDIDATE_NOT_IN_GAME';S['provisional_shot_ticks']=[0,90,180];S['cycle_ticks']=600
S['firing_elevation_degrees']=35;S['reload_elevation_degrees']=0
S['centered_trunnion_over_plate']=True;S['mount_load_path']='Yoke feet -> full distribution plate -> radial gussets -> central pedestal -> 16-bolt traverse flange'
for obj in created:
    if obj.type=='MESH' and len(obj.data.polygons)==96:
        for polygon in obj.data.polygons:polygon.use_smooth=polygon.index//24 in (0,2)
for im in bpy.data.images:
    if im.source=='FILE' and not im.packed_file:im.pack()
native=O/'rolling-artillery.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for ob in created+[root,assembly,elevation,carriage,drum,gate,muzzle,bore]+rounds:ob.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=str(O/'rolling-artillery.glb'),use_selection=True,export_format='GLB',export_apply=True,export_animations=False)
S.camera.data.ortho_scale=13.5
for view,yaw,frame in [('front',0,1),('rear',math.pi,1),('quarter',math.pi/4,1),('side',math.pi/2,1),('reload',math.pi,420)]:
    S.frame_set(frame);root.rotation_euler.z=yaw
    S.render.filepath=str(O/(view+'.png'));bpy.ops.render.render(write_still=True)
contract={'status':'MODEL_CANDIDATE_REVIEW_PENDING','base_included':False,'socket':[0,0,1.70],
 'mechanism':'Single siege barrel with three-chamber revolving breech and entire breech/barrel recoil carriage',
 'owner_agreed':'Three-shell rolling barrage, then long reload','provisional_shot_ticks':[0,90,180],
 'cycle_ticks':600,'last_shot_to_next':420,'vanilla_artillery_cooldown':200,
 'balance_plan':'Native shell damage, range and one shell consumed per shot; same 3 shells / 600 ticks sustained output as vanilla. Research scales the full cycle.',
 'firing_elevation_degrees':35,'reload_elevation_degrees':0,'mechanical_direction_owner_accepted':True,
 'mount_load_path':S['mount_load_path'],'centered_trunnion_over_plate':True,
 'runtime_implemented':False,'visual_approval':False,'collision_acceptance':False,
 'native_sha256':hashlib.sha256(native.read_bytes()).hexdigest()}
(O/'contract.json').write_text(json.dumps(contract,indent=2)+'\n')
print('ARTILLERY_CANDIDATE_READY',str(O),flush=True)
