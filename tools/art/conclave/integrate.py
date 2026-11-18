"""Only Conclave picture/icon changes; retain exact gameplay definition."""
import json,hashlib,shutil,sys
from pathlib import Path
from PIL import Image,ImageDraw
R=Path(__file__).resolve().parents[3];O=Path(sys.argv[sys.argv.index('--asset')+1]).resolve() if '--asset' in sys.argv else R/'art/source-to-3d/conclave-center/v01';C=O/'captures';G=R/'tech-priests_src/graphics/entity'/('conclave-center-v02' if O.name.startswith('v02') else 'conclave-center-v01');G.mkdir(parents=True,exist_ok=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert json.loads((O/'inspection.json').read_text())['passed']
files=[]
for i in range(4):
 for kind in ['body','shadow']:
  p=C/f'{kind}-d{i}.png';im=Image.open(p).convert('RGBA');assert im.size==(512,512)
  if kind=='shadow':
   # Remove Cycles shadow-catcher's <=8/255 background noise; keep real cast shadow.
   alpha=im.getchannel('A').point(lambda a:0 if a<=8 else a);im.putalpha(alpha)
  assert im.getchannel('A').getbbox() and im.getchannel('A').getextrema()[0]==0
  # Keep full source canvas. Native scale derives from measured 3.15-tile camera.
  if i==0:
   target=G/(kind+'.png');im.save(target);files.append(target)
shutil.copy2(C/'icon.png',G/'icon.png');files.append(G/'icon.png')
P=R/'tech-priests_src/prototypes/conclave_center_0558.lua';original=(O/'original-prototype.lua').read_text() if (O/'original-prototype.lua').exists() else P.read_text();prefix='__tech-priests__/graphics/entity/'+G.name+'/'
# Replace visual constants and picture layers only. No gameplay edits or flags.
start=original.index('local ICON = ');end=original.index('\nlocal entity =',start)
new=original[:start]+f'local ICON = "{prefix}icon.png"\nlocal WIDTH = 512\nlocal HEIGHT = 512\nlocal SCALE = 3.15 * 32 / 512 -- exact orthographic tile-to-pixel scale\n'+original[end:]
new=new.replace('icon_size = 1024','icon_size = 128')
start=new.index('  picture = {');end=new.index('  open_sound =',start)
shift=-.79/(2**.5)
new=new[:start]+'''  -- Static container: production north only; all source facings retained for review.
  picture = { layers = {
    { filename = "'''+prefix+'''body.png", priority = "high", width = WIDTH, height = HEIGHT,
      scale = SCALE, shift = { 0, '''+str(shift)+''' } },
    { filename = "'''+prefix+'''shadow.png", priority = "high", width = WIDTH, height = HEIGHT,
      scale = SCALE, shift = { 0, '''+str(shift)+''' }, draw_as_shadow = true }
  } },
'''+new[end:]
if not (O/'original-prototype.lua').exists():(O/'original-prototype.lua').write_text(original)
P.write_text(new)
manifest=dict(source_sha256=sha(O/('conclave-center-v02.blend' if O.name.startswith('v02') else 'conclave-center-v01.blend')),export_sha256=sha(O/('conclave-center-v02.glb' if O.name.startswith('v02') else 'conclave-center-v01.glb')),prototype_sha256=sha(P),files={p.relative_to(R).as_posix():sha(p) for p in files},scale=3.15*32/512,shift=[0,shift],placement='Projection of source world-ground origin; must be graphically verified in native client',gameplay_changed=False,owner_approval=False)
manifest['shadow_cleanup']='Only <=8/255 catcher background noise made transparent; original Cycles captures retained.'
(O/'integration.json').write_text(json.dumps(manifest,indent=2)+'\n')
sheet=Image.new('RGBA',(1024,1024),(28,28,27,255))
for i in range(4):sheet.alpha_composite(Image.open(C/f'body-d{i}.png').convert('RGBA'),((i%2)*512,(i//2)*512))
sheet.convert('RGB').save(O/'export-four-directions.jpg',quality=94)
print('CONCLAVE_PRODUCTION_GRAPHICS_INTEGRATED; gameplay unchanged')
