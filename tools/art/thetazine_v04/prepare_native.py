"""Review-only V04 body + independent heat atlas + actual native mixture shader."""
import argparse,pathlib,json,shutil,re,hashlib
from PIL import Image,ImageDraw
p=argparse.ArgumentParser();p.add_argument('--study',type=pathlib.Path,required=True);p.add_argument('--review-root',type=pathlib.Path,required=True);p.add_argument('--flame-y-adjust',type=float,default=0.0);a=p.parse_args();study=a.study.resolve();profile=a.review_root.resolve();W=pathlib.Path(__file__).resolve().parent;m=profile/'mods/model-visual-review_0.1.0';gfx=m/'graphics/thetazine-v04';gfx.mkdir(parents=True,exist_ok=True)
reg=json.loads((study/'native-jet-registration.json').read_text(encoding='utf-8'));model=json.loads((study/'source-manifest.json').read_text(encoding='utf-8'));assert reg['native_sha256']==model['native_sha256']
for name in ['body-1.png','body-2.png','heat-glow-1.png','heat-glow-2.png','idle-body.png','idle-heat-glow.png','underlay.png']:shutil.copy2(study/'source-package'/name,gfx/name)
counter=Image.new('RGBA',(256,128),(0,0,0,255));draw=ImageDraw.Draw(counter)
for frame in range(64):
 x=frame%8*32;y=frame//8*16
 for bit in range(6):draw.rectangle((x+4+bit*4,y+4,x+7+bit*4,y+11),fill=(255,255,255,255) if frame&(1<<bit) else (0,0,0,255))
counter.save(gfx/'frame-counter.png')
base=pathlib.Path('C:/Program Files (x86)/Steam/steamapps/common/Factorio/data/space-age/graphics/entity/thruster');meta=(base/'thruster.lua').read_text(encoding='utf-8');width=int(re.search(r'width\s*=\s*(\d+)',meta).group(1));height=int(re.search(r'height\s*=\s*(\d+)',meta).group(1))
with Image.open(base/'thruster-1.png') as im:alpha=im.crop((0,0,width,height)).convert('RGBA').getchannel('A').point(lambda v:255 if v>128 else 0);donor_lip_row=alpha.getbbox()[3]-1
shift='{'+','.join(map(str,reg['body_registration']['shift']))+'}';scale=reg['body_registration']['scale'];mouth=reg.get('light_plume_join_mean_native_tiles',reg['mouth_mean_native_tiles']);helper=pathlib.Path('C:/GITS/Tech-Priests/tools/art/hydrogen_thruster_v01/native_review/json.lua').read_text(encoding='utf-8')
lua=f'''local donor=data.raw.thruster.thruster
local p=table.deepcopy(data.raw.thruster['thetazine-thruster']);p.name='thetazine-v04-visual-pilot';p.localised_name={{'', 'Thetazine V04 / physical pipe joins / native flame'}}
local base='__model-visual-review__/graphics/thetazine-v04/'
local function atlas(kind)
 return {{filenames={{base..kind..'-1.png',base..kind..'-2.png'}},width=512,height=1280,line_length=8,lines_per_file=4,frame_count=64,animation_speed=.5,scale={scale},shift={shift}}}
end
local function marker(x)
 return {{filename=base..'frame-counter.png',width=32,height=16,line_length=8,frame_count=64,animation_speed=.5,scale=.5,shift={{x,-3.2}}}}
end
p.graphics_set.animation={{north={{layers={{atlas('body'),marker(-3.0)}}}}}}
p.graphics_set.idle_animation={{north={{filename=base..'idle-body.png',width=512,height=1280,frame_count=1,repeat_count=64,scale={scale},shift={shift}}}}}
p.graphics_set.always_draw_idle_animation=false;p.graphics_set.animation_random_start_frame=false
local kept={{}};for _,v in ipairs(p.graphics_set.working_visualisations or {{}}) do
 if v.name=='platform-service-underlay' or v.enabled_by_name then kept[#kept+1]=v end
end
p.graphics_set.working_visualisations=kept
for _,v in ipairs(kept) do
 if v.name=='platform-service-underlay' then v.animation={{filename=base..'underlay.png',width=512,height=1280,scale={scale},shift={shift}}} end
end
local heat=atlas('heat-glow');heat.draw_as_glow=true;heat.blend_mode='additive'
table.insert(p.graphics_set.working_visualisations,{{name='v04-separate-heat-glow',fadeout=true,animation={{layers={{heat,marker(3.0)}}}}}})
-- Reuse engine-driven effects through installed game references. No copied
-- game PNGs, replacement shader, scripted hue cycling or performance edits.
for _,key in ipairs({{'flame_effect','flame_half_height','flame_effect_width','flame_effect_height','flame_effect_offset'}}) do p.graphics_set[key]=table.deepcopy(donor.graphics_set[key]) end
p.plumes=table.deepcopy(donor.plumes)
local a=donor.graphics_set.animation;local sh=a.shift or {{0,0}};local donorLip=({donor_lip_row}-a.height/2)*a.scale/32+(sh[2] or sh.y or 0)
local offset=donorLip-donor.graphics_set.flame_position[2]
p.graphics_set.flame_position={{{mouth[0]},{mouth[1]}-offset+{a.flame_y_adjust}}}
p.drawing_box={{{{-4,-5}},{{4,42}}}}
data:extend({{p}})
'''+helper+"\nlog('THETAZINE_V04_NATIVE_JSON '..json({graphics=p.graphics_set,plumes=p.plumes,ports={fuel=p.fuel_fluid_box,oxidizer=p.oxidizer_fluid_box},collision=p.collision_box,donor={flame_position=donor.graphics_set.flame_position,body=a,lip_row="+str(donor_lip_row)+"},scope='Review-only actual native flame effect plus separate V04 body/heat sprites; gameplay preserved'}))\n"
shadow=None
if (study/'projected-shadow-validation.json').exists():
 shadow=json.loads((study/'projected-shadow-validation.json').read_text());assert shadow['native_sha256']==model['native_sha256'] and shadow['status'].startswith('PASS')
 for name in ['shadow-1.png','shadow-2.png','idle-shadow.png']:shutil.copy2(study/'source-package'/name,gfx/name)
 sw,sh=shadow['cell'];ss='{'+','.join(map(str,shadow['shift']))+'}'
 shadow_lua=f'''local projectedShadow={{filenames={{base..'shadow-1.png',base..'shadow-2.png'}},width={sw},height={sh},line_length=8,lines_per_file=4,frame_count=64,animation_speed=.5,scale={scale},shift={ss},draw_as_shadow=true}}
table.insert(p.graphics_set.animation.north.layers,projectedShadow)
table.insert(p.graphics_set.animation.north.layers,marker(0.0))
local coldBody=p.graphics_set.idle_animation.north
p.graphics_set.idle_animation.north={{layers={{coldBody,{{filename=base..'idle-shadow.png',width={sw},height={sh},frame_count=1,repeat_count=64,scale={scale},shift={ss},draw_as_shadow=true}}}}}}
'''
 lua=lua.replace('data:extend({p})',shadow_lua+'\ndata:extend({p})')
(m/'data-final-fixes.lua').write_text(lua,encoding='utf-8',newline='\n');(m/'scenarios/model-placement/control.lua').write_text((W/'native-control.lua').read_text().replace('REVIEW_SOURCE_NATIVE_SHA256',model['native_sha256']),encoding='utf-8',newline='\n')
receipt={'status':'ISOLATED_V04_NATIVE_PREPARED_REQUIRES_LOAD_AND_VISUAL_READBACK','native_sha256':model['native_sha256'],'registration_sha256':hashlib.sha256((study/'native-jet-registration.json').read_bytes()).hexdigest(),'data_sha256':hashlib.sha256((m/'data-final-fixes.lua').read_bytes()).hexdigest(),'control_sha256':hashlib.sha256((m/'scenarios/model-placement/control.lua').read_bytes()).hexdigest(),'donor_cell':[width,height],'donor_alpha_lip_row':donor_lip_row,'flame_y_adjust':a.flame_y_adjust,'graphics_files':[{'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in gfx.glob('*.png')],'effect_is_native':True,'native_colour_thrust_response_not_yet_reviewed':True}
receipt['shadow_contract']=shadow;receipt['native_visual_state_plan']=['working-connected','idle-connected','idle-disconnected','restart-disconnected'];(profile/'v04-preparation-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8',newline='\n');print('V04_NATIVE_READY',profile,donor_lip_row)
