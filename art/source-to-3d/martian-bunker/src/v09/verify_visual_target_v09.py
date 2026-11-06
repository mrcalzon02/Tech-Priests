"""Regression: v0.9 subtracts redundant trim and retains functional interfaces."""
import json,gzip, numpy as np
from pathlib import Path
import trimesh
P=Path(__file__).resolve().parent
m=json.loads((P/'component_manifest_v09.json').read_text())
b=json.loads(gzip.decompress((P/'original_z_up_mesh_payload_v09.json.gz').read_bytes()))
g={q['name']:q for q in b['parts']}
a=m['target_detail_parts']
assert m['reference_footprint_tiles']==[3,3] and m['square_shroud_removed']
assert 20 <= len(a) <= 45, (len(a),'v0.9 is intended to be subtractive')
assert m['parts_count'] < 215 and m['parts_count'] > 180,m['parts_count']
assert m['rotating_mesh_count'] < 160
assert all(g[n]['rotating'] for n in a),'A detail is not parented to turret rotation'
assert len(a)==len(set(a))
assert '21_gun_tube_outer_shroud' not in g
for n in ('81_mantlet_heavy_outer_armor','83_curved_barrel_access_cover',
          '85_W_rangefinder_socket','85_E_rangefinder_socket',
          '86_periscope_acquisition_lens','86_right_hydraulic_amber_window',
          '87_roof_red_inspection_armor','21_cylindrical_gun_jacket'):
    assert n in g,(n,'actual functional part missing')
# Stop re-introducing donut stacking, redundant fake branding and hand-placed chips.
for q in g:
    assert not q.startswith(('84_lathe_service_band','88_purity','88_machine_purity',
          '89_serial','89_recoil','90_cheek_impact','79_muzzle_radial','80_barrel_shroud')),(q,'redundant model detail')
assert not any(q.startswith('85_') and 'bezel' in q for q in g)
for n in ('81_mantlet_heavy_outer_armor','83_curved_barrel_access_cover'):
    part=g[n]; mesh=trimesh.Trimesh(vertices=part['vertices'],faces=part['faces'],process=False)
    assert mesh.is_watertight and mesh.volume>0,(n,'not physical machined part')
for n in a:
    v=np.asarray(g[n]['vertices'])
    assert v[:,2].min()>=1.69 and v[:,2].max()<3.12,n
print('SUBTRACTIVE_TURRET_DETAIL_REGRESSION_PASSED',m['parts_count'],'parts',len(a),'new target meshes')
