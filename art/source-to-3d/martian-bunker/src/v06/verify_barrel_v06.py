"""Release-blocking source geometry invariants for barrel and original material textures.
A passing geometrical check does not replace human examination of rendered art.
"""
from pathlib import Path
import json, gzip, hashlib
import numpy as np, trimesh
from PIL import Image
D=Path(__file__).resolve().parent
m=json.loads((D/'component_manifest_v06.json').read_text())
s=trimesh.load(D/'martian_heavy_weapon_bunker_source_geometry_v06.glb',force='scene')
g=s.geometry
assert m['parts_count']==len(g)==162
assert m['rotating_mesh_count']>=70
assert m['reference_footprint_tiles']==[3,3]
assert len(m['hull_attachments'])==22
assert len(m['inward_sloped_buttresses'])==8
assert m['rear_equipment_clearance_z']>=.10
assert m['barrel_bore_open'] and .045<=m['barrel_bore_radius']<=.05
for n in ('22_primary_cannon_barrel','23_muzzle_reinforcement','77_visible_rifled_liner'):
    x=g[n]
    assert x.is_watertight and x.volume>1e-6,(n,'not watertight',x.volume)
    # All rings maintain a genuinely clear central 0.045-unit radius.
    r=np.hypot(x.vertices[:,0],x.vertices[:,2]-2.02)
    assert float(r.min())>=.046,(n,'bore plugged',r.min())
    assert abs(float(np.mean(x.vertices[:,0])))<.001
assert abs(float(g['23_muzzle_reinforcement'].bounds[0,1])+2.025)<.002
assert g['22_primary_cannon_barrel'].bounds[1,1] > -1.08
for n in ('78_barrel_service_clamp_1','78_barrel_service_clamp_2','78_barrel_service_clamp_3',
          '79_muzzle_radial_crown_rib_top','80_barrel_shroud_side_heatbar_E'):
    assert n in g,n
body=json.loads(gzip.decompress((D/'original_z_up_mesh_payload_v06.json.gz').read_bytes()))
rot=[p for p in body['parts'] if p['name'].startswith(('22_','23_','77_','78_','79_','80_'))]
assert all(p['rotating'] for p in rot),[p['name'] for p in rot if not p['rotating']]
assert body['axes']=='+Z up, -Y gun forward, +X right'
tex=json.loads((D/'textures/texture_manifest.json').read_text())
assert set(tex['materials'])==set(body['materials'])
for key,val in tex['materials'].items():
    for name,path in val['texture_files'].items():
        p=D/path
        assert p.is_file() and p.stat().st_size>1024,(key,name)
        with Image.open(p) as image:
            assert image.size==(384,384) and image.mode=='RGB',(key,name,image.mode)
            if name=='albedo':
                data=np.asarray(image)
                assert float(data.std())>1.5,(key,'flat fake texture')
print('BARREL_OPEN_BORE_RECOIL_COLLARS_AND_ORIGINAL_TEXTURE_ASSETS_PASS',len(rot),len(tex['materials']))
