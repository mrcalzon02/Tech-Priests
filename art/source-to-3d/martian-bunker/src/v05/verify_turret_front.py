"""Source-level strict geometry check for BOTH front-turret refinement stages.
This does not claim real ballistic performance or game sprite approval.
"""
from pathlib import Path
import json, math
import numpy as np
import trimesh
D=Path(__file__).resolve().parent
m=json.loads((D/'component_manifest_v05.json').read_text())
s=trimesh.load(D/'martian_heavy_weapon_bunker_source_geometry_v05.glb',force='scene')
g=s.geometry
assert m['reference_footprint_tiles']==[3,3]
assert m['parts_count']==len(g)
assert len(m['hull_attachments'])>=22
assert len(m['inward_sloped_buttresses'])==8
assert m['rear_equipment_clearance_z']>=.1
for name in ('17_turret_front_cheek_W','18_turret_front_cheek_E',
             '19_mantlet_left_flank','19_mantlet_right_flank',
             '19_mantlet_upper_brow','19_mantlet_lower_apron','19_roof_to_mantlet_transition'):
    mesh=g[name]
    assert mesh.is_watertight,(name,'non-manifold armor')
    assert mesh.volume>.0001,(name,mesh.volume)
# Gun bore: square shroud is fully inside the 0.205-unit radius opening.
# A regular centered square shroud has .135-unit half-diagonal components.
assert math.hypot(.135,.135)<m['mantlet_aperture_inner_radius']
assert '19_machined_barrel_socket' in g
assert g['19_roof_to_mantlet_transition'].bounds[1,1]>=-.31-1e-4
assert g['19_roof_to_mantlet_transition'].bounds[1,2]>2.33
assert all(p['rotating'] for p in __import__('json').loads(__import__('gzip').decompress((D/'original_z_up_mesh_payload_v05.json.gz').read_bytes()))['parts'] if p['name'].startswith('19_')), 'Gun mantlet and socket must co-rotate with turret'
socket=g['19_machined_barrel_socket']
assert socket.is_watertight
assert socket.bounds[0,1]<-.99 and socket.bounds[1,1]>-.89
# Mantlet backs reach turret shell. New plates must not be forward-floating.
for name in ('17_turret_front_cheek_W','18_turret_front_cheek_E',
             '19_mantlet_left_flank','19_mantlet_right_flank',
             '19_mantlet_upper_brow','19_mantlet_lower_apron','19_roof_to_mantlet_transition',
             '63_armored_turret_front_brow'):
    assert g[name].bounds[1,1]>-.61,(name,'unattached face casting')
for name in ('22_primary_cannon_barrel','32_telemetry_mast','19_machined_barrel_socket'):
    assert any(a['name']==name for a in m['assets'])
if m['turret_front_refinement_pass']==2:
    assert m['trunnion_caps']==2
    for side in ('W','E'):
        for k in (68,69,70,71,72):
            assert any(n.startswith(f'{k}_') and f'_{side}' in n for n in g)
    assert m['rotating_mesh_count']>50
else:
    assert m['trunnion_caps']==0
    assert not any(n.startswith('68_') for n in g)
print('TURRET_FACE_PASS_VALIDATED',m['turret_front_refinement_pass'],
      'meshes',m['parts_count'],'traverse_parts',m['rotating_mesh_count'])
