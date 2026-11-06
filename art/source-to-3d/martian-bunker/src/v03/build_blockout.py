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

# Corner ribs: massed weight, not decorative arches.
for sx,labelx in [(-1,'W'),(1,'E')]:
    for sy,labely in [(-1,'S'),(1,'N')]:
        box(f'06_corner_armor_buttress_{labelx}{labely}',(sx*1.18,sy*1.10,.85),(.34,.48,.96),
            'ferrocrete_dark','load_path','External vertical anti-blast buttress supports roof')
        box(f'07_corner_buttress_foot_{labelx}{labely}',(sx*1.17,sy*1.09,.42),(.51,.60,.21),
            'ferrocrete_light','load_path','Spread footing for blast/ring forces')

# Narrow sacrificial machine-access hatch (visible on south face).
box('08_recessed_hatch_void',(0,-1.391,.72),(.65,.045,.75),
    'dark_recess','service','Recess behind armored machine service closure')
box('09_steel_service_hatch',(0,-1.426,.75),(.52,.065,.63),
    'martian_red','service','Removable armored access to sealed controls and maintenance tools')
box('10_service_hatch_spine',(0,-1.470,.75),(.09,.035,.55),
    'machine_steel','service','Hatch locking/reinforcement bar')
for x in [-.22,.22]:
    for z in [.50,1.00]: anchor_bolt(f'10_hatch_fastener_{x}_{z}',(x,-1.474,z),'y',.028)
box('11_left_approach_sensor',(-.95,-1.39,.95),(.29,.095,.17),
    'iron','sensing','Protected close-approach thermal detector enclosure')
box('12_left_approach_lens',(-.95,-1.453,.96),(.17,.025,.08),
    'glass','sensing','Senses bunker immediate approach from low-angle slit')

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

# Real exhaust air handling and service point; light devotional cue near inspected component.
box('44_rear_vent_guard',(-.30,1.42,.78),(.52,.07,.30),
    'iron','thermal','Shielded exhaust/cooling vent for magazines and controllers')
for i in range(4):
    box(f'45_vent_louver_{i+1}',(-.49+i*.12,1.47,.79),(.045,.03,.23),
        'machine_steel','thermal','Airflow louver blocks debris and shrapnel')
box('46_maintenance_purity_certificate',(-.98,1.288,1.68),(.17,.008,.20),
    'parchment','rites','Inspection certification attached to actual controller access panel')
box('47_oil_service_port',(.54,-.47,2.26),(.13,.10,.06),
    'brass','rites','Oiling point for weapon elevation bearing, mechanically anchored')

# Fasteners only where mechanical joins and exposed armor plates exist.
for x in [-.57,.57]:
    for z in [1.89,2.12]:
        anchor_bolt(f'48_front_cheek_fastener_{x}_{z}',(x,-.76,z),'y',.023)
for x in [-1.06,1.06]:
    for y in [-1.06,1.06]:
        anchor_bolt(f'49_roof_anchor_{x}_{y}',(x,y,1.55),'z',.036)


# Front reinforced pointed access rib is structural, not pasted-on cathedral trim.
# The paired struts and high meeting brace transfer roof load around the narrow hatch.
for side,letter in [(-1,'W'),(1,'E')]:
    strut(f'50_structural_front_gothic_rib_{letter}',
          (side*.57,-1.505,.45),(side*.21,-1.505,1.15),
          .11,.13,'ferrocrete_light','load_path',
          'Oblique compression member diverts roof loads around maintenance access')
    box(f'51_gothic_rib_foot_anchor_{letter}',
        (side*.56,-1.515,.45),(.22,.15,.13),
        'ferrocrete_dark','load_path','Foot of compression rib tied to ferrocrete sill')
strut('52_keystone_stiffener_across_front',(-.21,-1.50,1.15),(.21,-1.50,1.15),
      .13,.15,'ferrocrete_light','load_path',
      'High cross-brace transfers paired rib loads toward roof cap')
# Cast slab front edges deliberately read as separate concrete pours.
box('53_south_slab_anchor_strip',(0,-1.277,1.30),(2.27,.055,.11),
    'ferrocrete_light','load_path','Protective lintel below roof and turret ring')
box('54_north_slab_anchor_strip',(0,1.257,1.30),(2.27,.055,.11),
    'ferrocrete_light','load_path','Back concrete roof boundary tied to load bearing wall')

# Two prominent side armored service panels with actual locking fasteners.
box('55_east_wall_controller_armor',(1.393,-.45,.89),(.062,.72,.43),
    'martian_red','armor','Slab-mounted removable side access to bunker controller bus')
box('56_east_side_outer_stiffener',(1.442,-.45,.89),(.09,.065,.49),
    'machine_steel','armor','Vertical stiffening plate over side maintenance cover')
for y in [-.76,-.14]:
    for z in [.71,1.08]: anchor_bolt(f'57_side_cabinet_bolt_{y}_{z}',(1.458,y,z),'x',.022)

# Armored feedthrough is visible from exterior and terminates in fixed cabinet.
pipe('58_exterior_power_entry',[(1.50,.50,.26),(1.50,.50,.69),(1.41,.50,.69),(1.41,.93,.70)],
     .075,'iron','power_signal','Ground-level incoming power feed to protected machine controller')
box('59_exterior_supply_breaker',(1.465,.93,.72),(.18,.22,.20),
    'iron','control','External armored disconnect at service entry')
box('60_exterior_supply_lamp',(1.568,.93,.74),(.013,.073,.06),
    'alert','control','Bus energized/status telltale adjacent to supply breaker')

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
box('66_bunker_condition_gauge',(-1.39,.45,.79),(.09,.19,.22),
    'iron','sensing','External vibration and load-state sensor at cast wall')
box('67_bunker_condition_lens',(-1.45,.45,.81),(.02,.09,.08),
    'glass','sensing','Diagnostic panel reports vibration of turret load path')

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

MODEL_PATH=OUT/'martian_heavy_weapon_bunker_source_geometry_v03.glb'
SCENE.export(MODEL_PATH)
manifest={
    'asset_id':'red-tech-priests/fortified-martian-heavy-weapon-bunker',
    'version':'v0.3 corrected Blender coordinate+material import, NOT final visual acceptance',
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
(OUT/'component_manifest_v03.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'glb':str(MODEL_PATH),'parts':len(PARTS),'triangles':manifest['triangles_total'],'bounds':SCENE.bounds.tolist()},indent=2))


# Explicit Z-up original-coordinate geometry contract for Blender. Avoid glTF
# automatic up-axis rotation and incomplete vertex-color materials on import.
# Blender builds from these source mesh coordinates, and exports canonical GLB.
geometry_payload = {
    'version': 'v0.3-native-blender-source',
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
assert len(geometry_payload['parts']) == 131
payload_raw = json.dumps(geometry_payload, separators=(',', ':'), sort_keys=True).encode('utf8')
(OUT / 'original_z_up_mesh_payload_v03.json.gz').write_bytes(gzip.compress(payload_raw, compresslevel=9, mtime=0))
print('BUNKER_Z_UP_SOURCE_PAYLOAD_OK', len(geometry_payload['parts']), 'meshes',len(payload_raw),'uncompressed bytes')
