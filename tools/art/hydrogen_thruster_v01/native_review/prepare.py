"""Add the packaged hydrogen art to an already prepared isolated review copy."""
import argparse,hashlib,json,math,pathlib,shutil
ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--review-root',type=pathlib.Path,required=True);ap.add_argument('--package',type=pathlib.Path,required=True);ap.add_argument('--source-model',type=pathlib.Path,required=True);ap.add_argument('--legacy-json',type=pathlib.Path,required=True);ap.add_argument('--control',type=pathlib.Path,required=True);ap.add_argument('--json-helper',type=pathlib.Path,required=True);a=ap.parse_args()
root=a.review_root.resolve();m=root/'mods/model-visual-review_0.1.0';tp=next((root/'mods').glob('tech-priests_*'));package=a.package.resolve();graphics=tp/'graphics/entity/hydrogen-thruster-v01';graphics.mkdir(exist_ok=True)
for p in package.glob('*.png'):
 if not p.name.endswith('-idle-emission.png'):shutil.copy2(p,graphics/p.name)
shutil.copy2(package/'hydrogen-thruster-v01.lua',tp/'prototypes/generated_graphics/hydrogen-thruster-v01.lua')
shutil.copy2(a.control,m/'scenarios/model-placement/control.lua')
def lua(v):
 if isinstance(v,bool):return 'true' if v else 'false'
 if isinstance(v,str):return json.dumps(v,ensure_ascii=True)
 if isinstance(v,(float,int)):assert math.isfinite(v);return repr(v)
 if isinstance(v,list):return '{'+','.join(lua(x) for x in v)+'}'
 if isinstance(v,dict):return '{'+','.join('['+lua(k)+']='+lua(x) for k,x in sorted(v.items()))+'}'
 if v is None:return 'nil'
 raise TypeError(type(v))
old=json.loads(a.legacy_json.read_text(encoding='utf-8'));old_graphics=old['old_graphics']
data='''local base=assert(data.raw.thruster['hydrogen-thruster']);local before=table.deepcopy(base)
local old_graphics=OLD_GRAPHICS
local legacy=table.deepcopy(base);legacy.name='hydrogen-model-legacy';legacy.graphics_set=table.deepcopy(old_graphics);legacy.drawing_box={{-2.65,-2.95},{2.65,4.35}};data:extend({legacy})
require('__tech-priests__/prototypes/generated_graphics/hydrogen-thruster-v01')
local function equal(a,b)
 if type(a)~=type(b) then return false end
 if type(a)~='table' then return a==b end
 for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
 for k in pairs(b) do if a[k]==nil then return false end end
 return true
end
for key,value in pairs(before) do if key~='graphics_set' and key~='drawing_box' then assert(equal(value,base[key]),'Nonvisual prototype field changed: '..key) end end
for key in pairs(base) do if key~='graphics_set' and key~='drawing_box' then assert(before[key]~=nil,'Added nonvisual field: '..key) end end
local count=#old_graphics.working_visualisations
assert(#base.graphics_set.working_visualisations==count+1)
for i=1,count do assert(equal(old_graphics.working_visualisations[i],base.graphics_set.working_visualisations[i]),'Native cap changed') end
local forced=table.deepcopy(base);forced.name='hydrogen-model-run';forced.graphics_set.idle_animation=table.deepcopy(forced.graphics_set.animation)
for _,visual in ipairs(forced.graphics_set.working_visualisations) do if visual.name=='hydrogen-v01-thermal-glow' then visual.always_draw=true end end
data:extend({forced})
local pose_graphics={}
for i=0,6 do
 local pose=table.deepcopy(forced);pose.name='hydrogen-model-pose-'..i
 local body=pose.graphics_set.idle_animation.north
 body.layers[1].x=i*512;body.layers[1].line_length=1;body.layers[1].frame_count=1
 body.layers[2].repeat_count=1
 pose.graphics_set.animation=table.deepcopy(pose.graphics_set.idle_animation)
 for _,visual in ipairs(pose.graphics_set.working_visualisations) do
  if visual.name=='hydrogen-v01-thermal-glow' then visual.animation.x=i*512;visual.animation.line_length=1;visual.animation.frame_count=1 end
 end
 data:extend({pose});pose_graphics[#pose_graphics+1]={name=pose.name,source_index=i,body=pose.graphics_set.idle_animation,visuals=pose.graphics_set.working_visualisations}
end
'''.replace('OLD_GRAPHICS',lua(old_graphics))+a.json_helper.read_text(encoding='utf-8')+'''log('HYDROGEN_NATIVE_JSON '..json({nonvisual_fields_preserved=true,native_cap_visualisations_preserved=true,old_graphics=old_graphics,candidate_graphics=base.graphics_set,forced_run_graphics=forced.graphics_set,pose_graphics=pose_graphics,fuel=base.fuel_fluid_box,oxidizer=base.oxidizer_fluid_box,footprint={base.tile_width,base.tile_height},collision_box=base.collision_box,selection_box=base.selection_box,drawing_box=base.drawing_box,tile_buildability_rules=base.tile_buildability_rules,circuit_connector=base.circuit_connector or false,circuit_wire_connection_point=base.circuit_wire_connection_point or false,circuit_wire_max_distance=base.circuit_wire_max_distance or false}))
'''
(m/'data-final-fixes.lua').write_text(data,encoding='utf-8',newline='\n')
(root/'candidate-binding.json').write_text(json.dumps({'source_model_sha256':hashlib.sha256(a.source_model.read_bytes()).hexdigest(),'module_sha256':hashlib.sha256((package/'hydrogen-thruster-v01.lua').read_bytes()).hexdigest(),'images':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in graphics.glob('*.png')},'actual_target_idle':'hydrogen-thruster','forced_run_graphics_only':'hydrogen-model-run','legacy_comparison':'hydrogen-model-legacy','nonvisual_prototype_and_cap_preservation_asserted_in_data_stage':True},indent=2)+'\n',encoding='utf-8');print('NATIVE_REVIEW_PREPARED')
