"""Author a six-cell rocket salvo candidate; no fixed bunker in moving geometry.

Blender --background --python THIS -- PACKED_FAMILY_STUDIO OUTPUT_ROOT
Source animation is a design demonstration, not a claim of native integration.
"""
from pathlib import Path
import sys
kit=Path(__file__).with_name('build_bullet_turrets.py').read_text()
kit=kit[:kit.index('    # Standard interface, supported yoke')]
kit=kit.replace("for variant in ('chicago-piano','twin-minigun'):","for variant in ('rocket-salvo',):")
exec(compile(kit,'family_studio_and_geometry','exec'),globals())

S.cycles.samples=24
S.render.resolution_x=S.render.resolution_y=768
S.render.resolution_percentage=100
S.camera.data.ortho_scale=5.6

def bolt(name,a,b,r=.026,parent=None):
    return cylinder(name,a,b,r,'steel',parent,6)

def ring_bolts(name,x,y,z,r,parent=None):
    for n in range(8):
        a=n*math.tau/8
        bolt(name,(x+r*math.cos(a),y,z+r*math.sin(a)),
             (x+r*math.cos(a),y-.028,z+r*math.sin(a)),.017,parent)

cylinder('Socket adapter on fixed bunker',(0,0,1.70),(0,0,1.88),.78,'dark')
tube('Exposed traverse bearing',(0,0,1.85),(0,0,1.95),.79,.085,'steel')
for j in range(16):
    a=j*math.tau/16
    bolt('Bearing lock',(math.cos(a)*.71,math.sin(a)*.71,1.94),
         (math.cos(a)*.71,math.sin(a)*.71,1.97),.027)
profile_body('Tapered armoured central keel',0,.72,
             [(-.75,1.94),(.92,1.94),(1.03,2.10),(.60,2.38),(-.53,2.39),(-.85,2.20)],'dark')
for side in (-1,1):
    x=side*.90
    profile_body('Integrated triangulated pod support',side*.52,.15,
                 [(-.42,1.94),(.44,1.94),(.28,2.12),(.11,2.24),(-.14,2.24)],'dark')
    cylinder('Load bearing transverse trunnion',(side*.39,0,2.10),(side*1.34,0,2.10),.10,'steel')
    tube('Red elevation bearing flange',(side*1.25,0,2.10),(side*1.36,0,2.10),.16,.055,'red')
    # Real diagonal elevation link terminates on the pod attachment clevis.
    cylinder('Elevation screw housing',(side*.54,.51,2.02),(side*.70,.508,2.06),.08,'dark')
    cylinder('Elevation polished actuator',(side*.70,.508,2.06),(side*.82,.5063,2.0920),.041,'steel')
    cylinder('Elevation clevis pin',(side*.77,.5063,2.0920),(side*.88,.5063,2.0920),.060,'brass')

pods=[];doors=[];loaders=[];rounds=[];muzzles=[]
for bank,x in enumerate((-.90,.90)):
    pivot=empty('ELEVATING_LAUNCH_POD_'+str(bank),(x,0,2.10));pods.append(pivot)
    offsets=[(-.245,0),(.245,0),(0,.455)]
    box('Trunnion to pod structural saddle',(x,0,2.16),(.80,.18,.10),'dark',pivot,.008)
    # Each cell is an actual open tube, with separately supported retaining bands.
    for cell,(dx,dz) in enumerate(offsets):
        cx=x+dx;cz=2.43+dz
        tube('Bored launch cell %d_%d'%(bank,cell),(cx,-1.18,cz),(cx,.74,cz),.224,.027,'dark',pivot)
        tube('Red cell muzzle collar',(cx,-1.20,cz),(cx,-1.03,cz),.250,.060,'red',pivot)
        tube('Machined muzzle liner',(cx,-1.215,cz),(cx,-1.15,cz),.199,.012,'steel',pivot)
        for y in (-.70,.34,.68):
            tube('Individual cell structural band',(cx,y-.045,cz),(cx,y+.045,cz),.239,.025,'steel',pivot)
        ring_bolts('Cell rear flange fastener',cx,.69,cz,.205,pivot)
        missile=empty('LOADED_ROCKET_%d_%d'%(bank,cell),(cx,-.50,cz),pivot);rounds.append(missile)
        cylinder('Visible rocket body',(cx,-1.03,cz),(cx,-.27,cz),.125,'steel',missile)
        bpy.ops.mesh.primitive_cone_add(vertices=24,radius1=.125,radius2=.008,depth=.24,location=(cx,-1.15,cz))
        nose=bpy.context.object;nose.rotation_euler.x=math.pi/2;finish(nose,'Protected rocket nose','brass',missile)
        tube('Rocket identification collar',(cx,-.83,cz),(cx,-.76,cz),.130,.012,'red',missile)
        socket=empty('MUZZLE_%d_%d'%(bank,cell),(cx,-1.235,cz),pivot);muzzles.append(socket)
    # Connected triangular end frames carry all three cells, with a central void.
    for y in (-.53,.50):
        for a,b in ((offsets[0],offsets[1]),(offsets[1],offsets[2]),(offsets[2],offsets[0])):
            cylinder('Pod cross brace',(x+a[0],y,2.43+a[1]),(x+b[0],y,2.43+b[1]),.065,'dark',pivot)
        box('Pod lower cradle foot',(x,y,2.18),(.87,.16,.10),'red',pivot,.018)
    # Upper half shields leave the separate cells and external skeleton legible.
    arc_shell('Upper curved pod armour',x,-.88,.49,2.885,.270,.035,0,math.pi,'red',pivot)
    for sign in (-1,1):
        profile_body('Swept removable pod cheek',x+sign*.48,.045,
            [(-.89,2.28),(.53,2.28),(.66,2.55),(.26,2.71),(-.63,2.61)],'red',pivot)
        for y in (-.65,.23,.49):bolt('Pod cheek captive bolt',(x+sign*.51,y,2.43),(x+sign*.54,y,2.43),.025,pivot)
    # A three-round cassette and guide rails follow the same elevation axis.
    for dx in (-.38,.38):
        cylinder('Reload guide rail',(x+dx,.61,2.27),(x+dx,2.49,2.27),.033,'steel',pivot)
        box('Rail terminal lug',(x+dx,2.48,2.27),(.105,.12,.13),'dark',pivot)
    loader=empty('SLIDING_THREE_ROUND_CASSETTE_'+str(bank),(x,1.05,2.43),pivot);loaders.append(loader)
    for dx,dz in offsets:
        cylinder('Cassette cartridge sleeve',(x+dx,.93,2.43+dz),(x+dx,1.34,2.43+dz),.184,'dark',loader)
        tube('Brass cartridge base retaining ring',(x+dx,1.31,2.43+dz),(x+dx,1.37,2.43+dz),.194,.035,'brass',loader)
        cylinder('Cartridge base',(x+dx,1.34,2.43+dz),(x+dx,1.375,2.43+dz),.155,'steel',loader)
    for a,b in ((offsets[0],offsets[1]),(offsets[1],offsets[2]),(offsets[2],offsets[0])):
        cylinder('Cassette connected rear frame',(x+a[0],1.40,2.43+a[1]),(x+b[0],1.40,2.43+b[1]),.047,'red',loader)
    # The drive is outboard of the shutter; no shaft passes through the panel.
    outboard=x+(-.46 if bank==0 else .46)
    cylinder('Outboard cassette loading ram',(outboard,.69,2.58),(outboard,1.31,2.58),.043,'steel',loader)
    cylinder('Cassette drive attachment',(outboard,1.35,2.58),(x+(-.245 if bank==0 else .245),1.35,2.43),.040,'dark',loader)
    for dx in (-.38,.38):
        tube('Cassette linear bearing',(x+dx,1.17,2.27),(x+dx,1.33,2.27),.055,.020,'dark',loader)
        cylinder('Cassette bearing support',(x+dx,1.24,2.30),(x+(-.245 if dx<0 else .245),1.24,2.36),.031,'steel',loader)
    # Articulated blast shutter mounted to a real transverse hinge.
    door=empty('HINGED_RELOAD_SHUTTER_'+str(bank),(x,.78,3.14),pivot);doors.append(door)
    cylinder('Breech shutter hinge',(x-.39,.78,3.14),(x+.39,.78,3.14),.047,'steel',pivot)
    # Narrow service panel clears both guide rails. Hinge arms remain inside
    # the rail inner faces; the two actual pivot pins are intended contacts.
    panel=armor('Faceted breech blast shutter',x,.80,2.27,.64,.065,.79,door)
    for dx in (-.29,.29):
        box('Shutter hinge arm',(x+dx,.80,3.06),(.08,.10,.22),'dark',door)
        bolt('Breech shutter latch',(x+dx,.76,2.42),(x+dx,.87,2.42),.032,door)
    pivot.rotation_euler.x=-math.radians(10)

# Rangefinder and command equipment are attached to the keel, below the tubes.
box('Forward optical support',(0,-.55,2.36),(.36,.26,.13),'dark')
sensor=armor('Sloped stereo tracking head',0,-.69,2.38,.43,.32,.19)
for x in (-.12,.12):
    tube('Optical armoured bezel',(x,-.85,2.48),(x,-.90,2.48),.061,.016,'steel')
    cylinder('Recessed optical lens',(x,-.86,2.48),(x,-.88,2.48),.043,'lens')
box('Rear service cover',(0,.79,2.32),(.40,.39,.12),'red',bevel=.018)
for y in (.68,.76,.84,.92):box('Controller cooling louvre',(0,y,2.39),(.29,.025,.022),'dark',bevel=.003)
cylinder('Protected radio socket',(0,.54,2.40),(0,.54,2.50),.063,'dark')
cylinder('Short communications whip',(0,.54,2.49),(0,.54,3.23),.013,'steel')
for side in (-1,1):
    conduit('Clipped pod electrical harness',[(side*.22,.42,2.20),(side*.44,.44,2.26),(side*.59,.20,2.43)],.025,'dark')
    tube('Harness retaining clamp',(side*.43,.43,2.24),(side*.43,.46,2.24),.037,.010,'steel')

# Provisional source study: six staggered departures, then a visible cassette
# withdrawal/return and shutter cycle. Runtime must later be driven by real shots.
S.render.fps=60;S.frame_start=1;S.frame_end=241
shot_ticks=[0,10,20,30,40,50]
# Alternate left/right and progress through the three cells of each pod.
order=[0,3,1,4,2,5]
for tick,index in zip(shot_ticks,order):
    ob=rounds[index]
    for frame,scale in ((1,1),(tick+1,1),(tick+2,0),(179,0),(180,1),(241,1)):
        ob.scale=(scale,scale,scale);ob.keyframe_insert('scale',frame=frame)
for door in doors:
    for frame,angle in ((1,0),(82,0),(106,105),(174,105),(211,0),(241,0)):
        door.rotation_euler.x=math.radians(angle);door.keyframe_insert('rotation_euler',frame=frame)
for loader in loaders:
    rest=loader.location.copy()
    # Retract before opening; feed only under the fully raised shutter;
    # retract again before closure, then park behind the closed panel.
    for frame,dy,dz in ((1,0,0),(52,0,0),(82,.95,0),(114,.95,0),
                         (140,0,0),(150,0,0),(174,.95,0),(213,.95,0),(237,0,0),(241,0,0)):
        loader.location=rest+Vector((0,dy,dz));loader.keyframe_insert('location',frame=frame)
S.frame_set(1)
S['variant']='rocket-salvo';S['base_included']=False;S['mount_socket']=[0,0,1.70]
S['surface_plan']='Oxide-red removable curved shields; dark individual launch canisters and cast yoke; machined steel rings/rails; brass rocket nose and cassette retainers; recessed optical glass. Surfaces use physically scaled local UVs.'
S['status']='CANDIDATE_NOT_IN_GAME';S['provisional_shot_ticks']=shot_ticks
for im in bpy.data.images:
    if im.source=='FILE' and not im.packed_file:im.pack()
native=O/'rocket-salvo.blend';bpy.ops.wm.save_as_mainfile(filepath=str(native),compress=True)
bpy.ops.object.select_all(action='DESELECT')
for ob in created:ob.select_set(True)
for ob in [root]+pods+doors+loaders+rounds+muzzles:ob.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=str(O/'rocket-salvo.glb'),use_selection=True,export_format='GLB',export_apply=True,export_animations=False)
for view,yaw in [('front',0),('rear',math.pi),('quarter',math.pi/4),('side',math.pi/2)]:
    root.rotation_euler.z=yaw;S.render.filepath=str(O/(view+'.png'));bpy.ops.render.render(write_still=True)
root.rotation_euler.z=math.pi/4;S.frame_set(116)
S.render.filepath=str(O/'reload-study.png');bpy.ops.render.render(write_still=True)
(O/'contract.json').write_text(json.dumps({'status':'MODEL_CANDIDATE_REVIEW_PENDING','base_included':False,
    'socket':[0,0,1.70],'cells':6,'pod_layout':'Two triangular three-cell packs with trunnions',
    'owner_agreed':'Staggered rocket salvo, then visible reload','provisional_shot_ticks':shot_ticks,
    'provisional_recycle_ticks':190,'native_ammo_plan':['rocket','explosive-rocket'],
    'runtime_implemented':False,'visual_approval':False,
    'native_sha256':hashlib.sha256(native.read_bytes()).hexdigest()},indent=2)+'\n')
print('ROCKET_CANDIDATE_READY',str(O),flush=True)
