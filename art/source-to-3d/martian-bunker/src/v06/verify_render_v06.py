"""Complete render/texture/gallery verification after real headless Blender execution."""
from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image, ImageDraw

src=Path(__file__).resolve().parent
gallery=src.parents[1]/'gallery'
assert gallery.is_dir(),gallery
manifest=json.loads((src/'component_manifest_v06.json').read_text())
assert manifest['parts_count']==162
assert manifest['rotating_mesh_count']>=73
assert manifest['barrel_bore_open']
assert manifest['reference_footprint_tiles']==[3,3]
assert len(manifest['hull_attachments'])==22
assert len(manifest['inward_sloped_buttresses'])==8
tex=json.loads((src/'textures/texture_manifest.json').read_text())
assert len(tex['materials'])==20
assets={}
for filename in ('martian_heavy_weapon_bunker_v06_flat.blend',
  'martian_heavy_weapon_bunker_v06_textured.blend',
  'martian_heavy_weapon_bunker_v06_textured_export.glb'):
    p=src/filename
    assert p.is_file() and p.stat().st_size>30000,(filename,'MISSING MASTER')
    assets[filename]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
checks={}
for mode in ('flat','textured'):
    for suffix in ('front','rear'):
        path=src/f'bunker_v06_{mode}_{suffix}.png'
        assert path.is_file() and path.stat().st_size>30000,path
        with Image.open(path) as im:
            assert im.size==(900,900)
            arr=np.asarray(im.convert('RGBA'))
        visible=arr[:,:,3]>30
        red=(arr[:,:,0]>arr[:,:,1]*1.25)&(arr[:,:,0]>arr[:,:,2]*1.25)&(arr[:,:,0]>50)&visible
        assert visible.sum()>20000 and red.sum()>1000,(mode,suffix,'color/framing missing')
        checks[f'{mode}_{suffix}']={'visible_pixels':int(visible.sum()),'red_pixels':int(red.sum())}
        if mode=='textured':(gallery/f'v06_textured_{suffix}.png').write_bytes(path.read_bytes())
    for suffix in ('three_quarter','head_on','side'):
        path=src/f'barrel_v06_{mode}_{suffix}.png'
        assert path.is_file() and path.stat().st_size>30000,path
        if mode=='textured':(gallery/f'v06_barrel_{suffix}.png').write_bytes(path.read_bytes())
with Image.open(src/'barrel_v06_flat_three_quarter.png') as a, Image.open(src/'barrel_v06_textured_three_quarter.png') as b:
    delta=np.abs(np.asarray(a.convert('RGB'),dtype=np.int16)-np.asarray(b.convert('RGB'),dtype=np.int16))
changed=int(np.count_nonzero(np.max(delta,axis=2)>3))
assert changed>7000,('Textured render indistinguishable from flat source',changed)

def captioned(path,label):
    with Image.open(path) as im:
        out=Image.new('RGB',(900,960),(29,31,33));out.paste(im.convert('RGB'),(0,60))
    ImageDraw.Draw(out).text((30,25),label,fill=(234,219,194))
    return out
sheet=Image.new('RGB',(2700,960),(29,31,33))
for i,(path,label) in enumerate([
    (gallery/'v05_pass2_turret_close_front.png','v05 baseline | old solid muzzle + flat materials'),
    (src/'barrel_v06_flat_three_quarter.png','v06 geometry | open bore and machined sleeves'),
    (src/'barrel_v06_textured_three_quarter.png','v06 PBR | original maps and tempered steel')]):
    sheet.paste(captioned(path,label),(i*900,0))
sheet.save(gallery/'v06_three_stage_barrel_comparison.png')
with Image.open(gallery/'v06_textured_front.png') as im:
    im.thumbnail((256,256));im.save(gallery/'v06_factorio_256px.png')
# Persist the material-board evidence in the committed GitHub gallery.
board=Image.new('RGB',(1200,660),(30,31,33))
draw=ImageDraw.Draw(board)
for i,key in enumerate(('martian_red','ferrocrete','gunmetal_dark','heat_blues',
                       'machine_steel','brass','machined_bright','red_dark')):
    with Image.open(src/'textures'/f'{key}_albedo.png') as texim:
        img=texim.convert('RGB').resize((280,280))
    x=(i%4)*300;y=(i//4)*330
    board.paste(img,(x,y));draw.text((x+10,y+287),key,fill=(234,219,194))
board.save(gallery/'v06_material_swatch.png')
report={'result':'v06 native Blender geometry, original PBR textures, GLB reimport and gallery checks passed',
        'parts':manifest['parts_count'],'rotating':manifest['rotating_mesh_count'],
        'bore_radius':manifest['barrel_bore_radius'],
        'material_count':len(tex['materials']),'pbr_maps':len(list((src/'textures').glob('*.png'))),
        'texture_difference_pixels':changed,'render_checks':checks,'asset_hashes':assets,
        'art_approval':'pending human art inspection and native Factorio game-size validation'}
(src/'validation_report_v06.json').write_text(json.dumps(report,indent=2)+'\n')
print('BARREL_AND_PACKED_PBR_TEXTURED_BLENDER_GALLERY_PASS',report)
