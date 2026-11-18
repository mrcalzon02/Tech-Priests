"""Anatomical UV aging for fitted plates and distinct enamel cog finish."""
from pathlib import Path
from PIL import Image,ImageFilter
import random,math,json
R=Path(__file__).resolve().parents[3];O=R/'art/source-to-3d/conclave-center/v08-martian-central-emblem';T=O/'textures';T.mkdir(exist_ok=True)
ao=Image.open(O.parent/'v07-aged-and-ambient/textures/skull-original-uv-cavity-ao.png').convert('L');a=ao.load();w,h=ao.size;rng=random.Random(8031)
for role,base,metal in [('oxide',(63,72,68),210),('steel',(107,118,109),225),('enamel',(164,143,102),25)]:
 im=Image.new('RGB',(w,h));orm=Image.new('RGB',(w,h));normal=Image.new('RGB',(w,h),(128,128,255));p=im.load();q=orm.load()
 for y in range(h):
  for x in range(w):
   cavity=1-a[x,y]/255 if role!='enamel' else 0;grain=rng.uniform(-4,4);age=.20*cavity+.025*math.sin(x*.035)*math.sin(y*.017)
   p[x,y]=tuple(max(0,min(255,int(c*(1-age)+grain))) for c in base);q[x,y]=(a[x,y] if role!='enamel' else 255,int(154+58*cavity+grain),metal)
 im.save(T/(role+'-albedo.png'));orm.save(T/(role+'-orm.png'));normal.save(T/(role+'-normal.png'))
(O/'emblem-surface-plan.json').write_text(json.dumps(dict(oxide='Dry black oxide cranial/jaw shell with original-UV cavity accumulation and local porous roughness.',steel='Contrasting aged orbital steel, cavity-driven staining; true fitted panel gaps and dressed edges supply relief.',enamel='Warm worn enamel on left cog half; dark oxide on opposite half. Cog is real thick toothed geometry.',normal='Flat tangent map for new cast plates: do not apply bone sculpt detail to mechanical armor.'),indent=2))
print('V08_EMBLEM_MAPS_READY')
