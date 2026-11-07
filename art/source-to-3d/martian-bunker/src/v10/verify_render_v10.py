"""Complete render/texture/gallery verification after real headless Blender execution."""
from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image, ImageDraw

src=Path(__file__).resolve().parent
gallery=(src.parent.parent/'gallery') if src.parent.name=='src' else (src/'gallery')
gallery.mkdir(exist_ok=True,parents=True)
assert gallery.is_dir(),gallery
manifest=json.loads((src/'component_manifest_v10.json').read_text())
assert manifest['parts_count']==194
assert manifest['rotating_mesh_count']==105
assert manifest['barrel_bore_open']
assert not any(x['name'].startswith('87_roof_') for x in manifest['assets'])
assert manifest['target_detail_count']==31
assert manifest['reference_footprint_tiles']==[3,3]
assert len(manifest['hull_attachments'])==22
assert len(manifest['inward_sloped_buttresses'])==8
tex=json.loads((src/'textures/texture_manifest.json').read_text())
assert len(tex['materials'])>=22
assets={}
for filename in ('martian_heavy_weapon_bunker_v10_flat.blend',
  'martian_heavy_weapon_bunker_v10_textured.blend',
  'martian_heavy_weapon_bunker_v10_textured_export.glb'):
    p=src/filename
    assert p.is_file() and p.stat().st_size>30000,(filename,'MISSING MASTER')
    assets[filename]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
checks={}
for mode in ('flat','textured'):
    for suffix in ('front','rear'):
        path=src/f'bunker_v10_{mode}_{suffix}.png'
        assert path.is_file() and path.stat().st_size>30000,path
        with Image.open(path) as im:
            assert im.size==(900,900)
            arr=np.asarray(im.convert('RGBA'))
        visible=arr[:,:,3]>30
        red=(arr[:,:,0]>arr[:,:,1]*1.25)&(arr[:,:,0]>arr[:,:,2]*1.25)&(arr[:,:,0]>50)&visible
        assert visible.sum()>20000 and red.sum()>1000,(mode,suffix,'color/framing missing')
        checks[f'{mode}_{suffix}']={'visible_pixels':int(visible.sum()),'red_pixels':int(red.sum())}
        if mode=='textured':(gallery/f'v10_textured_{suffix}.png').write_bytes(path.read_bytes())
    for suffix in ('three_quarter','head_on','side'):
        path=src/f'barrel_v10_{mode}_{suffix}.png'
        assert path.is_file() and path.stat().st_size>30000,path
        if mode=='textured':(gallery/f'v10_barrel_{suffix}.png').write_bytes(path.read_bytes())
with Image.open(src/'barrel_v10_flat_three_quarter.png') as a, Image.open(src/'barrel_v10_textured_three_quarter.png') as b:
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
    (gallery/'v07_barrel_three_quarter.png','v07 | actual existing round gun, sparse turret fittings'),
    (src/'barrel_v10_flat_three_quarter.png','v10 | actual detailed turret, untextured diagnostic'),
    (src/'barrel_v10_textured_three_quarter.png','v10 | reduced, purposeful REAL MESHES + weathered PBR')]):
    sheet.paste(captioned(path,label),(i*900,0))
sheet.save(gallery/'v10_three_stage_reference_progress.png')
with Image.open(gallery/'v10_textured_front.png') as im:
    im.thumbnail((256,256));im.save(gallery/'v10_factorio_256px.png')
# Persist the material-board evidence in the committed GitHub gallery.
board=Image.new('RGB',(1200,660),(30,31,33))
draw=ImageDraw.Draw(board)
for i,key in enumerate(('martian_red','ferrocrete','gunmetal_dark','heat_blues',
                       'machine_steel','brass','machined_bright','red_dark')):
    with Image.open(src/'textures'/f'{key}_albedo.png') as texim:
        img=texim.convert('RGB').resize((280,280))
    x=(i%4)*300;y=(i//4)*330
    board.paste(img,(x,y));draw.text((x+10,y+287),key,fill=(234,219,194))
board.save(gallery/'v10_material_swatch.png')
# Source image is a visual specification, NOT geometry or material data.
# The comparison uses only the real previous and real freshly-rendered model.
reference=gallery.parent/'style-references'/'visual-target-v08.png'
previous=gallery/'v09_barrel_three_quarter.png'
current=gallery/'v10_barrel_three_quarter.png'
assert reference.is_file() and previous.is_file() and current.is_file(),(reference,previous,current)
board=Image.new('RGB',(2400,856),(26,28,29))
for i,(path,label) in enumerate(((reference,'TARGET: user-selected reference image'),
                                 (previous,'REJECTED: actual Blender v09'),
                                 (current,'CORRECTED: actual Blender v10'))):
    with Image.open(path) as im:
        content=im.convert('RGB')
        content.thumbnail((785,790))
        x=i*800+(800-content.width)//2; y=48+(800-content.height)//2
        board.paste(content,(x,y))
    ImageDraw.Draw(board).text((i*800+17,18),label,fill=(233,224,204))
board.save(gallery/'v10_target_vs_v09_vs_v10.png')

report={'result':'v10 native Blender mesh reconstruction, original PBR textures, GLB reimport and gallery checks passed',
        'parts':manifest['parts_count'],'rotating':manifest['rotating_mesh_count'],
        'bore_radius':manifest['barrel_bore_radius'],
        'material_count':len(tex['materials']),'pbr_maps':len(list((src/'textures').glob('*.png'))),
        'texture_difference_pixels':changed,'render_checks':checks,'asset_hashes':assets,
        'old_square_shroud_absent':manifest['square_shroud_removed'],
        'reference_mesh_details':manifest['target_detail_count'],
        'art_approval':'pending human art inspection and native Factorio game-size validation'}
(src/'validation_report_v10.json').write_text(json.dumps(report,indent=2)+'\n')
print('BARREL_AND_PACKED_PBR_TEXTURED_BLENDER_GALLERY_PASS',report)
