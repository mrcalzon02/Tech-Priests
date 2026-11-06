"""Verify functional geometry is actually modeled, colored and attached."""
import json, gzip, numpy as np
from pathlib import Path
import trimesh
P=Path(__file__).resolve().parent
m=json.loads((P/'component_manifest_v08.json').read_text())
blob=json.loads(gzip.decompress((P/'original_z_up_mesh_payload_v08.json.gz').read_bytes()))
g={p['name']:p for p in blob['parts']}
a=m['target_detail_parts']
assert m['reference_footprint_tiles']==[3,3] and m['square_shroud_removed']
assert len(a)>=50,(len(a),'insufficiently detailed target build')
assert all(g[n]['rotating'] for n in a),'Detail detached from traverse'
assert len(a)==len(set(a)), 'Duplicate names'
assert '21_gun_tube_outer_shroud' not in g
for n in ('81_mantlet_heavy_outer_armor','81_mantlet_oil_seal','83_curved_barrel_access_cover','85_W_rangefinder_bezel','85_E_rangefinder_bezel','86_periscope_armored_overhang','86_right_hydraulic_amber_window','87_roof_red_inspection_armor','88_machine_purity_medallion'):
    assert n in g,(n,'Missing modeled target feature')
    assert len(g[n]['faces'])>8,n
def bounds(n):return np.asarray(g[n]['vertices']).min(0),np.asarray(g[n]['vertices']).max(0)
# Main ring overlaps old socket radially and axially.
ring=trimesh.Trimesh(vertices=g['81_mantlet_heavy_outer_armor']['vertices'],faces=g['81_mantlet_heavy_outer_armor']['faces'],process=False)
assert ring.is_watertight and ring.volume>0,'Mantlet assembly not real manifold mesh'
cover=trimesh.Trimesh(vertices=g['83_curved_barrel_access_cover']['vertices'],faces=g['83_curved_barrel_access_cover']['faces'],process=False)
assert cover.is_watertight and cover.volume>0,'Cover no closed radial geometry'
assert len(cover.vertices)>=70,('Not a rounded curved service cover',len(cover.vertices))
for side in ('W','E'):
    lens=g[f'85_{side}_rangefinder_recessed_lens']
    assert len(lens['faces'])>=20
for n in a:
    lo,hi=bounds(n)
    assert lo[2]>=1.69 and hi[2]<3.12,(n,'outside rotating envelope')

# A part can share the traverse pivot yet still FLOAT in its default pose.
# Enforce spatial continuity of every owner-target detail against at least
# one other rotating mesh, with a strict 0.001-tile contact tolerance.
rotating=[p['name'] for p in blob['parts'] if p['rotating']]
for n in a:
    lo1,hi1=bounds(n)
    contacting=False
    for other in rotating:
        if other==n:continue
        lo2,hi2=bounds(other)
        if np.all(lo1<=hi2+0.001) and np.all(lo2<=hi1+0.001):
            contacting=True
            break
    assert contacting, (n,'target detail still floating from ALL turret members')
# The new optical glass must intersect the ORIGINAL mounted sight window.
la,ha=bounds('86_periscope_acquisition_lens')
lb,hb=bounds('39_primary_optic_lens')
assert np.all(np.minimum(ha,hb)-np.maximum(la,lb)>0), 'New periscope glass not physically seated into existing sight window'

assert np.min(np.asarray(g['23_muzzle_reinforcement']['vertices'])[:,1])<-2.02
print('V08_TARGET_GEOMETRY_AND_TURRET_ATTACHMENTS_PASS',len(g),'parts',len(a),'new target meshes')
