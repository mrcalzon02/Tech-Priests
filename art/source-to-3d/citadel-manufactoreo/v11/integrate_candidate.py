"""Scoped integration into isolated current committed mod; preserve concurrent checkout."""
from pathlib import Path
import json,hashlib,shutil,math,subprocess
O=Path(__file__).resolve().parent;R=O.parent;M=R.parent/'tp-sterling-contract-main01/mods/tech-priests_0.1.687';REPO=O.parents[3]/'model-production';BASE='12fe5163fd02e644c56227976e03da843e5fc7d7'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
a=json.loads((O/'atlas-manifest.json').read_text());assert a['genuine_blender_frames']==33 and a['native_directions']==[0] and a['runtime_sha256']==sha(O/'citadel-v11.glb')
dst=M/'graphics/entity/citadel-manufactoreo-v1';dst.mkdir(exist_ok=True);files={}
for n in('north-idle.png','north-working.png','icon.png'):
 assert sha(O/'sprites'/n)==a['files'][n]['sha256'];shutil.copy2(O/'sprites'/n,dst/n);files[n]=sha(dst/n)
shift=-1.6/math.sqrt(2)
lua='''-- Authored closed Citadel cathedral. Actual fixed-north 5x5 platform assembler.
local target=assert(data.raw["assembling-machine"]["citadel-manufactoreo"],"actual Citadel prototype")
local prefix="__tech-priests__/graphics/entity/citadel-manufactoreo-v1/"
local function picture(file,frames)
 return {filename=prefix..file,width=512,height=512,frame_count=frames,repeat_count=frames==1 and 32 or 1,line_length=frames==1 and 1 or 8,animation_speed=8/60,scale=.625,shift={0,SHIFT}}
end
target.graphics_set={idle_animation=picture("north-idle.png",1),animation=picture("north-working.png",32),always_draw_idle_animation=false}
target.working_visualisations=nil;target.integration_patch=nil;target.water_reflection=nil
-- Native red/green terminals sit on the console's right-hand interface.
-- This preserves the existing circuit behavior/reach and adds no copper socket.
-- Source console's upper two seated control heads provide the terminals.
-- Projection: native X = model X; native Y = -model Y - model Z/sqrt(2).
-- No inherited crusher connector sprite floats over the cathedral roof.
local connector={points={wire={red={RED_X,RED_Y},green={GREEN_X,GREEN_Y}},shadow={red={RED_X,SHADOW_Y},green={GREEN_X,SHADOW_Y}}}}
target.circuit_connector={table.deepcopy(connector),table.deepcopy(connector),table.deepcopy(connector),table.deepcopy(connector)}
for _,prototype in ipairs({target,data.raw.item["citadel-manufactoreo"],data.raw.recipe["citadel-manufactoreo"]})do
 if prototype then prototype.icon=prefix.."icon.png";prototype.icon_size=64;prototype.icons=nil end
end
'''.replace('SHIFT',format(shift,'.12g'))
rec=json.loads((O/'recovered-console.json').read_text());scale=1.04/(rec['bounds']['max'][0]-rec['bounds']['min'][0]);heads=[o for o in rec['objects']if o['name'].endswith('console / control push button')or o['name'].endswith('console / control push button.001')];assert len(heads)==2
points=[]
for head in heads:
 v=head['vertices'];x=(min(q[0]for q in v)+max(q[0]for q in v))/2*scale-1.85;y=min(q[1]for q in v)*scale-2.01;z=(min(q[2]for q in v)+max(q[2]for q in v))/2*scale+.83;points.append([x,-y-z/math.sqrt(2),-y])
for key,value in [('RED_X',points[0][0]),('RED_Y',points[0][1]),('GREEN_X',points[1][0]),('GREEN_Y',points[1][1]),('SHADOW_Y',points[0][2])]:lua=lua.replace(key,format(value,'.12g'))
(O/'citadel-manufactoreo-v1.lua').write_text(lua,encoding='utf-8');(M/'prototypes/generated_graphics/citadel-manufactoreo-v1.lua').write_text(lua,encoding='utf-8')
base=subprocess.check_output(['git','-C',str(REPO),'show',BASE+':tech-priests_src/data-final-fixes.lua']);require=b'\nrequire("prototypes.generated_graphics.citadel-manufactoreo-v1")\n';assert b'citadel-manufactoreo-v1'not in base
assert (M/'data-final-fixes.lua').read_bytes()in(base,base+require),'isolated mod must match committed current main plus only this scoped art installation'
(M/'data-final-fixes.lua').write_bytes(base+require)
(O/'integration-candidate.json').write_text(json.dumps({'installed_isolated_current_mod':str(M),'base_commit':BASE,'source_sha256':sha(O/'citadel-v11.blend'),'runtime_sha256':sha(O/'citadel-v11.glb'),'files':files,'generated_lua_sha256':sha(O/'citadel-manufactoreo-v1.lua'),'sprite_shift':[0,shift],'sprite_scale':.625,'native_orientations':[0],'circuit_terminal_model_heads_native_projection':points,'fluid_ports':0,'gameplay_properties_changed':False,'production_repository_integrated':False,'native_operation_and_reload_pending':True},indent=2)+'\n');print('CITADEL_ISOLATED_INTEGRATION_READY',json.dumps(files))
