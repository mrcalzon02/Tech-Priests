"""Stage and independently inspect the actual artillery GLB using family QA."""
import sys,runpy,shutil,json,hashlib,math,bpy
from pathlib import Path

candidate=Path(sys.argv[sys.argv.index('--')+1]).resolve()
root=Path(__file__).resolve().parents[2]
stage=root/'build/artillery-export-review'/candidate.name
asset=stage/'rolling-artillery';asset.mkdir(parents=True,exist_ok=True)
for suffix in ('blend','glb'):
    shutil.copy2(candidate/('rolling-artillery.'+suffix),asset/('rolling-artillery.'+suffix))
sys.argv=['inspect_bullet_turret_exports.py','--',str(stage),'rolling-artillery']
runpy.run_path(str(Path(__file__).with_name('inspect_bullet_turret_exports.py')),run_name='__main__')
report=json.loads((asset/'independent-export-inspection.json').read_text())
assert report['degenerate_triangles']==0
assert report['meshes_with_uv']==report['meshes']
delta=bpy.data.objects['MUZZLE_ARTILLERY'].matrix_world.translation-bpy.data.objects['BREECH_BORE'].matrix_world.translation
angle=math.degrees(math.atan2(delta.z,math.hypot(delta.x,delta.y)))
assert abs(angle-35)<.001,('Exported barrel elevation',angle)
report['measured_barrel_elevation_degrees']=angle
(asset/'independent-export-inspection.json').write_text(json.dumps(report,indent=2)+'\n')
assert report['glb_sha256']==hashlib.sha256((candidate/'rolling-artillery.glb').read_bytes()).hexdigest()
for p in asset.iterdir():
    if p.name.startswith('import-') or p.name=='independent-export-inspection.json':shutil.copy2(p,candidate/p.name)
print('ARTILLERY_EXPORT_PASS',report['triangles'],report['meshes_with_uv'],flush=True)
