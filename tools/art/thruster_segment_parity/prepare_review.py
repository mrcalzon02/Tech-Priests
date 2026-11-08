"""Reproduce the isolated native liquid-thruster cutaway review from tracked source."""
import argparse,pathlib,subprocess,shutil,json
p=argparse.ArgumentParser();p.add_argument('--repo',type=pathlib.Path,required=True);p.add_argument('--review-root',type=pathlib.Path,required=True);p.add_argument('--baseline',type=pathlib.Path,required=True);a=p.parse_args();repo=a.repo.resolve();root=a.review_root.resolve();here=pathlib.Path(__file__).resolve().parent
subprocess.run(['python','-B',str(repo/'tools/art/native_visual_review/prepare.py'),'--repo',str(repo),'--workdir',str(root)],check=True)
baseline=json.loads(a.baseline.read_text(encoding='utf-8'));m=root/'mods/model-visual-review_0.1.0';shutil.copyfile(here/'cutaway-control.lua',m/'scenarios/model-placement/control.lua')
def lua(v):
 if isinstance(v,bool):return str(v).lower()
 if isinstance(v,str):return json.dumps(v)
 if isinstance(v,(int,float)):return repr(v)
 if isinstance(v,list):return '{'+','.join(map(lua,v))+'}'
 if isinstance(v,dict):return '{'+','.join('['+lua(k)+']='+lua(x) for k,x in v.items())+'}'
 if v is None:return 'nil'
 raise TypeError(type(v))
helper=(repo/'tools/art/hydrogen_thruster_v01/native_review/json.lua').read_text(encoding='utf-8')
data='local baseline='+lua(baseline['custom'])+'''
local report={platform_transition=data.raw.tile['space-platform-foundation'].variants.transition}
for _,name in ipairs({'hydrogen-thruster','thetazine-thruster'}) do
 local p=data.raw.thruster[name];local old=baseline[name]
 local legacy=table.deepcopy(p);legacy.name='cutaway-baseline-'..name;legacy.tile_buildability_rules=old.tile_rules;legacy.collision_box=old.collision_box
 local kept={};for _,v in ipairs(legacy.graphics_set.working_visualisations or {}) do if v.name~='platform-service-underlay' then kept[#kept+1]=v end end;legacy.graphics_set.working_visualisations=kept
 data:extend({legacy})
 report[name]={tile_rules=p.tile_buildability_rules,graphics=p.graphics_set,ports={fuel=p.fuel_fluid_box,oxidizer=p.oxidizer_fluid_box},collision=p.collision_box,selection=p.selection_box,collision_mask=p.collision_mask or false}
end
'''+helper+"\nlog('CUTAWAY_CANDIDATE_JSON '..json(report))\n"
(m/'data-final-fixes.lua').write_text(data,encoding='utf-8',newline='\n');print('NATIVE_CUTAWAY_PREPARED',root)
