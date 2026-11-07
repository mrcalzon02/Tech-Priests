"""v0.9: true cylinder/attachment/texture regression, independent from render.

This explicitly fails if the old cuboid barrel shroud returns. It checks actual
unmodified source mesh vertices and ring cross sections, not just a manifest.
"""
from pathlib import Path
import json, gzip
import numpy as np
import trimesh
from PIL import Image
D=Path(__file__).resolve().parent
m=json.loads((D/'component_manifest_v10.json').read_text())
s=trimesh.load(D/'martian_heavy_weapon_bunker_source_geometry_v10.glb',force='scene')
g=s.geometry
assert m['parts_count']==len(g) and 185<=len(g)<220, (m['parts_count'],len(g))
assert 90 <= m['rotating_mesh_count'] < 160
assert m['square_shroud_removed'] and '21_gun_tube_outer_shroud' not in g
assert m['reference_footprint_tiles']==[3,3]
assert len(m['hull_attachments'])==22 and len(m['inward_sloped_buttresses'])==8
assert m['rear_equipment_clearance_z']>=.10
assert m['barrel_bore_open'] and .045<=m['barrel_bore_radius']<=.05
jacket=g['21_cylindrical_gun_jacket']
assert jacket.is_watertight and jacket.volume>0
assert len(jacket.vertices)>= 48*2, len(jacket.vertices)
# All jacket radial sections must be round and coaxial at world Z=2.02.
# A boxy shroud would have just four corners and grossly variable radii.
y_levels=np.unique(np.round(jacket.vertices[:,1],4))
assert len(y_levels)>=7, y_levels
for y in y_levels:
    v=jacket.vertices[np.isclose(jacket.vertices[:,1],y,atol=.0001)]
    r=np.hypot(v[:,0],v[:,2]-2.02)
    # The local outer + inner walls are two circles, not squared profiles.
    outer=r[r>np.median(r)]
    assert len(outer)>=24 and np.std(outer)<.0008,(y,outer.min(),outer.max(),np.std(outer))
assert jacket.bounds[0,1]<-1.53 and jacket.bounds[1,1]>-.91
for n in ('22_primary_cannon_barrel','23_muzzle_reinforcement','77_visible_rifled_liner'):
    x=g[n]
    assert x.is_watertight and x.volume>1e-6,(n,'not watertight',x.volume)
    r=np.hypot(x.vertices[:,0],x.vertices[:,2]-2.02)
    assert float(r.min())>=.046,(n,'bore plugged',r.min())
assert abs(float(g['23_muzzle_reinforcement'].bounds[0,1])+2.025)<.002
assert np.max(np.hypot(g['23_muzzle_reinforcement'].vertices[:,0],g['23_muzzle_reinforcement'].vertices[:,2]-2.02)) <= .111, 'Forbidden oversized muzzle knob'

assert g['22_primary_cannon_barrel'].bounds[1,1]>-1.08
for n in ('21_jacket_socket_locking_flange','78_barrel_service_clamp_3',
          '73_barrel_shroud_front_collar','74_barrel_heat_shield_joint'):
    assert n in g,n
assert '21_jacket_mid_service_collar' not in g

body=json.loads(gzip.decompress((D/'original_z_up_mesh_payload_v10.json.gz').read_bytes()))
rot=[p for p in body['parts'] if p['name'].startswith(('21_','22_','23_','77_','78_','79_','80_'))]
assert all(p['rotating'] for p in rot),[p['name'] for p in rot if not p['rotating']]
assert body['axes']=='+Z up, -Y gun forward, +X right'
tex=json.loads((D/'textures/texture_manifest.json').read_text())
assert set(tex['materials'])==set(body['materials'])
assert tex['dimension']==[512,512],tex['dimension']
for key,val in tex['materials'].items():
    for name,path in val['texture_files'].items():
        p=D/path
        assert p.is_file() and p.stat().st_size>1024,(key,name)
        with Image.open(p) as image:
            assert image.size==(512,512) and image.mode=='RGB',(key,name,image.mode)
            if name=='albedo':
                data=np.asarray(image)
                assert float(data.std())>1.5,(key,'flat fake texture')
print('V10_ROUND_JACKET_AND_CONNECTED_HOLLOW_GUN_AND_512PX_WEATHERED_PBR_PASS',len(g),len(rot),len(tex['materials']))
