"""Fortified Martian Heavy-Weapon Bunker: source-independent mechanical blockout.

Builds an editable, named-component GLB suitable for importing into Blender.
Uses no Wube or other third-party mesh geometry. Dimensions are in Factorio
(tile) units; this is NOT game-approved art or proof of final visual fidelity.

Run: python build_blockout.py
Requirements: numpy, trimesh
"""
from pathlib import Path
import json
import gzip
import math
import numpy as np
import trimesh

OUT = Path(__file__).resolve().parent
SCENE = trimesh.Scene()
PARTS = []

COL = {
    'ferrocrete': '#706e65', 'ferrocrete_light': '#89877e',
    'ferrocrete_dark': '#50514b', 'martian_red': '#842921',
    'red_highlight': '#a83a2b', 'red_dark': '#541d1b',
    'iron': '#363938', 'machine_steel': '#666b68',
    'dark_recess': '#222626', 'brass': '#a38a58',
    'glass': '#244949', 'alert': '#db973e', 'parchment': '#c3aa79',
    'grease': '#252522',
}

def rgba(hexv):
    h=hexv.lstrip('#')
    return [int(h[i:i+2],16) for i in (0,2,4)] + [255]

def add(name, mesh, material, system, purpose):
    mesh.visual.vertex_colors = np.tile(rgba(COL[material]), (len(mesh.vertices),1))
    SCENE.add_geometry(mesh, geom_name=name, node_name=name)
    PARTS.append(dict(name=name, material=material, system=system, purpose=purpose,
                      triangles=int(len(mesh.faces))))

def box(name, center, size, mat, system, purpose):
    m=trimesh.creation.box(extents=size)
    m.apply_translation(center)
    add(name,m,mat,system,purpose)

def rod(name, a, b, radius, mat, system, purpose, sides=12):
    a=np.array(a, dtype=float); b=np.array(b,dtype=float)
    d=b-a; length=np.linalg.norm(d)
    if length < 0.0001: raise ValueError(name)
    m=trimesh.creation.cylinder(radius=radius,height=length,sections=sides)
    T=trimesh.geometry.align_vectors([0,0,1], d/length)
    m.apply_transform(T)
    m.apply_translation((a+b)/2)
    add(name,m,mat,system,purpose)

def pipe(name, points, radius, mat, system, purpose):
    for i in range(len(points)-1):
        rod(f'{name}_segment_{i+1}',points[i],points[i+1],radius,mat,system,purpose,10)
    for i,p in enumerate(points[1:-1]):
        m=trimesh.creation.icosphere(subdivisions=1,radius=radius)
        m.apply_translation(p)
        add(f'{name}_elbow_{i+1}',m,mat,system,purpose)

def cylinder(name, center, radius, height, mat, system, purpose, sides=32):
    m=trimesh.creation.cylinder(radius=radius,height=height,sections=sides)
    m.apply_translation(center)
    add(name,m,mat,system,purpose)

def ring(name, center, inner, outer, height, mat, system, purpose, sides=36):
    m=trimesh.creation.annulus(r_min=inner,r_max=outer,height=height,sections=sides)
    m.apply_translation(center)
    add(name,m,mat,system,purpose)

def oct_prism(name, bottom, top, low_size, high_size, chamfer, mat, system, purpose):
    """A chamfered eight-sided concrete casting, not a pile of identical cubes."""
    def outline(w,d,c):
        x=w/2; y=d/2
        return [(-x+c,-y),(x-c,-y),(x,-y+c),(x,y-c),
                (x-c,y),(-x+c,y),(-x,y-c),(-x,-y+c)]
    v=[]
    for z,(w,d) in ((bottom,low_size),(top,high_size)):
        v.extend([(x,y,z) for x,y in outline(w,d,chamfer)])
    f=[]
    f.extend([(0,i+1,i) for i in range(1,7)])
    f.extend([(8,8+i,8+i+1) for i in range(1,7)])
    for i in range(8):
        j=(i+1)%8
        f.extend([(i,j,8+j),(i,8+j,8+i)])
    m=trimesh.Trimesh(vertices=v,faces=f,process=False)
    add(name,m,mat,system,purpose)

def strut(name, a, b, width, thickness, mat, system, purpose):
    # A rectangular load-bearing rib with its long axis between anchors.
    a=np.array(a,float); b=np.array(b,float)
    d=b-a; length=np.linalg.norm(d)
    m=trimesh.creation.box(extents=(width,thickness,length))
    m.apply_transform(trimesh.geometry.align_vectors([0,0,1], d/length))
    m.apply_translation((a+b)/2)
    add(name,m,mat,system,purpose)

def anchor_bolt(prefix,loc,axis='z',radius=0.035):
    p=np.array(loc,float)
    dv={'z':[0,0,.055], 'x':[.055,0,0], 'y':[0,-.055,0]}[axis]
    rod(prefix,p-np.array(dv),p+np.array(dv),radius,'brass','fasteners','Removable armor plate/structural mount fastener',8)

# v0.4 surface contracts: no world-space "old flat wall" offsets.
# The primary bunker shell is a linear taper from 2.75x2.71 at z=.38
# to 2.43x2.39 at z=1.31, with .24 diagonal chamfers at the corners.
ATTACHMENTS = []
BUTTRESS_PROFILES = []

def shell_half(z, axis):
    assert .38 <= z <= 1.31, (axis,z)
    frac = (z - .38) / (1.31 - .38)
    bottom = 2.75 if axis == 'x' else 2.71
    top = 2.43 if axis == 'x' else 2.39
    return (bottom + frac * (top - bottom)) / 2

def face_xyz(face, lateral, z, offset=0):
    """Point on a tapered cardinal shell plane; positive offset is outside."""
    r = shell_half(z, 'x' if face in ('E','W') else 'y') + offset
    return ({'E':(r,lateral,z),'W':(-r,lateral,z),
             'N':(lateral,r,z),'S':(lateral,-r,z)})[face]

def face_plate(name, face, lateral, z, span, height, thickness, mat, system, purpose,
               penetration=.025, stand_off=0.0):
    """A true sloped 8-vertex mount. Its inner skin penetrates the wall or backing plate."""
    z0,z1=z-height/2,z+height/2
    assert .38 <= z0 < z1 <= 1.31, (name,z0,z1)
    assert span>0 and thickness>0 and penetration>=0
    # Inner face intersects the shell by penetration, outer follows shell slope.
    inner=stand_off-penetration
    outer=stand_off+thickness
    def point(t,zv,ofs): return face_xyz(face,t,zv,ofs)
    v=[point(lateral-span/2,z0,inner), point(lateral+span/2,z0,inner),
       point(lateral+span/2,z1,inner), point(lateral-span/2,z1,inner),
       point(lateral-span/2,z0,outer), point(lateral+span/2,z0,outer),
       point(lateral+span/2,z1,outer), point(lateral-span/2,z1,outer)]
    faces=[(0,2,1),(0,3,2),(4,5,6),(4,6,7),
           (0,1,5),(0,5,4),(1,2,6),(1,6,5),
           (2,3,7),(2,7,6),(3,0,4),(3,4,7)]
    m=trimesh.Trimesh(vertices=v,faces=faces,process=False)
    add(name,m,mat,system,purpose)
    ATTACHMENTS.append({'name':name,'face':face,'lateral':lateral,
      'z_bottom':z0,'z_top':z1,'stand_off':stand_off,'penetration':penetration,
      'outer_projection':thickness,'surface_slope':round((shell_half(z1,'x' if face in ('E','W') else 'y')-shell_half(z0,'x' if face in ('E','W') else 'y'))/(z1-z0),6),
      'contact_type':'shell' if stand_off==0 else 'face-mounted equipment'})
    return m

def fitted_box(name, face, lateral, z, sx, sy, sz, offset, mat, system, purpose):
    """Place rectangular secondary fittings slightly penetrating their host.
    `offset` here measures from tapered shell face to the fitting center."""
    x,y,_=face_xyz(face,lateral,z,offset)
    box(name,(x,y,z),(sx,sy,sz),mat,system,purpose)
    return np.array((x,y,z))

def sloped_buttress(name,sx,sy,lower_z,upper_z,low_center,high_center,
                     low_size,high_size,mat,system,purpose):
    """A real tapered chamfered structural rib, four sloped faces and bevelled corners.
    Every upper corner moves toward center, in BOTH plan axes."""
    def outline(cx,cy,w,d,bevel):
        x=w/2;y=d/2;c=bevel
        return [(cx-x+c,cy-y),(cx+x-c,cy-y),(cx+x,cy-y+c),
                (cx+x,cy+y-c),(cx+x-c,cy+y),(cx-x+c,cy+y),
                (cx-x,cy+y-c),(cx-x,cy-y+c)]
    low=outline(sx*low_center[0],sy*low_center[1],*low_size,.08)
    high=outline(sx*high_center[0],sy*high_center[1],*high_size,.065)
    v=[(x,y,lower_z) for x,y in low]+[(x,y,upper_z) for x,y in high]
    f=[(0,i+1,i) for i in range(1,7)] + [(8,8+i,8+i+1) for i in range(1,7)]
    for i in range(8):
        j=(i+1)%8;f.extend([(i,j,8+j),(i,8+j,8+i)])
    m=trimesh.Trimesh(vertices=v,faces=f,process=False)
    add(name,m,mat,system,purpose)
    BUTTRESS_PROFILES.append({'name':name,'sx':sx,'sy':sy,'lower_z':lower_z,
        'upper_z':upper_z,'low_center':low_center,'high_center':high_center,
        'low_size':low_size,'high_size':high_size})
    return m

def surface_strut(name,face,start_lateral,start_z,end_lateral,end_z,
                  width,depth,mat,system,purpose):
    """Compression rib seated across two positions on a sloped exterior wall."""
    a=face_xyz(face,start_lateral,start_z,depth*.25)
    b=face_xyz(face,end_lateral,end_z,depth*.25)
    strut(name,a,b,width,depth,mat,system,purpose)
    ATTACHMENTS.append({'name':name,'face':face,'lateral':(start_lateral+end_lateral)/2,
     'z_bottom':min(start_z,end_z),'z_top':max(start_z,end_z),'contact_type':'strut',
     'penetration':depth*.25})

# 3×3 matching vanilla assembler footprint for controlled size comparison.
# Ground is z=0; front is y=- (gun elevation along negative Y).
oct_prism('01_foundation_granular_ferrocrete',.00,.26,(3.0,3.0),(2.99,2.99),.25,
    'ferrocrete_dark','load_path','Full 3x3 footprint; strongly chamfered/blast-deflecting outer plinth')
oct_prism('02_lower_blast_raft',.20,.40,(2.88,2.82),(2.76,2.72),.24,
    'ferrocrete_light','load_path','Beveled interlocking heavy slab sheds blast into lower plinth')
oct_prism('03_monolithic_bunker_mass',.38,1.31,(2.75,2.71),(2.43,2.39),.24,
    'ferrocrete','load_path','Cast mass supports gun ring and shields controls and magazine')
oct_prism('04_upper_blast_cap',1.23,1.47,(2.62,2.62),(2.44,2.44),.24,
    'ferrocrete_dark','load_path','Tapered armored roof cap; smaller upper profile transfers bearing forces into walls')
oct_prism('05_top_concrete_skin',1.47,1.525,(2.44,2.44),(2.35,2.35),.23,
    'ferrocrete_light','load_path','Narrow upper cast drainage plane; radial sweep around mounting ring')

# Sloped, octagonal corner ribs, let into BOTH changing outer shell and its raft.
# Lower corners are visibly broader/farther outward; top corners lean inward.
for sx,labelx in [(-1,'W'),(1,'E')]:
    for sy,labely in [(-1,'S'),(1,'N')]:
        sloped_buttress(f'06_corner_armor_buttress_{labelx}{labely}',sx,sy,.43,1.33,
            (1.235,1.155),(1.085,1.005),(.49,.53),(.32,.35),
            'ferrocrete_dark','load_path',
            'Genuinely inward-sloping, beveled ferrocrete corner pillar seated in load path')
        sloped_buttress(f'07_corner_buttress_foot_{labelx}{labely}',sx,sy,.29,.51,
            (1.225,1.145),(1.232,1.154),(.59,.64),(.51,.55),
            'ferrocrete_light','load_path','Beveled spread footing overlaps first course of tapered buttress')

# South face: openings and all its fixtures conform to its actual inclined plane.
face_plate('08_recessed_hatch_void','S',0,.76,.67,.71,.036,
    'dark_recess','service','Inset hatch aperture fully seated into beveled exterior wall')
face_plate('09_steel_service_hatch','S',0,.75,.52,.61,.066,
    'martian_red','service','Armor closure follows tapered concrete wall without air gap',stand_off=.032,penetration=.042)
face_plate('10_service_hatch_spine','S',0,.75,.085,.51,.04,
    'machine_steel','service','Surface-aligned locking spine fixed through hatch',stand_off=.092,penetration=.02)
for x in [-.22,.22]:
    for z in [.52,.97]:
        px,py,_=face_xyz('S',x,z,.11)
        anchor_bolt(f'10_hatch_fastener_{x}_{z}',(px,py,z),'y',.028)
face_plate('11_left_approach_sensor','S',-.95,.95,.28,.17,.083,
    'iron','sensing','Protected thermal enclosure seated on sloped south wall')
face_plate('12_left_approach_lens','S',-.95,.96,.16,.08,.035,
    'glass','sensing','Detector aperture intersecting and attached to its enclosure',stand_off=.072,penetration=.026)

# Turret ring: independent bearing; roof remains stationary.
cylinder('13_ring_lower_bearing_seat',(0,0,1.59),.80,.14,
         'machine_steel','traverse','Bolted structural lower bearing seat')
ring('14_ring_open_bearing_race',(0,0,1.705),.56,.74,.095,
    'iron','traverse','Clear continuous traverse bearing annulus')
cylinder('15_ring_rotary_platform',(0,0,1.76),.59,.12,
    'red_dark','traverse','Armored rotating platform and rotary power/signal coupling')
for i in range(12):
    a=math.radians(i*30)
    anchor_bolt(f'15_bearing_bolt_{i+1}',(.76*math.cos(a),.76*math.sin(a),1.65),'z',.022)

# Low armored turret is faceted to deflect and absorb impact; breech is fully supported.
oct_prism('16_martian_red_turret_armor',1.82,2.28,(1.52,1.35),(1.30,1.20),.18,
    'martian_red','armor','Ballistic armor on rotating carriage')
box('17_turret_front_cheek_W',(-.57,-.63,2.01),(.25,.22,.46),
    'red_dark','armor','Left bearing/trunnion cheek protects gun elevation coupling')
box('18_turret_front_cheek_E',(.57,-.63,2.01),(.25,.22,.46),
    'red_dark','armor','Right bearing/trunnion cheek protects gun elevation coupling')
box('19_cannon_mantlet',(0,-.76,2.01),(.68,.22,.45),
    'red_highlight','armor','Armored mantlet around barrel and elevation hardware')
box('20_enclosed_breech',(0,-.13,2.06),(.61,.66,.34),
    'iron','weapon','Recoiling breech behind mantlet, inside turret protection')
box('21_gun_tube_outer_shroud',(0,-1.06,2.02),(.27,.89,.27),
    'machine_steel','weapon','Square armored heavy-gun tube with visible recoil route')
rod('22_primary_cannon_barrel',(0,-1.09,2.02),(0,-1.90,2.02),.103,
    'iron','weapon','Ballistic barrel carrying projectile from breech through mantlet',16)
rod('23_muzzle_reinforcement',(0,-1.82,2.02),(0,-1.94,2.02),.155,
    'machine_steel','weapon','Replaceable ring at heat-affected muzzle',16)
for sx,label in [(-1,'W'),(1,'E')]:
    rod(f'24_recoil_piston_{label}',(sx*.30,-.79,1.92),(sx*.30,-1.36,1.92),.064,
        'machine_steel','weapon','Parallel sliding recoil damper between mantlet and cradle',12)
    rod(f'25_recoil_guard_{label}',(sx*.30,-.79,1.92),(sx*.30,-.96,1.92),.09,
        'red_dark','weapon','Armored stationary housing around recoil rod',12)

# Ammunition module is fixed in bunker, with protected turret interface.
box('26_rear_armor_magazine',(0,.92,1.37),(.62,.44,.26),
    'red_dark','ammo','Armored ammunition lift and ready-magazine below aft turret')
box('27_protected_breech_feed',(0,.54,1.46),(.27,.62,.20),
    'iron','ammo','Feeds from static lift into breech through elevated protected route')
box('28_right_magazine_inspection_panel',(.36,.92,1.39),(.08,.28,.21),
    'red_highlight','ammo','Removal inspection plate over magazine feed drive')
for y in [.85,1.06]: anchor_bolt(f'28_magazine_bolt_{y}',(.42,y,1.40),'x',.025)

# Power & signal paths terminate at cabinets / rotary coupling, never nowhere.
box('29_rear_control_cabinet',(-1.03,.94,1.38),(.35,.46,.25),
    'iron','control','Ballistic-protected remote-fire electronics outside rotating envelope')
box('30_controller_access_panel',(-1.03,1.188,1.38),(.29,.025,.19),
    'red_highlight','control','Serviced controller access panel')
# The mast is part of the rotating turret, not fixed atop the bunker.
strut('31_antenna_mount_angled_rear',(.42,.49,2.15),(.47,.84,2.35),
      .13,.15,'machine_steel','comms','Rear casing bolted standoff; rotates with turret and clears barrel')
box('31_antenna_base',(.47,.81,2.39),(.20,.24,.20),
    'iron','comms','Remote telemetry mast seated on the back of the rotating armor shell')
rod('32_telemetry_mast',(.47,.85,2.46),(.47,.85,3.01),.038,
    'machine_steel','comms','Low-profile co-traversing vox/remote telemetry mast')
rod('33_telemetry_crossarm',(.29,.85,2.84),(.65,.85,2.84),.023,
    'machine_steel','comms','Aerial crossarm on turret rear; cannot enter muzzle half-space')
for sx,label in [(-1,'W'),(1,'E')]:
    rod(f'34_mast_antenna_element_{label}',(.47+sx*.15,.85,2.75),(.47+sx*.15,.85,2.98),.015,
        'brass','comms','Tuned antenna element on co-rotating remote-control mast')
pipe('35_telemetry_hardline',[(.47,.80,2.46),(.47,.63,2.38),(.39,.49,2.33),(.28,.19,2.20)],
    .028,'machine_steel','power_signal','Mast connects to co-rotating turret control bus; fixed feed via slip ring')
pipe('36_controller_to_slipring',[(-1.03,.89,1.43),(-.83,.74,1.44),(-.60,.52,1.51),(-.44,.22,1.64)],
    .037,'machine_steel','power_signal','Low stationary controller cable to protected rotating slip ring')
pipe('37_ammo_condition_probe_to_controller',[(.27,.93,1.36),(.36,1.06,1.35),(.36,1.16,1.27),(-1.03,1.16,1.27)],
    .025,'brass','power_signal','Ready-magazine condition cable kept below turret underside')

# Targeting optic physically seated on turret cheek (rotating with gun).
box('38_primary_optic_mount',(-.68,-.42,2.16),(.29,.25,.23),
    'iron','sensing','Protected co-traversing thermal/visible sight head mount')
box('39_primary_optic_lens',(-.68,-.568,2.18),(.17,.035,.10),
    'glass','sensing','Forward target optics with clear muzzle-adjacent line of sight')
box('40_coax_rangefinder_mount',(.61,.12,2.24),(.25,.24,.22),
    'machine_steel','sensing','Secondary independent range channel on rotating turret')
rod('41_rangefinder_aperture',(.62,.01,2.28),(.62,-.13,2.28),.06,
    'glass','sensing','Directed secondary ranging aperture',12)
pipe('42_turret_optics_data',[(-.68,-.34,2.17),(-.68,-.06,2.18),(-.39,.12,2.22)],
    .027,'brass','power_signal','Optic head to gun control bus on turret')
pipe('43_turret_ranging_data',[(.61,.15,2.24),(.48,.25,2.23),(.32,.17,2.21)],
    .023,'brass','power_signal','Rangefinder to rotating target-control electronics')

# Cooling vent and louvers are anchored to the bevel, not hanging behind it.
face_plate('44_rear_vent_guard','N',-.30,.78,.52,.30,.072,
    'iron','thermal','Rear heat aperture backed by real concrete face')
for i in range(4):
    face_plate(f'45_vent_louver_{i+1}','N',-.49+i*.12,.79,.048,.22,.028,
        'machine_steel','thermal','Actual mounted intake louvers over rear cooling duct',stand_off=.056,penetration=.024)
# Certification attaches directly to the accessible rear controller cover, not air.
box('46_maintenance_purity_certificate',(-1.03,1.214,1.38),(.155,.012,.13),
    'parchment','rites','Controller-specific certificate affixed flush to serviced cabinet')
box('47_oil_service_port',(.54,-.47,2.26),(.13,.10,.06),
    'brass','rites','Oiling point for weapon elevation bearing, mechanically anchored')

# Fasteners only where mechanical joins and exposed armor plates exist.
for x in [-.57,.57]:
    for z in [1.89,2.12]:
        anchor_bolt(f'48_front_cheek_fastener_{x}_{z}',(x,-.76,z),'y',.023)
for x in [-1.06,1.06]:
    for y in [-1.06,1.06]:
        anchor_bolt(f'49_roof_anchor_{x}_{y}',(x,y,1.55),'z',.036)


# True tapered-wall-aligned structural gothic buttresses around service hatch.
for side,letter in [(-1,'W'),(1,'E')]:
    surface_strut(f'50_structural_front_gothic_rib_{letter}','S',
          side*.57,.47,side*.21,1.15,.12,.21,
          'ferrocrete_light','load_path','Load-bearing diagonal rib seated continuously on sloped wall')
    face_plate(f'51_gothic_rib_foot_anchor_{letter}','S',side*.56,.47,
          .22,.14,.12,'ferrocrete_dark','load_path','Rib foot penetrates tapered south wall and sill')
surface_strut('52_keystone_stiffener_across_front','S',-.21,1.15,.21,1.15,
      .13,.20,'ferrocrete_light','load_path','Hatch lintel physically seated on angled exterior wall')
# Cast slab front edges deliberately read as separate concrete pours.
box('53_south_slab_anchor_strip',(0,-1.277,1.30),(2.27,.055,.11),
    'ferrocrete_light','load_path','Protective lintel below roof and turret ring')
box('54_north_slab_anchor_strip',(0,1.257,1.30),(2.27,.055,.11),
    'ferrocrete_light','load_path','Back concrete roof boundary tied to load bearing wall')

# Side panels are TRUE projected trapezoids. No old x=1.39 flat wall offsets.
face_plate('55_east_wall_controller_armor','E',-.45,.89,.70,.43,.065,
    'martian_red','armor','Removable controller armor with back perfectly following wall slope')
face_plate('56_east_side_outer_stiffener','E',-.45,.89,.065,.48,.063,
    'machine_steel','armor','Stiffener bolted through tilted controller panel',stand_off=.058,penetration=.021)
for y in [-.73,-.17]:
    for z in [.74,1.04]:
        px,py,_=face_xyz('E',y,z,.086)
        anchor_bolt(f'57_side_cabinet_bolt_{y}_{z}',(px,py,z),'x',.022)

# Armored feedthroughs run along the actual tapered wall. The upper portion
# turns into its protected disconnect rather than hanging in an old-air path.
pipe('58_exterior_power_entry',[
    (1.442,.50,.29),face_xyz('E',.50,.45,.044),
    face_xyz('E',.50,.69,.049),face_xyz('E',.86,.70,.047)],
     .061,'iron','power_signal','Conduit maintains continuous physical contact along sloping wall')
face_plate('59_exterior_supply_breaker','E',.88,.72,.20,.20,.14,
    'iron','control','Power breaker physically fastened to east wall and source conduit')
fitted_box('60_exterior_supply_lamp','E',.88,.74,.025,.07,.06,.15,
    'alert','control','Status light seated on breaker outer face')

# Engineered cast roof ribs tie traversal ring to four main bunker buttresses.
for sx,side in [(-1,'W'),(1,'E')]:
    box(f'61_ring_radial_armor_brace_{side}',(sx*.94,0,1.55),(.57,.26,.11),
        'machine_steel','traverse','Bolted ring-to-roof stiffener connecting turret reaction to side wall')
    anchor_bolt(f'62_ring_brace_anchor_{side}',(sx*1.12,0,1.628),'z',.025)

# Armor lip and protected lens help the identity read at reduced game size.
box('63_armored_turret_front_brow',(0,-.73,2.29),(.97,.14,.085),
    'red_dark','armor','Overhanging top brow shields front sensor and gun elevation gear')
box('64_steel_optic_rain_visor',(-.68,-.59,2.27),(.24,.19,.065),
    'machine_steel','sensing','Optic shield from rain and spall without blocking line of sight')

# Service port with a paired physical instrument so blessing gear is not gratuitous.
rod('65_oil_service_manifold',(.56,-.43,2.27),(.46,-.34,2.27),.023,
    'brass','rites','Short service conduit between oil port and elevation gearbox',12)
face_plate('66_bunker_condition_gauge','W',.45,.79,.19,.22,.09,
    'iron','sensing','Condition-monitoring gauge actually touching left tapered shell')
face_plate('67_bunker_condition_lens','W',.45,.81,.09,.08,.022,
    'glass','sensing','Visible glass diagnostic seated into gauge housing',stand_off=.082,penetration=.02)

# Enforce fitted attachments at lower AND upper edges, not just a single-point test.
# Any panel's rear surface MUST penetrate its supporting tapered shell.
for a in ATTACHMENTS:
    if a['contact_type'] in ('shell','face-mounted equipment'):
        g=SCENE.geometry[a['name']]
        ax=0 if a['face'] in ('E','W') else 1
        sign=1 if a['face'] in ('E','N') else -1
        coords=np.array(g.vertices)
        for z in (a['z_bottom'],a['z_top']):
            sl=coords[np.abs(coords[:,2]-z)<.0001]
            assert len(sl)>=4,(a['name'],z,len(sl))
            wall=shell_half(z,'x' if ax==0 else 'y')
            inner=np.min(sign*sl[:,ax]);outer=np.max(sign*sl[:,ax])
            if a['contact_type']=='shell':
                assert inner <= wall + .001 and outer >= wall + .01,(a['name'],z,inner,wall,outer)
            else:
                # Accessories overlap parent equipment; never left floating in air.
                assert inner <= wall + a['stand_off'] + .001,(a['name'],z,inner,wall)
                assert outer > wall + a['stand_off'] + .01,(a['name'],z,outer,wall)
    elif a['contact_type']=='strut':
        assert a['penetration']>0,(a['name'],a)
for a in BUTTRESS_PROFILES:
    lx,ly=a['low_center'];hx,hy=a['high_center']
    if a['name'].startswith('06_'):
        assert hx<lx and hy<ly,(a['name'],'non-inward-leaning')
    g=SCENE.geometry[a['name']]
    assert len(g.vertices)==16 and np.ptp(g.vertices[:,2])>.15,(a['name'],'not a sloped buttress')
    if a['name'].startswith('06_'):
        for z,center,size in ((a['lower_z'],a['low_center'],a['low_size']),
                              (a['upper_z'],a['high_center'],a['high_size'])):
            # Chamfered corner of bunker: sum of signed east/south projections
            # crosses the octagonal bunker corner plane: some material embedded,
            # some outside; this means structurally anchored rather than floating.
            xh=shell_half(min(max(z,.38),1.31),'x')
            yh=shell_half(min(max(z,.38),1.31),'y')
            diagonal=xh+yh-.24
            ctrsum=center[0]+center[1]
            assert ctrsum-(size[0]+size[1])*.5 < diagonal < ctrsum+(size[0]+size[1])*.5,(a['name'],z,ctrsum,diagonal)
# Additional flag: world-space static mounts must follow the shell's slope.
for name in ('08_recessed_hatch_void','09_steel_service_hatch',
 '11_left_approach_sensor','44_rear_vent_guard','55_east_wall_controller_armor',
 '59_exterior_supply_breaker','66_bunker_condition_gauge'):
    a=next(x for x in ATTACHMENTS if x['name']==name)
    assert abs(a['surface_slope']) > .17,(name,a['surface_slope'])
print('HULL_SURFACE_CONTACT_AND_INWARD_BUTTRESS_GEOMETRY_PASSED',len(ATTACHMENTS),len(BUTTRESS_PROFILES))

# Clearance contract: items above the fixed structures rotate together as a single assembly.
# Track moving groups explicitly rather than treating the mast as an unrelated fixed roof item.
MOVING_PREFIXES=('15_ring_rotary_platform','16_martian_red_turret_armor','17_turret_front_cheek',
 '18_turret_front_cheek','19_cannon_mantlet','20_enclosed_breech','21_gun_tube',
 '22_primary_cannon','23_muzzle','24_recoil','25_recoil','31_antenna',
 '32_telemetry','33_telemetry','34_mast','35_telemetry','38_primary',
 '39_primary','40_coax','41_rangefinder','42_turret','43_turret',
 '47_oil_service','48_front','63_armored_turret','64_steel_optic',
 '65_oil_service')
fixed_rear_prefixes=('26_rear','27_protected','28_right','28_magazine',
 '29_rear','30_controller','36_controller','37_ammo')
stationary=[x for x in SCENE.geometry.items() if x[0].startswith(fixed_rear_prefixes)]
rotating=[x for x in SCENE.geometry.items() if x[0].startswith(MOVING_PREFIXES)]
assert len(rotating)>20 and len(stationary)>7, (len(rotating),len(stationary))
fixed_rear_bodies=[g for name,g in stationary if name.startswith(('26_','27_','28_','29_','30_'))]
max_fixed_body_z=max(float(g.bounds[1,2]) for g in fixed_rear_bodies)
min_rotating_z=min(float(g.bounds[0,2]) for name,g in rotating)
max_fixed_rear_z=max(float(g.bounds[1,2]) for name,g in stationary)
assert min_rotating_z>=1.69 and max_fixed_rear_z<=1.68
assert min_rotating_z-max_fixed_body_z>=.10, (min_rotating_z,max_fixed_body_z)
# A fixed rear part must either be underneath the moving assembly or beyond its radial sweep.
for name,g in stationary:
    assert g.bounds[1,2] < min_rotating_z-.015, (name,g.bounds)
assert all('comms' != p['system'] or p['name'].startswith(('31_','32_','33_','34_'))
           for p in PARTS)
assert all(p['triangles'] > 0 for p in PARTS)

MODEL_PATH=OUT/'martian_heavy_weapon_bunker_source_geometry_v04.glb'
SCENE.export(MODEL_PATH)
manifest={
    'asset_id':'red-tech-priests/fortified-martian-heavy-weapon-bunker',
    'version':'v0.4 conforming hull fixtures and sloped structural buttresses, NOT final visual acceptance',
    'authorship':'Original mesh geometry generated from project doctrine; no Factorio source meshes embedded',
    'reference_footprint_tiles':[3,3],
    'coordinate_convention':'+Z up; -Y forward/muzzle; +X east',
    'render_comparison':'Factorio assembling-machine 3x3 visual-density benchmark, NOT geometry source',
    'parts_count':len(PARTS),
    'rotating_mesh_count':len(rotating),
    'static_rear_top_z':max_fixed_rear_z,
    'rear_equipment_top_z':max_fixed_body_z,
    'rear_equipment_clearance_z':min_rotating_z-max_fixed_body_z,
    'moving_min_z':min_rotating_z,
    'rear_vertical_clearance':min_rotating_z-max_fixed_rear_z,
    'rear_mast_mount':'turret rear casing (co-rotating, behind bore line)',
    'base_footprint_unchanged':True,
    'triangles_total':sum(p['triangles'] for p in PARTS),
    'assets':[p for p in PARTS],
    'hull_attachments':ATTACHMENTS,
    'inward_sloped_buttresses':BUTTRESS_PROFILES,
    'functional_links':[
        ['telemetry mast','telemetry hardline','rear controller'],
        ['rear controller','controller to slip ring','gun traverse electronics'],
        ['magazine lift','protected feed','gun breech'],
        ['ammunition sensor','ammo condition cable','rear controller'],
        ['primary optic','optics cable','turret control bus'],
        ['rangefinder','ranging cable','turret control bus'],
    ],
    'limitations':['Simplified all-solid blockout (not internal cutaway)',
       'Weapon traverse rig and muzzle flare layers not animated',
       'Render materials are color IDs only, not PBR final',
       'Turret swept volume clear of stationary rear equipment based on conservative radial and Z envelopes; physical rotation needs Blender rig validation',
       'No native Factorio sprite has been overwritten'],
}
(OUT/'component_manifest_v04.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'glb':str(MODEL_PATH),'parts':len(PARTS),'triangles':manifest['triangles_total'],'bounds':SCENE.bounds.tolist()},indent=2))


# Explicit Z-up original-coordinate geometry contract for Blender. Avoid glTF
# automatic up-axis rotation and incomplete vertex-color materials on import.
# Blender builds from these source mesh coordinates, and exports canonical GLB.
geometry_payload = {
    'version': 'v0.4-native-blender-source',
    'axes': '+Z up, -Y gun forward, +X right',
    'materials': COL,
    'parts': [
        {'name': meta['name'], 'material': meta['material'],
         'rotating': meta['name'].startswith(MOVING_PREFIXES),
         'vertices': SCENE.geometry[meta['name']].vertices.tolist(),
         'faces': SCENE.geometry[meta['name']].faces.tolist()}
        for meta in PARTS
    ],
}
assert len(geometry_payload['parts']) >= 125
payload_raw = json.dumps(geometry_payload, separators=(',', ':'), sort_keys=True).encode('utf8')
(OUT / 'original_z_up_mesh_payload_v04.json.gz').write_bytes(gzip.compress(payload_raw, compresslevel=9, mtime=0))
print('BUNKER_Z_UP_SOURCE_PAYLOAD_OK', len(geometry_payload['parts']), 'meshes',len(payload_raw),'uncompressed bytes')
