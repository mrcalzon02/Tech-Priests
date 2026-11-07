"""Strict model-to-reference correction regression. No newly invented geometry.

This compares v1.0 against the last committed v0.9 GLB for EXACT geometry
identity of all untouched parts, not merely mesh count. It also verifies the
user-rejected muzzle knob and bolt-on roof slab are absent.
"""
from pathlib import Path
import json
import numpy as np
import trimesh
D = Path(__file__).resolve().parent
manifest=json.loads((D/'component_manifest_v10.json').read_text())
candidates=[D.parent/'v09'/'martian_heavy_weapon_bunker_source_geometry_v09.glb',
            Path('/mnt/data/bunker_v09_cleanup/martian_heavy_weapon_bunker_source_geometry_v09.glb')]
oldfile=next((p for p in candidates if p.is_file()),None)
assert oldfile, ('Missing last-approved geometry for strict comparison',candidates)
old=trimesh.load(oldfile,force='scene').geometry
new=trimesh.load(D/'martian_heavy_weapon_bunker_source_geometry_v10.glb',force='scene').geometry
removed=set(old)-set(new)
roof={n for n in old if n.startswith('87_roof_')}
assert removed==roof and len(removed)==5,(sorted(removed),sorted(roof))
assert not(set(new)-set(old)), 'New decorative hardware is forbidden'
changed=[]
for name in sorted(set(old)&set(new)):
    a,b=old[name],new[name]
    same=(a.vertices.shape==b.vertices.shape and a.faces.shape==b.faces.shape
          and np.allclose(a.vertices,b.vertices,atol=1e-7)
          and np.array_equal(a.faces,b.faces))
    if not same: changed.append(name)
assert changed==['23_muzzle_reinforcement'], ('Accidental geometry edits',changed)
assert len(old)==199 and len(new)==194 and manifest['parts_count']==194
assert manifest['rotating_mesh_count']==105
new_muzzle=new['23_muzzle_reinforcement']
radii=np.hypot(new_muzzle.vertices[:,0],new_muzzle.vertices[:,2]-2.02)
old_muzzle=old['23_muzzle_reinforcement']
old_r=np.hypot(old_muzzle.vertices[:,0],old_muzzle.vertices[:,2]-2.02)
assert old_r.max()>.155 and radii.max()<=.111,(old_r.max(),radii.max())
assert radii.min()>=.059, 'Central bore blocked'
assert new_muzzle.is_watertight and new_muzzle.volume>0
assert len(manifest['hull_attachments'])==22 and len(manifest['inward_sloped_buttresses'])==8
print('REFERENCE_GEOMETRY_1_TO_1_PASS',{'unchanged_parts':len(set(new))-1,
      'deleted':sorted(removed),'reshaped':changed,'old_muzzle_radius':float(old_r.max()),
      'new_muzzle_radius':float(radii.max()), 'no_new_parts':True})
