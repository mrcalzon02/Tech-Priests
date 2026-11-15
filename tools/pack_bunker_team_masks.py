"""Pack original corner-stanchion coverage as neutral runtime force masks."""
import json,hashlib
from pathlib import Path
from PIL import Image,ImageChops,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
coverage=ROOT/'build/bunker-team-colour/coverage';dest=ROOT/'tech-priests_src/graphics/entity/bunker-autocannon'
teams=[('Red',(225,55,40)),('Blue',(45,120,245)),('Green',(60,210,90)),('Gold',(245,190,45))]
board=Image.new('RGB',(1280,1400),(61,66,69));draw=ImageDraw.Draw(board);records=[]
for row,direction in enumerate(('north','east','south','west')):
    base=Image.open(dest/f'base-{direction}.png').convert('RGBA')
    shape=Image.open(coverage/f'coverage-{direction}.png').convert('RGBA').getchannel('A')
    alpha=ImageChops.multiply(shape,base.getchannel('A'))
    # Preserve the existing rough surfaces and shaded facets while raising the
    # black substrate to a neutral paint value that can receive saturated tint.
    grey=base.convert('L').point(lambda v:min(230,75+v*4))
    mask=Image.merge('RGBA',(grey,grey,grey,alpha));path=dest/f'base-{direction}-team-mask.png';mask.save(path)
    assert alpha.getbbox() and sum(alpha.histogram()[1:])>1000,'Empty/small stanchion mask'
    outside=ImageChops.multiply(alpha,ImageChops.invert(base.getchannel('A')))
    assert max(outside.getextrema())<=64,'Mask escapes base silhouette'
    for col,(name,color) in enumerate(teams):
        paint=Image.merge('RGBA',tuple(grey.point(lambda v,m=multiplier:round(v*m/255)) for multiplier in color)+(alpha,))
        preview=Image.alpha_composite(base,paint).resize((320,320),Image.Resampling.LANCZOS)
        board.paste(preview,(col*320,row*350+22),preview)
        draw.text((col*320+12,row*350+6),f'{direction}: {name}',fill='white')
    records.append({'direction':direction,'mask':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                    'source_base_sha256':hashlib.sha256((dest/f'base-{direction}.png').read_bytes()).hexdigest(),
                    'coverage_sha256':hashlib.sha256((coverage/f'coverage-{direction}.png').read_bytes()).hexdigest(),
                    'covered_pixels':sum(alpha.histogram()[1:]),'bounds':alpha.getbbox()})
out=ROOT/'build/bunker-team-colour';board.save(out/'stanchion-colour-review.png')
(ROOT/'docs/prototypes/bunker-team-colour-assets.json').write_text(json.dumps({'status':'MASKS_PACKED_RUNTIME_PENDING',
    'scope':'All six bunker weapons share the four original corner-stanchion masks. Red armour, concrete, equipment, glow and shadow are excluded.',
    'selection':json.loads((coverage/'selection.json').read_text()),'files':records},indent=2)+'\n')
print('BUNKER_STANCHION_MASKS_PACKED',len(records))
