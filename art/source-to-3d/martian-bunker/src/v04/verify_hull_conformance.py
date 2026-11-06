"""Independent structural checks of v0.4 bunker generated source files.

A passing Blender render is NOT evidence of contact: prove end-point geometry
for every conformed panel and tapered load-bearing corner before rendering.
"""
from pathlib import Path
import gzip
import json
import numpy as np
ROOT=Path(__file__).resolve().parent
m=json.loads((ROOT/'component_manifest_v04.json').read_text())
p=json.loads(gzip.decompress((ROOT/'original_z_up_mesh_payload_v04.json.gz').read_bytes()))
g={x['name']:x for x in p['parts']}
assert len(g)==m['parts_count']==131
assert m['reference_footprint_tiles']==[3,3]
assert m['rotating_mesh_count']==42
assert len(m['hull_attachments'])>=20
assert len(m['inward_sloped_buttresses'])==8

def half(z,ax):
    return (1.375 if ax==0 else 1.355)-.16*(z-.38)/.93

for a in m['hull_attachments']:
    assert a['name'] in g
    pts=np.asarray(g[a['name']]['vertices'])
    assert not g[a['name']]['rotating'],a['name']
    if a['contact_type'] in ('shell','face-mounted equipment'):
        ax=0 if a['face'] in ('E','W') else 1
        sign=1 if a['face'] in ('E','N') else -1
        # True plane projection with zero back-face-to-wall gap for shell mounts;
        # service-mounted secondary plates must penetrate their parent backing.
        for z in (a['z_bottom'],a['z_top']):
            slab=pts[np.abs(pts[:,2]-z)<1e-6]
            assert len(slab)>=4,(a['name'],z)
            inside=np.min(slab[:,ax]*sign)
            outside=np.max(slab[:,ax]*sign)
            wall=half(z,ax)
            expected_inside=wall+a['stand_off']-a['penetration']
            assert abs(inside-expected_inside)<1e-5,(a['name'],inside,expected_inside)
            assert outside>wall+a['stand_off']+.01,(a['name'],outside,wall)
        assert abs(a['surface_slope']+.172043)<.0001,a
    else:
        assert a['contact_type']=='strut'

for a in m['inward_sloped_buttresses']:
    pts=np.asarray(g[a['name']]['vertices'])
    assert len(pts)==16,a['name']
    bottom=pts[:8];top=pts[8:]
    assert np.allclose(bottom[:,2],a['lower_z']) and np.allclose(top[:,2],a['upper_z'])
    assert not g[a['name']]['rotating']
    if a['name'].startswith('06_'):
        for axis in (0,1):
            # Every top corner shifts inward, both axes. Compare centroids and
            # each outer boundary independently; not just nominal center values.
            assert np.mean(abs(top[:,axis]))+.09 < np.mean(abs(bottom[:,axis])),a['name']
            assert np.max(abs(top[:,axis]))+.13 < np.max(abs(bottom[:,axis])),a['name']
        assert a['upper_z']>=1.3

assert p['axes']=='+Z up, -Y gun forward, +X right'
assert all(x['name'] in g for x in m['assets'])
print('BUNKER_V04_HULL_ATTACHMENT_PROOF_PASSED',len(m['hull_attachments']),
      'surface and structural mounts /',len(m['inward_sloped_buttresses']),
      'beveled buttress bodies /',len(g),'named meshes')
