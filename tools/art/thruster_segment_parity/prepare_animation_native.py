"""Display the actual new atlas in a review-only thruster, with a frame-counter layer."""
import argparse,pathlib,json,shutil
from PIL import Image,ImageDraw
p=argparse.ArgumentParser();p.add_argument('--study',type=pathlib.Path,required=True);p.add_argument('--review-root',type=pathlib.Path,required=True);p.add_argument('--registration',type=pathlib.Path,required=True);p.add_argument('--working',action='store_true');a=p.parse_args()
w=pathlib.Path(__file__).resolve().parent;study=a.study.resolve();profile=a.review_root.resolve();m=profile/'mods/model-visual-review_0.1.0';gfx=m/'graphics/thetazine-v02';gfx.mkdir(parents=True,exist_ok=True)
for path in (study/'source-package').glob('*.png'):shutil.copyfile(path,gfx/path.name)
underlay=study/'underlay-pilot.png'
if not underlay.exists():underlay=study/'source-package/underlay.png'
shutil.copyfile(underlay,gfx/'underlay.png')
counter=Image.new('RGBA',(256,128),(0,0,0,255));d=ImageDraw.Draw(counter)
for frame in range(64):
 x=(frame%8)*32;y=(frame//8)*16
 for bit in range(6):d.rectangle((x+4+bit*4,y+4,x+7+bit*4,y+11),fill=(255,255,255,255) if frame&(1<<bit) else (0,0,0,255))
counter.save(gfx/'frame-counter.png')
reg=json.loads(a.registration.read_text(encoding='utf-8'))['proposed_draw_registration'];scale=reg['scale'];shift='{'+','.join(map(str,reg['shift']))+'}'
current=(m/'data-final-fixes.lua').read_text(encoding='utf-8');assert 'THETAZINE_V02_NATIVE_JSON' not in current
data=f'''
local pilot=table.deepcopy(data.raw.thruster['thetazine-thruster']);pilot.name='thetazine-v02-visual-pilot';pilot.localised_name={{'', 'Thetazine V02 mechanical preview'}}
local base='__model-visual-review__/graphics/thetazine-v02/'
local function atlas(kind)
 return {{filenames={{base..'body-'..kind..'-1.png',base..'body-'..kind..'-2.png'}},width=512,height=768,line_length=8,lines_per_file=4,frame_count=64,animation_speed=.5,scale={scale},shift={shift}}}
end
local marker={{filename=base..'frame-counter.png',width=32,height=16,line_length=8,frame_count=64,animation_speed=.5,scale=.5,shift={{-2.8,-2.6}}}}
pilot.graphics_set.animation={{north={{layers={{atlas('beauty'),marker}}}}}}
pilot.graphics_set.idle_animation=table.deepcopy(pilot.graphics_set.animation)
pilot.graphics_set.animation_random_start_frame=false
for _,v in ipairs(pilot.graphics_set.working_visualisations) do
 if v.name=='platform-service-underlay' then v.animation={{filename=base..'underlay.png',width=512,height=768,scale={scale},shift={shift}}} end
end
local glow=atlas('emission');glow.blend_mode='additive';glow.draw_as_glow=true
table.insert(pilot.graphics_set.working_visualisations,{{name='v02-preview-thermal-glow',always_draw=true,animation=glow}})
pilot.drawing_box={{{{-3.5,-3.5}},{{3.5,6.5}}}}
data:extend({{pilot}})
log('THETAZINE_V02_NATIVE_JSON '..json({{graphics=pilot.graphics_set,fuel=pilot.fuel_fluid_box,oxidizer=pilot.oxidizer_fluid_box,collision=pilot.collision_box,tile_rules=pilot.tile_buildability_rules}}))
'''
(m/'data-final-fixes.lua').write_text(current+data,encoding='utf-8',newline='\n');shutil.copyfile(w/('working-animation-native-control.lua' if a.working else 'animation-native-control.lua'),m/'scenarios/model-placement/control.lua')
print('NEW_MODEL_NATIVE_REVIEW_PREPARED')
