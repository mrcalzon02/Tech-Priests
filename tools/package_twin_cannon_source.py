"""Archive the reopened editable model, inspection export and rebuild sources."""
import json,hashlib,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];out=ROOT/'build/twin-cannon/delivery-0.4.0';model=ROOT/'build/twin-cannon/flexible-aerials-v3/twin-cannon'
check=json.loads((out/'portable-source-check.json').read_text());assert check['status']=='PASS'
assert check['native_sha256']==hashlib.sha256((model/'twin-cannon.blend').read_bytes()).hexdigest()
files={
    'twin-cannon.blend':model/'twin-cannon.blend','twin-cannon.glb':model/'twin-cannon.glb',
    'inputs/energy_dish_v04.blend':ROOT/'build/bunker-family/dish-v04/energy_dish_v04.blend',
    'portable-source-check.json':out/'portable-source-check.json',
    'structure-and-motion-check.json':model/'structure-and-motion-check.json',
    'aerial-geometry-check.json':model/'aerial-geometry-check.json',
    'backlog.md':ROOT/'docs/prototypes/bunker-weapon-backlog.md'}
for path in (ROOT/'tools/art').glob('twin_cannon_*.py'):files['tools/art/'+path.name]=path
for name in ('build_twin_cannon.py','build_bullet_turrets.py','capture_twin_cannon.py','capture_twin_cannon_aerials.py',
             'capture_twin_cannon_shadows.py','capture_bullet_turrets.py','render_twin_cannon_motion_review.py',
             'verify_twin_cannon_aerials.py','verify_twin_cannon_structure.py','verify_twin_cannon_portable_source.py'):
    files['tools/art/'+name]=ROOT/'tools/art'/name
manifest={'status':'EDITABLE_SOURCE_VERIFIED','native_sha256':check['native_sha256'],
          'files':{name:hashlib.sha256(path.read_bytes()).hexdigest() for name,path in files.items()}}
readme='''# Twin siege cannon editable source 0.4.0

Open twin-cannon.blend in Blender 5.0.1 or a compatible newer version. Used
textures are packed. Frame 1 is the opening pose, frames 1–226 demonstrate
alternating recoil and settling, and later frames demonstrate traverse-driven
aerial flex. The concrete bunker is intentionally separate from the weapon.
The GLB is the independently inspected static geometry export.

The Blender authoring helpers and packed studio/material input are included.
To rebuild, run build_twin_cannon.py in Blender background mode with two
absolute paths after --: inputs/energy_dish_v04.blend and an output directory.
Use absolute paths because opening a Blender scene can change its directory.
The portable-source and geometry checks bind to the included model by SHA-256.

Runtime uses actual cannon-shell items, original native projectiles and the
native Factorio gunshot artwork. Review rendering needs a local Factorio
installation; those native effect images are not redistributed here. The
playable mod is the separate tech-priests-bunker-family-prototype_0.4.0.zip.
Only the cannon is finalized here; six further weapon families remain listed
in backlog.md. Experimental balance remains provisional.
'''
archive=out/'twin-siege-cannon-editable-source_0.4.0.zip';prefix='twin-siege-cannon-source/'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=3) as z:
    for name,path in files.items():z.write(path,prefix+name)
    z.writestr(prefix+'README.md',readme);z.writestr(prefix+'manifest.json',json.dumps(manifest,indent=2)+'\n')
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for name,digest in manifest['files'].items():assert hashlib.sha256(z.read(prefix+name)).hexdigest()==digest,name
(out/'editable-source.json').write_text(json.dumps({'status':'PASS','archive':str(archive.relative_to(ROOT)),
    'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'bytes':archive.stat().st_size,'manifest':manifest},indent=2)+'\n')
print('EDITABLE_CANNON_SOURCE_PASS',archive.stat().st_size)
