"""Install this art only into the isolated committed-current-mod fixture."""
from pathlib import Path
import subprocess,json,shutil,hashlib,math
R=Path(__file__).resolve().parent;A=R/'authored-v02';repo=R.parents[2]/'model-production';M=R.parent/'tp-sterling-contract-main01/mods/tech-priests_0.1.687';base='d264c959d10d415e2132e4fbf4c2e27a9c3899f4';old='83ee782fdc9c959550b0cfe29ef670069c925814'
def git(*a):return subprocess.check_output(['git','-C',str(repo),*a])
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
a=json.loads((A/'capture-manifest.json').read_text());assert a['genuine_blender_frames']==132 and a['runtime_sha256']==sha(A/'entropic-v02.glb');assert json.loads((A/'clearance-review.json').read_text())['passed']
for p in git('diff','--name-only',old,base,'--','tech-priests_src').decode().splitlines():
 dst=M/Path(p).relative_to('tech-priests_src');dst.parent.mkdir(parents=True,exist_ok=True);dst.write_bytes(git('show',base+':'+p))
dst=M/'graphics/entity/entropic-extractor-v1';dst.mkdir(exist_ok=True)
for p in (A/'sprites').glob('*.png'):assert sha(p)==a['files'][p.name]['sha256'];shutil.copy2(p,dst/p.name)
lua='''-- Closed fragment-burning 3x3 reliquary. Art-only integration.
local target=assert(data.raw["burner-generator"]["entropic-extractor"])
local prefix="__tech-priests__/graphics/entity/entropic-extractor-v1/"
local function sprite(direction,state,frames)
 return {filename=prefix..direction.."-"..state..".png",width=512,height=512,frame_count=frames,repeat_count=frames==1 and 32 or 1,line_length=frames==1 and 1 or 8,animation_speed=8/60,scale=.375,shift={0,-.707106781187}}
end
local function four(state,frames)
 return {north=sprite("north",state,frames),east=sprite("east",state,frames),south=sprite("south",state,frames),west=sprite("west",state,frames)}
end
target.idle_animation=four("idle",1)
target.animation=four("working",32)
target.always_draw_idle_animation=false
for _,p in ipairs({target,data.raw.item["entropic-extractor"],data.raw.recipe["entropic-extractor"]})do
 p.icon=prefix.."icon.png";p.icon_size=64;p.icons=nil
end
'''
(A/'entropic-extractor-v1.lua').write_text(lua);(M/'prototypes/generated_graphics/entropic-extractor-v1.lua').write_text(lua)
data=git('show',base+':tech-priests_src/data-final-fixes.lua');assert b'generated_graphics.entropic-extractor-v1'not in data;data+=b'\nrequire("prototypes.generated_graphics.entropic-extractor-v1")\n';(M/'data-final-fixes.lua').write_bytes(data);(A/'data-final-fixes.lua').write_bytes(data)
(A/'integration-candidate.json').write_text(json.dumps({'base_commit':base,'source_sha256':sha(A/'entropic-v02.blend'),'runtime_sha256':sha(A/'entropic-v02.glb'),'generated_lua_sha256':sha(A/'entropic-extractor-v1.lua'),'sprite_files':a['files'],'isolated_current_mod':str(M),'gameplay_properties_changed':False,'production_repository_integrated':False,'native_final_art_checks_pending':True},indent=2));print('ENTROPIC_ISOLATED_ART_READY')

