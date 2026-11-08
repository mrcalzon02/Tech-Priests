import hashlib,json,pathlib,shutil,sys,math
from PIL import Image
import numpy as np
r=pathlib.Path(sys.argv[1]).resolve();out=r/'package';out.mkdir(exist_ok=True);receipt=json.loads((r/'capture-receipt.json').read_text(encoding='utf-8'));reg=json.loads((r/'draw-registration.json').read_text(encoding='utf-8'));assert receipt['status']=='CAPTURED_REQUIRES_REVIEW' and len(receipt['files'])==28
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
assert receipt['source_sha256']==sha(r/'hydrogen-thruster-v01.blend');checks=[]
for state in ['idle','run']:
 for channel in ['beauty','emission']:
  sheet=Image.new('RGBA',(3584,768))
  for i in range(7):
   row=next(v for v in receipt['files'] if v['state']==state and v['index']==i and v['pass']==channel);p=r/'captures'/row['file'];assert sha(p)==row['sha256']
   with Image.open(p) as im:im.verify()
   with Image.open(p) as im:
    im.load();assert im.mode=='RGBA' and im.size==(512,768);bbox=im.getbbox();assert bbox and bbox[0]>0 and bbox[1]>0 and bbox[2]<512 and bbox[3]<768,(p,bbox)
    sheet.paste(im,(i*512,0));checks.append({'file':p.name,'alpha_bbox':bbox,'sha256':sha(p)})
  name='hydrogen-thruster-v01-'+state+('' if channel=='beauty' else '-emission')+'.png';sheet.save(out/name)
  with Image.open(out/name) as atlas:
   for i in range(7):
    with Image.open(r/'captures'/(state+'-'+str(i).zfill(2)+'-'+channel+'.png')) as source:assert np.array_equal(np.asarray(atlas.crop((i*512,0,(i+1)*512,768))),np.asarray(source))
shadow=Image.open(r/'projected-shadow.png').convert('RGBA');a=np.asarray(shadow)[:,:,3];assert max(int(a[0].max()),int(a[-1].max()),int(a[:,0].max()),int(a[:,-1].max()))==0;shutil.copy2(r/'projected-shadow.png',out/'hydrogen-thruster-v01-shadow.png')
body_bottom=max((c['alpha_bbox'][3]-384)*reg['scale']/32+reg['shift'][1] for c in checks);drawing_bottom=math.ceil((body_bottom+.25)*8)/8
shift='{'+','.join(format(v,'.15g') for v in reg['shift'])+'}'
lua='''-- Authored hydrogen model V01: drawing-only registration, after legacy rescaling.
local p=data.raw.thruster and data.raw.thruster['hydrogen-thruster']
if not p or not p.graphics_set then return end
local base='__tech-priests__/graphics/entity/hydrogen-thruster-v01/'
local function animation(state,emission)
 return {filename=base..'hydrogen-thruster-v01-'..state..(emission and '-emission' or '')..'.png',width=512,height=768,line_length=7,frame_count=7,animation_speed=0.18,scale=0.375,shift=SHIFT,draw_as_glow=emission or false,blend_mode=emission and 'additive' or 'normal'}
end
local function body(state)
 return {north={layers={animation(state,false),{filename=base..'hydrogen-thruster-v01-shadow.png',width=768,height=1024,frame_count=1,repeat_count=7,animation_speed=0.18,scale=0.375,shift=SHIFT,draw_as_shadow=true}}}}
end
p.graphics_set.idle_animation=body('idle')
p.graphics_set.animation=body('run')
p.graphics_set.always_draw_idle_animation=false
p.graphics_set.animation_random_start_frame=false
p.drawing_box={{-2.65,-2.95},{2.65,DRAW_BOTTOM}}
p.graphics_set.working_visualisations=p.graphics_set.working_visualisations or {}
local thermal={name='hydrogen-v01-thermal-glow',always_draw=false,animation=animation('run',true)}
local existing=nil
for i,v in ipairs(p.graphics_set.working_visualisations) do if v.name==thermal.name then existing=i end end
if existing then p.graphics_set.working_visualisations[existing]=thermal else p.graphics_set.working_visualisations[#p.graphics_set.working_visualisations+1]=thermal end
'''.replace('SHIFT',shift).replace('DRAW_BOTTOM',repr(drawing_bottom))
(out/'hydrogen-thruster-v01.lua').write_text(lua,encoding='utf-8',newline='\n')
manifest={'status':'ATLAS_SOURCE_CELL_EQUIVALENCE_PASS_REQUIRES_FINAL_NATIVE_REVIEW','source_model_sha256':sha(r/'hydrogen-thruster-v01.blend'),'glb_sha256':sha(r/'hydrogen-thruster-v01.glb'),'registration':reg,'source_cell_checks':checks,'pngs':{p.name:sha(p) for p in out.glob('*.png')},'module_sha256':sha(out/'hydrogen-thruster-v01.lua'),'native_shadow_alpha_bbox':shadow.getbbox(),'native_shadow_border_alpha_zero':True,'exact_rgba_cells_checked':28,'native_body_alpha_bottom_tiles':body_bottom,'drawing_box_bottom_with_quarter_tile_margin':drawing_bottom,'module_changes':'Only graphics_set idle/run animation, random-start display flag, one thermal glow visual and drawing-box culling extent. Native pipe-cap visuals and all nonvisual prototype fields remain unchanged.','idle_emission_atlas':'Exported source channel retained for future graphics use; current module uses the run emission channel only for working glow.'}
(out/'package-validation.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8');print('PACKAGED',len(manifest['pngs']),'PNGS',28,'EXACT CELLS')
