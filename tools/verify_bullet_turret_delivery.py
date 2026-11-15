"""Audit the completed local prototype and bind its evidence to file hashes."""
import hashlib,json,zipfile
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1];B=ROOT/'build/bullet-turrets'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text())
game=B/'graphical-fixed-points/user-data/script-output/bullet-turrets'
proofs={}
for label,path in {
    'native_combat':game/'result.json','research':game/'upgrades.json',
    'physical_inserters':game/'inserters.json','native_muzzle_suppression':game/'muzzle-effects.json',
    'save_reload':B/'reload-fixed-points/user-data/script-output/bullet-turrets/continued.json',
    'older_family_regression':B/'final-regression/user-data/script-output/bunker-family/result.json',
    'actual_export_inspection':B/'candidate-v5/independent-export-inspection.json',
    'fixed_rotary_muzzles':B/'candidate-v5/twin-minigun/fixed-muzzle-repair.json',
    'sprite_cell_readback':ROOT/'docs/prototypes/bullet-turret-assets.json',
}.items():
    data=read(path);assert data['status']=='PASS',(label,path)
    proofs[label]={'path':str(path.relative_to(ROOT)),'sha256':sha(path)}
mapping=read(B/'projection-probe/user-data/script-output/mapping.json')
assert mapping['actual']==mapping['expected'] and len(mapping['actual'])==64
proofs['native_direction_mapping']={'path':'build/bullet-turrets/projection-probe/user-data/script-output/mapping.json','sha256':sha(B/'projection-probe/user-data/script-output/mapping.json'),'headings':64}
repair=read(B/'candidate-v5/twin-minigun/fixed-muzzle-repair.json')
assert repair['body_pose_before_sha256']==repair['body_pose_after_sha256']
for points in repair['shot_positions'].values():
    assert all(max(abs(a-b) for a,b in zip(points[0],point))<.00002 for point in points)
# Verify actual in-game flashes remain at the two fixed image coordinates.
centroids=[[],[]];screens=[]
for tick in (601,607,613,619,625,631):
    path=game/f'weapon-2-tick-{tick}.png';im=Image.open(path).convert('RGB')
    for bank,(left,right) in enumerate(((440,480),(506,546))):
        pixels=[(x,y) for x in range(left,right) for y in range(360,400)
                if im.getpixel((x,y))[0]>220 and im.getpixel((x,y))[1]>190 and im.getpixel((x,y))[2]>150]
        assert pixels,('Missing custom muzzle flash',bank,tick)
        centroids[bank].append([sum(p[j] for p in pixels)/len(pixels) for j in (0,1)])
    screens.append({'path':str(path.relative_to(ROOT)),'sha256':sha(path)})
for points in centroids:
    assert all(max(abs(a-b) for a,b in zip(points[0],point))<1.5 for point in points),points
archive=B/'delivery-0.3.0/tech-priests-bunker-family-prototype_0.3.0.zip'
prefix='tech-priests-bunker-family-prototype_0.3.0/'
assets=read(ROOT/'docs/prototypes/bullet-turret-assets.json')
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    assert not any('/scenarios/' in name for name in z.namelist())
    for path in ('scripts/bullet_turret_controller.lua','scripts/bunker_family_visuals.lua','prototypes/bunker_bullet_weapons.lua','prototypes/bunker_family.lua'):
        assert z.read(prefix+path)==(ROOT/'tech-priests_src'/path).read_bytes(),path
    assert z.read(prefix+'README.md')==(ROOT/'docs/prototypes/bullet-turrets-readme.md').read_bytes()
    for weapon in assets['weapons']:
        assert weapon['name'] in ('chicago-piano','twin-minigun')
        native=B/'candidate-v5'/weapon['name']/(weapon['name']+'.blend')
        assert sha(native)==weapon['capture']['identity']['source_sha256']
        for file in weapon['files']:
            relative='graphics/entity/bunker-'+weapon['name']+'/'+file['name']
            assert sha(ROOT/'tech-priests_src'/relative)==file['sha256']
            assert hashlib.sha256(z.read(prefix+relative)).hexdigest()==file['sha256']
source_archive=archive.parent/'bullet-turrets-editable-sources.zip'
with zipfile.ZipFile(source_archive,'w',zipfile.ZIP_DEFLATED,compresslevel=1) as z:
    for name in ('chicago-piano','twin-minigun'):
        for file in sorted((B/'candidate-v5'/name).iterdir()):
            if file.suffix in ('.blend','.glb','.json','.png'):z.write(file,'models/'+name+'/'+file.name)
    for file in ('build_bullet_turrets.py','capture_bullet_turrets.py','inspect_bullet_turret_exports.py','fix_twin_fixed_muzzles.py'):
        z.write(ROOT/'tools/art'/file,'tools/'+file)
    z.write(ROOT/'docs/prototypes/bullet-turrets-readme.md','README.md')
with zipfile.ZipFile(source_archive) as z:assert z.testzip() is None
review={'reviewer':'Codex, with owner visual review','owner_response':'yerp its good',
    'owner_review_scope':'Latest fixed-point rotary firing preview; earlier mechanical direction accepted with Chicago side-feed correction implemented.',
    'scores_out_of_5':{'mechanical_construction':4,'material_coherence':4,'silhouette_at_game_scale':4,'faction_identity':4,'functional_reference_match':4},
    'findings':'Stepped quad receivers and four lower side-entry belt tracks replace the rear ramps. Twin rotary drives use rounded armor, exposed bearings and drums. Native preview cores remain legible; foundations stay fixed. Two stationary minigun muzzle points are visible in actual game captures, with duplicate stock effects suppressed.',
    'sources':[{'name':name,'blend_sha256':sha(B/'candidate-v5'/name/(name+'.blend')),'glb_sha256':sha(B/'candidate-v5'/name/(name+'.glb'))} for name in ('chicago-piano','twin-minigun')]}
report={'status':'PASS','delivery':'local playable prototypes, not a published full-mod release','engine':'2.1.24',
    'prototype_archive':{'path':str(archive.relative_to(ROOT)),'bytes':archive.stat().st_size,'sha256':sha(archive)},
    'editable_sources':{'path':str(source_archive.relative_to(ROOT)),'sha256':sha(source_archive)},
    'proofs':proofs,'fixed_flash_game_centroids':centroids,'game_screenshots':screens,'art_review':review,
    'limitations':['Provisional recipes and balance.','Fractional speed research quantizes the piano recycle to 29–31 ticks, averaging 30.','Twin volleys use one doubled native damage impact, so flat armor is applied once.']}
(ROOT/'docs/prototypes/bullet-turrets-completion.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'status':'PASS','archive':str(archive),'source_archive':str(source_archive),'proofs':len(proofs)}))
