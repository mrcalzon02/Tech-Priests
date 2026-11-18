"""Original-UV cavity staining, warm bone, dry porous roughness."""
from pathlib import Path
from PIL import Image,ImageFilter
import math,random,json
R=Path(__file__).resolve().parents[3];T=R/'art/source-to-3d/conclave-center/v07-aged-and-ambient/textures'
ao=Image.open(T/'skull-original-uv-cavity-ao.png').convert('L');w,h=ao.size;pix=ao.load();rng=random.Random(7183)
stain=Image.new('L',(64,64));stain.putdata([rng.randrange(256) for _ in range(4096)]);stain=stain.resize((w,h),Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(12));sp=stain.load();color=Image.new('RGB',(w,h));orm=Image.new('RGB',(w,h));cp=color.load();op=orm.load()
for y in range(h):
 for x in range(w):
  cavity=(1-pix[x,y]/255)**.7;age=sp[x,y]/255;grain=rng.uniform(-3,3);dirt=min(.88,cavity*.78+max(0,age-.4)*.2)
  # Bone ochre on raised anatomy, brown contact soil in true eye/nose/jaw folds.
  cp[x,y]=tuple(int(a*(1-dirt)+b*dirt+grain) for a,b in zip((164,140,100),(42,29,17)))
  op[x,y]=(pix[x,y],int(188+min(55,46*cavity+12*age)),0)
color.save(T/'aged-original-skull-albedo.png');orm.save(T/'aged-original-skull-orm.png')
# Feathered smoke strip: density concentrated on the wisp center, never a hard card edge.
smoke=Image.new('RGBA',(128,256));p=smoke.load()
for y in range(256):
 for x in range(128):
  u=(x-63.5)/63.5;v=y/255;edge=max(0,1-u*u)**2;fade=math.sin(math.pi*v)**1.3
  p[x,y]=(115,111,100,int(62*edge*fade*(.8+.2*math.sin(v*21+u*6))))
smoke.save(T/'candle-smoke-feather.png')
(T.parent/'surface-plan.json').write_text(json.dumps(dict(skull='Original supplied UV; actual isolated cavity bake drives brown recess staining and porous roughness. Warm worn ivory on raised bone; original sculpt normal retained.',metal='Existing panel-specific wear retained; dull brass and cast surfaces aged without changing construction or interface geometry.',smoke='Feathered low opacity wisps above each burning wick; no opaque puff spheres.'),indent=2))
print('V07_BONE_AND_SMOKE_TEXTURES_READY')
